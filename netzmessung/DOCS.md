# SmartStamm Netzmessung add-on

Runs two internet speed measurements once per hour each, at configurable minutes, and publishes the results as Home Assistant sensors:

- **Speedtest.net** with the official [Speedtest CLI by Ookla](https://www.speedtest.net/apps/cli) against a fixed server. The built-in Speedtest.net integration can only use the ten servers Ookla picks from the client's geo-IP location, which is often wrong on mobile uplinks; the CLI accepts any server id.
- **RTR-Netztest** with the [RMBT client](https://github.com/rtr-nettest/open-rmbt-client-cli) of the Austrian regulator RTR-GmbH (Rust variant, built from a pinned commit).

Both measurements run sequentially in one loop, so they never overlap.

## Sensors

| Entity | Unit | Content |
| --- | --- | --- |
| `sensor.speedtest_download` | Mbit/s | Download (attributes `bytes_received`, `latency_loaded_ms`) |
| `sensor.speedtest_upload` | Mbit/s | Upload (attributes `bytes_sent`, `latency_loaded_ms`) |
| `sensor.speedtest_ping` | ms | Idle latency (attributes `jitter_ms`, `packet_loss`) |
| `sensor.speedtest_status` | text | `ok`, `running` or `error`, with message |
| `sensor.rtr_netztest_download` | Mbit/s | Download |
| `sensor.rtr_netztest_upload` | Mbit/s | Upload |
| `sensor.rtr_netztest_ping` | ms | Median ping (attribute `ping_min`) |
| `sensor.rtr_netztest_status` | text | `ok`, `running` or `error`, with message |

Speedtest sensors carry `server_name`, `server_location`, `server_country`, `server_id`, `server_host`, `isp`, `share_url` and `measured_at`; RTR sensors carry `server`, `share_url`, `measured_at` and `threads`. The entity ids match the former Speedtest.net integration and the former separate add-ons, so history and dashboards keep working.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `speedtest_minute` | `0` | Minute of each hour for Speedtest.net; leave empty to disable |
| `speedtest_server_id` | `818` | Speedtest.net server id (818 = LIWEST Linz). Find ids at `https://www.speedtest.net/api/js/servers?engine=js&search=<city>` |
| `speedtest_fallback_server_id` | `73500` | Server tried when the first one fails (73500 = Energie AG Linz); empty disables the fallback |
| `rtr_minute` | `30` | Minute of each hour for RTR-Netztest; leave empty to disable |
| `rtr_control_server` | `https://c01.netztest.at` | RTR control server |
| `rtr_model` | `Home Assistant Green` | Device model reported to RTR |
| `run_on_start` | `true` | Run both enabled measurements when the add-on starts |

## Manual measurement

Call the action `hassio.addon_stdin` with `addon: <this add-on's slug>` and `input: speedtest` or `input: rtr`; any other input starts both. The status sensors switch to `running` while a test is in progress.

## Notes

- Both clients are downloaded on first start into the add-on data directory: the Ookla CLI from Ookla (its EULA does not allow redistribution; starting it records acceptance of EULA and privacy policy, use is limited to personal, non-commercial purposes), the RMBT client from this repository's releases with SHA-256 verification. The add-on needs internet access at first start.
- Each measurement transfers roughly 100 to 300 MB. Two measurements per hour add up to several GB per day.
- Speedtest results are submitted to Ookla, RTR results to RTR (anonymised open data); both `share_url`s are public.
- The sensors are created through the REST API and are not available until the first measurement after a Home Assistant restart.
