# Inkling 2 Mini setups compared, M5 Max Studio (2026-11-24)

Five ways to run a local model as a coding agent on one Mac, measured one at a time with every other
server stopped. Results are one machine on one day; see the disclaimer on the [home page](../).

## Test machine

| | |
|---|---|
| Computer | Mac Studio (Mac17,14) |
| Chip | Apple M5 Max, 18 CPU cores (6 Super + 12 Performance), 40 GPU cores |
| Memory | 64 GB unified |
| OS | macOS 27.0.1 |
| Power | On AC power, Low Power Mode off |
| Other load | Everything else stopped between setups; the desktop was in normal use, so background load was not controlled |
| Swap | 26.5 GB of a 27.6 GB swap file was in use when the runs ended. These pages were left over from earlier heavy sessions and were not cleared by a reboot, so every setup ran under the same stale swap. Measured with `sysctl vm.swapusage` after the runs, not before |

## What was measured

- **Agent run.** `agent-bench` gives the model three small Python projects (ledger, shop, planner) with
  failing tests, through the `pi` harness. Each task is graded by visible tests, hidden tests the model
  never sees, and a check that the tests were not edited. A run is the three tasks back to back; the time is the sum.
  3 runs per setup.
- **Decode speed.** One fixed coding prompt, temperature 0, 400 tokens, streamed. One warmup run is discarded,
  then 5 runs. The rate excludes prefill (`agent-bench/tools/decode-bench.py`).
- **Order.** Flint, MTPLX, oMLX, Unsloth 64k, Unsloth 256k. Before each setup every other model server
  was stopped and the server for that setup was started fresh.

## Setups

| Setup | Model and quant | Engine | Context |
|---|---|---|---|
| Flint (rec) | Flint 40B-A2.5B, int4 | `rec` 0.1.2 | 262,144 |
| MTPLX | Inkling 2 Mini, MTPLX Bare Speed (4-bit, native MTP head) | `mtplx` 2.13.0, `sustained` profile | 749k default |
| oMLX | Inkling 2 Mini, `oQ4e-mtp` (MLX), Lightning MTP on | oMLX 0.8.3 | 262,144 |
| Unsloth 64k | Inkling 2 Mini, `UD-Q4_K_XL` GGUF + `dspark` draft (n-max 3) | Unsloth's own `llama.cpp` build 12588 | 65,536 |
| Unsloth 256k | the same | the same | 262,144 |

Flint is a different model from Inkling 2 Mini, so its row compares a model as well as an engine.
The harness was `pi` 1.6.0 for every setup, with reasoning effort `medium` on the Unsloth servers.

## Results

Seconds for ledger / shop / planner, then the total:

| Setup | Run 1 | Run 2 | Run 3 | Median total | Greedy decode (min / median / max) | Tests |
|---|---|---|---|---|---|---|
| Flint (rec) | 27 / 64 / 55 = 146 | 18 / 48 / 65 = 131 | 20 / 48 / 64 = 132 | **132 s** | 231 / **233** / 236 tok/s | 1 of 3 runs passed every hidden test; the other 2 missed 1 of 6 hidden shop tests |
| MTPLX | 26 / 66 / 96 = 188 | 18 / 59 / 177 = 254 | 29 / 52 / 88 = 169 | **188 s** | 124 / **125** / 127 tok/s | all passed |
| oMLX 0.8.3 | 26 / 75 / 149 = 250 | 46 / 81 / 120 = 247 | 20 / 76 / 116 = 212 | **247 s** | 72.5 / **75.4** / 77.7 tok/s | all passed |
| Unsloth 256k | 61 / 104 / 210 = 375 | 86 / 135 / 176 = 397 | 49 / 137 / 170 = 356 | **375 s** | 51.9 / **52.2** / 52.4 tok/s | all passed |
| Unsloth 64k | 47 / 162 / 196 = 405 | 85 / 140 / 181 = 406 | 51 / 139 / 204 = 394 | **405 s** | 51.7 / **52.4** / 52.6 tok/s | all passed |

Raw per-run reports and decode logs: [`runs/2026-11-24/`](https://github.com/gAmUssA/agent-bench/tree/main/bench-results/runs/2026-11-24).

## Reading the numbers

- Run-to-run spread is large. MTPLX's three totals span 169 to 254 s, and the same setups measured earlier
  the same week (before this protocol) differed from these medians by up to about 20% (Unsloth 64k 338 s then 405 s,
  Unsloth 256k 465 s then 375 s). Treat gaps under about 25% as noise.
- Decode speed is stable (under 3% spread), but it predicts agent time only roughly: agent time also depends
  on prefill, how many tool calls a model makes, and how long it reasons.
- Longer context did not cost speed here: Unsloth at 256k was no slower than at 64k in this rerun.
- Memory pressure may have slowed some runs. MTPLX logged one memory-guard event (`prefill_admission_shed`) during its three agent runs, and its run 2 was the slow one (254 s against 188 s and 169 s). A clean rerun after a reboot would show how much of the spread is swap. Decode speed is unlikely to be affected: MTPLX decoded at 125 tok/s here and 129 tok/s in an earlier pass.
- Greedy decode is not what an agent sees. Agent runs sample, and speculative drafting accepts fewer tokens
  on less predictable output.

## Earlier results

[Unsloth vs Ollama decode and the first agent runs](unsloth-vs-ollama-inkling) (2026-11-22).
