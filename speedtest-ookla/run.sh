#!/command/with-contenv bashio
# Speedtest.net add-on: runs the official Ookla CLI against a fixed server on a
# schedule and publishes the results as Home Assistant sensors through the
# Supervisor core API proxy. Sensor names match the former Speedtest.net
# integration so history and dashboard stay continuous.
# bashio enables errexit; a failed measurement must not end the add-on.
set +o errexit +o errtrace
set -o pipefail

OPTIONS=/data/options.json   # add-on options as written by the Supervisor
SERVER_ID=$(jq -r '.server_id // 818' "${OPTIONS}")
FALLBACK_ID=$(jq -r '.fallback_server_id // empty' "${OPTIONS}")
MINUTE=$(jq -r '.minute // 0' "${OPTIONS}")
RUN_ON_START=$(jq -r 'if .run_on_start == null then true else .run_on_start end' "${OPTIONS}")
export HOME=/data            # keeps the recorded licence acceptance (~/.config/ookla) across restarts
BIN_DIR=/data/bin
CLI="${BIN_DIR}/speedtest"
CLI_VERSION=1.2.0
TRIGGER=/tmp/speedtest_trigger
API="http://supervisor/core/api"

# Download the Ookla CLI once. Ookla's EULA forbids redistribution, therefore the
# binary is fetched at runtime instead of being baked into the image.
install_cli() {
  if [ -x "${CLI}" ] && [ "$(cat "${BIN_DIR}/version" 2>/dev/null)" = "${CLI_VERSION}" ]; then return 0; fi
  local arch; arch=$(uname -m)   # aarch64 or x86_64, matches Ookla's file names
  local url="https://install.speedtest.net/app/cli/ookla-speedtest-${CLI_VERSION}-linux-${arch}.tgz"
  bashio::log.info "Downloading Ookla CLI ${CLI_VERSION} for ${arch}"
  mkdir -p "${BIN_DIR}"
  if ! curl -sfL "${url}" | tar xz -C "${BIN_DIR}" speedtest; then
    bashio::log.error "Download of ${url} failed"
    return 1
  fi
  echo "${CLI_VERSION}" > "${BIN_DIR}/version"
}

# Publish one sensor state. $1 entity id, $2 state, $3 attributes JSON object.
publish() {
  local entity="$1" state="$2" attrs="$3" body
  body=$(jq -cn --arg s "$state" --argjson a "$attrs" '{state:$s, attributes:$a}')
  if [ -n "${SPEEDTEST_DRY_RUN:-}" ] || [ -f /data/dry_run ]; then echo "DRY ${entity} ${body}"; return 0; fi
  curl -sf -o /dev/null -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    -H "Content-Type: application/json" -d "${body}" "${API}/states/${entity}" \
    || bashio::log.warning "Publishing ${entity} failed"
}

set_status() {   # $1 state, $2 message
  publish sensor.speedtest_status "$1" "$(jq -cn --arg m "$2" --arg t "$(date -Iseconds)" \
    '{friendly_name:"Speedtest.net Status", icon:"mdi:speedometer", message:$m, updated:$t}')"
}

# Run the CLI against one server id; prints the JSON result line on success.
speedtest_json() {
  timeout 180 "${CLI}" --accept-license --accept-gdpr -f json -p no -s "$1" 2>/dev/null | grep '"type":"result"' | tail -1
}

run_test() {
  bashio::log.info "Starting Speedtest.net against server ${SERVER_ID}"
  set_status running "Messung läuft"
  local json used="${SERVER_ID}"
  json=$(speedtest_json "${SERVER_ID}")
  if [ -z "${json}" ] && [ -n "${FALLBACK_ID}" ]; then
    bashio::log.warning "Server ${SERVER_ID} failed, trying fallback ${FALLBACK_ID}"
    used="${FALLBACK_ID}"; json=$(speedtest_json "${FALLBACK_ID}")
  fi
  if [ -z "${json}" ]; then
    bashio::log.error "Speedtest failed on server ${used}"
    set_status error "Messung gegen Server ${used} fehlgeschlagen"
    return 1
  fi
  # bandwidth is bytes/s in the CLI output; sensors report Mbit/s
  local down up ping
  down=$(echo "${json}" | jq -r '(.download.bandwidth * 8 / 1000000 * 100 | round) / 100')
  up=$(echo "${json}" | jq -r '(.upload.bandwidth * 8 / 1000000 * 100 | round) / 100')
  ping=$(echo "${json}" | jq -r '(.ping.latency * 10 | round) / 10')
  local common; common=$(echo "${json}" | jq -c --arg t "$(date -Iseconds)" '{
    server_name: .server.name, server_location: .server.location, server_country: .server.country,
    server_id: (.server.id | tostring), server_host: .server.host, isp: .isp,
    share_url: .result.url, measured_at: $t, attribution: "Data retrieved from Speedtest.net by Ookla"}')
  publish sensor.speedtest_download "${down}" "$(echo "${common}" | jq -c --argjson j "${json}" '. + {friendly_name:"SpeedTest Download", unit_of_measurement:"Mbit/s", device_class:"data_rate", state_class:"measurement", icon:"mdi:download-network", bytes_received:$j.download.bytes, latency_loaded_ms:$j.download.latency.iqm}')"
  publish sensor.speedtest_upload "${up}" "$(echo "${common}" | jq -c --argjson j "${json}" '. + {friendly_name:"SpeedTest Upload", unit_of_measurement:"Mbit/s", device_class:"data_rate", state_class:"measurement", icon:"mdi:upload-network", bytes_sent:$j.upload.bytes, latency_loaded_ms:$j.upload.latency.iqm}')"
  publish sensor.speedtest_ping "${ping}" "$(echo "${common}" | jq -c --argjson j "${json}" '. + {friendly_name:"SpeedTest Ping", unit_of_measurement:"ms", device_class:"duration", state_class:"measurement", icon:"mdi:timer-outline", jitter_ms:$j.ping.jitter, packet_loss:$j.packetLoss}')"
  set_status ok "Download ${down} Mbit/s, Upload ${up} Mbit/s, Ping ${ping} ms"
  bashio::log.info "Result: down ${down} Mbit/s, up ${up} Mbit/s, ping ${ping} ms, server ${used}, $(echo "${json}" | jq -r .result.url)"
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

bashio::log.info "Speedtest.net add-on started; server ${SERVER_ID}, fallback ${FALLBACK_ID:-none}, schedule: every hour at minute ${MINUTE}"
until install_cli; do bashio::log.warning "Retrying CLI download in 60 s"; sleep 60; done
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
