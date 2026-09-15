#!/usr/bin/env bashio
# RTR-Netztest add-on: runs the RMBT CLI client on a schedule and publishes the
# results as Home Assistant sensors through the Supervisor core API proxy.
set -o pipefail

OPTIONS=/data/options.json   # add-on options as written by the Supervisor
CONTROL_SERVER=$(jq -r '.control_server // "https://c01.netztest.at"' "${OPTIONS}")
MINUTE=$(jq -r '.minute // 30' "${OPTIONS}")
RUN_ON_START=$(jq -r 'if .run_on_start == null then true else .run_on_start end' "${OPTIONS}")
MODEL=$(jq -r '.model // "Home Assistant Green"' "${OPTIONS}")
export HOME=/data            # keeps the client UUID (~/.rmbt_client_uuid) across restarts
TRIGGER=/tmp/rtr_trigger
API="http://supervisor/core/api"

# Publish one sensor state. $1 entity id, $2 state, $3 attributes JSON object.
publish() {
  local entity="$1" state="$2" attrs="$3" body
  body=$(jq -cn --arg s "$state" --argjson a "$attrs" '{state:$s, attributes:$a}')
  if [ -n "${RTR_DRY_RUN:-}" ] || [ -f /data/dry_run ]; then echo "DRY ${entity} ${body}"; return 0; fi
  curl -sf -o /dev/null -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    -H "Content-Type: application/json" -d "${body}" "${API}/states/${entity}" \
    || bashio::log.warning "Publishing ${entity} failed"
}

set_status() {   # $1 state, $2 message
  publish sensor.rtr_netztest_status "$1" "$(jq -cn --arg m "$2" --arg t "$(date -Iseconds)" \
    '{friendly_name:"RTR-Netztest Status", icon:"mdi:speedometer", message:$m, updated:$t}')"
}

run_test() {
  bashio::log.info "Starting RTR-Netztest against ${CONTROL_SERVER}"
  set_status running "Messung läuft"
  local out rc
  out=$(rmbt-client --host "${CONTROL_SERVER}" --type CLI --platform Linux --model "${MODEL}" --nettype 98 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    bashio::log.error "rmbt-client exited with ${rc}: $(echo "${out}" | tail -3 | tr '\n' ' ')"
    set_status error "Client-Fehler ${rc}: $(echo "${out}" | grep -iE 'error|failed' | tail -1)"
    return 1
  fi
  local down up ping_med ping_min pings share server threads
  down=$(echo "${out}" | awk '/^Download:/{print $2}')
  up=$(echo "${out}" | awk '/^Upload:/{print $2}')
  ping_med=$(echo "${out}" | awk '/^Ping \(median\):/{print $3}')
  ping_min=$(echo "${out}" | awk '/^Ping \(min\):/{print $3}')
  pings=$(echo "${out}" | awk '/^Ping \(min\):/{gsub(/[()]/,"",$5); print $5}')
  share=$(echo "${out}" | awk '/^Result:/{print $2}')
  server=$(echo "${out}" | awk '/^Server:/{print $2}')
  threads=$(echo "${out}" | awk '/^Download:/{for(i=1;i<=NF;i++) if($i ~ /^thread/) print $(i-1)}' | head -1)
  if [ -z "${down}" ] || [ -z "${up}" ] || [ -z "${ping_med}" ]; then
    bashio::log.error "Could not parse results: $(echo "${out}" | tail -8 | tr '\n' ' ')"
    set_status error "Ergebnis nicht lesbar"
    return 1
  fi
  local ts; ts=$(date -Iseconds)
  local common; common=$(jq -cn --arg srv "${server}" --arg url "${share}" --arg t "${ts}" --arg th "${threads:-}" \
    '{server:$srv, share_url:$url, measured_at:$t, threads:$th, attribution:"RTR-Netztest (RMBT), RTR-GmbH"}')
  publish sensor.rtr_netztest_download "${down}" "$(echo "${common}" | jq -c '. + {friendly_name:"RTR-Netztest Download", unit_of_measurement:"Mbit/s", device_class:"data_rate", state_class:"measurement", icon:"mdi:download-network"}')"
  publish sensor.rtr_netztest_upload "${up}" "$(echo "${common}" | jq -c '. + {friendly_name:"RTR-Netztest Upload", unit_of_measurement:"Mbit/s", device_class:"data_rate", state_class:"measurement", icon:"mdi:upload-network"}')"
  publish sensor.rtr_netztest_ping "${ping_med}" "$(echo "${common}" | jq -c --arg mn "${ping_min}" --arg n "${pings}" '. + {friendly_name:"RTR-Netztest Ping", unit_of_measurement:"ms", device_class:"duration", state_class:"measurement", icon:"mdi:timer-outline", ping_min:($mn|tonumber), pings:($n|tonumber? // $n)}')"
  set_status ok "Download ${down} Mbit/s, Upload ${up} Mbit/s, Ping ${ping_med} ms"
  bashio::log.info "Result: down ${down} Mbit/s, up ${up} Mbit/s, ping ${ping_med} ms, ${share}"
}

# Manual trigger: `hassio.addon_stdin` with any input starts a measurement.
( while read -r _line; do touch "${TRIGGER}"; done ) <&0 &

seconds_until_next_run() {
  local now m target
  now=$(date +%s); m=$(date +%M | sed 's/^0//')
  target=$(( now - (m*60 + $(date +%S | sed 's/^0//')) + MINUTE*60 ))
  [ "${target}" -le "${now}" ] && target=$(( target + 3600 ))
  echo $(( target - now ))
}

bashio::log.info "RTR-Netztest add-on started; schedule: every hour at minute ${MINUTE}"
if [ "${RUN_ON_START}" = "true" ]; then run_test; fi
while true; do
  wait_s=$(seconds_until_next_run)
  bashio::log.info "Next measurement in ${wait_s} s"
  while [ "${wait_s}" -gt 0 ]; do
    if [ -f "${TRIGGER}" ]; then rm -f "${TRIGGER}"; bashio::log.info "Manual trigger received"; run_test; wait_s=$(seconds_until_next_run); continue; fi
    sleep 10; wait_s=$(( wait_s - 10 ))
  done
  run_test
done
