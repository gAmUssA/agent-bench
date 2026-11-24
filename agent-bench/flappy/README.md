# Flappy Bird contest

Same supervisor and contest runner as the [weather contest](../weather/README.md), a different task: a mobile-first
Flappy Bird in one `index.html`. Run it with `TASK=flappy bash agent-bench/weather/contest.sh flint mtplx`.

- `prompt.txt`, `nudge.txt`: what the model is asked, and the retry text that carries the gate's message.
- `gate.sh` / `gate.py`: opens `index.html` in installed Google Chrome with a 390x844 touch viewport and checks that it is
  self-contained, logs no errors, fills the screen without scrolling, exposes `window.game`, starts on a tap, ends when the
  bird is left alone, restarts on a tap, and lets a simple bot pass a pipe.
- `reference/index.html`: the smallest game that passes. `?mode=blank` draws nothing and exposes no hook.

## Manual validation of the gate

The gate needs Chrome and a window server, so CI cannot run it (`rules/testing-standards.md`, platform-bound carve-out).
Run this after changing the gate:

1. Accept: `bash gate.sh reference /tmp/flappy-accept` exits 0 and prints `gate passed`.
2. Reject, no hook: `GATE_QUERY='?mode=blank' bash gate.sh reference /tmp/flappy-blank` exits 1 and says `window.game is missing`.
3. Reject, no file: `bash gate.sh /tmp/empty-dir /tmp/flappy-none` exits 1 and says there is no `index.html`.

A pass means exit codes 0, 1, 1 and a sensible message each time. Open `/tmp/flappy-accept/*.png` to see what was checked.
