# Weather-app contest

`run.sh` supervises one model building a native macOS weather app from `prompt.txt`, round after round,
until `gate.sh` passes or a limit is reached. See the header of each script for its contract.

- `gate.sh <project> <out-dir>`: builds, launches the executable, screenshots its window, reads the text with
  Vision OCR, and passes only when the window shows Berlin's live temperature (within 1.5 C of Open-Meteo)
  and at least 5 weekday names.
- `reference-app/`: the smallest app that passes the gate. `WEATHER_REFERENCE_MODE=blank` makes it open an empty window.
- `timeline.sh`: screenshots one window on an interval.

## Manual validation of the gate

The gate needs a window server, Screen Recording permission and the network, so CI cannot run it
(`rules/testing-standards.md`, platform-bound carve-out). The deterministic pieces (`window-info.py`, `ocr.swift`, the
decision logic) are exercised by this procedure. Run it after changing the gate:

1. Accept: `bash gate.sh reference-app /tmp/gate-accept` exits 0 and prints `gate passed`.
2. Reject, no data: `WEATHER_REFERENCE_MODE=blank bash gate.sh reference-app /tmp/gate-blank` exits 1 and the message names the weekday count.
3. Reject, no package: `bash gate.sh /tmp/empty-dir /tmp/gate-none` exits 1 and says there is no `Package.swift`.

A pass means exit codes 0, 1, 1 and a sensible message each time. Open `/tmp/gate-accept/gate.png` to see what was read.
