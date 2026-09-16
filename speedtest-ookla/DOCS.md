# Speedtest.net (Ookla CLI) add-on

Runs the official [Speedtest CLI by Ookla](https://www.speedtest.net/apps/cli) once per hour at a configurable minute against a fixed Speedtest.net server and publishes the result as Home Assistant sensors.

Why not the built-in Speedtest.net integration: it can only use the ten servers Ookla picks from the client's geo-IP location. On mobile uplinks with carrier-grade NAT that location is often wrong (the measurements then run against random servers abroad) and a server outside that list cannot be selected. The Ookla CLI accepts any server id.

## Sensors

| Entity | Unit | Content |
| --- | --- | --- |
| `sensor.speedtest_download` | Mbit/s | Download throughput (attributes `bytes_received`, `latency_loaded_ms`) |
| `sensor.speedtest_upload` | Mbit/s | Upload throughput (attributes `bytes_sent`, `latency_loaded_ms`) |
| `sensor.speedtest_ping` | ms | Idle latency (attributes `jitter_ms`, `packet_loss`) |
| `sensor.speedtest_status` | text | `ok`, `running` or `error`, with message |

All result sensors carry the attributes `server_name`, `server_location`, `server_country`, `server_id`, `server_host`, `isp`, `share_url` (public result page on speedtest.net) and `measured_at`. The entity ids are the same as those of the Speedtest.net integration, so an existing history and dashboard keep working after switching. Remove the integration before starting the add-on.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `server_id` | `818` | Speedtest.net server id (818 = LIWEST Linz). Find ids at `https://www.speedtest.net/api/js/servers?engine=js&search=<city>` |
| `fallback_server_id` | `73500` | Server tried when the first one fails (73500 = Energie AG Linz). Empty disables the fallback |
| `minute` | `0` | Minute of each hour at which the measurement runs |
| `run_on_start` | `true` | Run a measurement when the add-on starts |

## Manual measurement

Call the action `hassio.addon_stdin` with `addon: <this add-on's slug>` and any `input` text, for example from a dashboard button. The status sensor switches to `running` while the test is in progress.

## Notes

- The CLI binary is downloaded from Ookla on first start into the add-on data directory, because Ookla's EULA does not allow redistributing it. The add-on therefore needs internet access at first start.
- Starting the CLI records acceptance of Ookla's EULA and privacy policy (`--accept-license --accept-gdpr`). Ookla's licence limits use to personal, non-commercial purposes.
- Each run transfers roughly 100 to 300 MB depending on line speed. On metered connections adjust the schedule accordingly.
- The sensors are created through the REST API and are not available until the first measurement after a Home Assistant restart.
