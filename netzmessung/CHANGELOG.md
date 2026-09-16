## 1.0.0

- First release. Merges the former add-ons RTR-Netztest (0.1.1) and Speedtest.net (Ookla CLI) (0.1.0) into one add-on with one schedule loop.
- Both clients are downloaded at first start (Ookla CLI 1.2.0 from Ookla, RMBT client from this repository's releases, SHA-256 verified).
- A failed measurement sets the status sensor to `error` instead of ending the add-on (bashio's `errexit` is disabled).
- Sensors and entity ids are unchanged: `sensor.speedtest_*` and `sensor.rtr_netztest_*`.
