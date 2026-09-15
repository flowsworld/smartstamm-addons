# RTR-Netztest add-on

Runs the [RTR-Netztest](https://www.netztest.at/) measurement client (RMBT, open source by RTR-GmbH) once per hour at a configurable minute and publishes the result as Home Assistant sensors.

## Sensors

| Entity | Unit | Content |
| --- | --- | --- |
| `sensor.rtr_netztest_download` | Mbit/s | Download throughput |
| `sensor.rtr_netztest_upload` | Mbit/s | Upload throughput |
| `sensor.rtr_netztest_ping` | ms | Median ping (attribute `ping_min`) |
| `sensor.rtr_netztest_status` | text | `ok`, `running` or `error`, with message |

All result sensors carry the attributes `server`, `share_url` (public result page on netztest.at), `measured_at` and `threads`.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `control_server` | `https://c01.netztest.at` | RTR control server |
| `minute` | `30` | Minute of each hour at which the measurement runs |
| `run_on_start` | `true` | Run a measurement when the add-on starts |
| `model` | `Home Assistant Green` | Device model reported to RTR |

## Manual measurement

Call the action `hassio.addon_stdin` with `addon: <this add-on's slug>` and any `input` text, for example from a dashboard button. The status sensor switches to `running` while the test is in progress.

## Notes

- Each run transfers roughly 100 to 300 MB in total. On metered connections adjust the schedule accordingly.
- Results are submitted to RTR and appear anonymised in RTR's open data, like every test made on netztest.at.
- The client UUID is stored in the add-on data directory and reused across restarts.
- The sensors are created through the REST API and are not available until the first measurement after a Home Assistant restart.
