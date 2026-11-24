# Inkling 2 Mini decode speed: Unsloth's llama.cpp vs Ollama (2026-11-22)

One coding prompt (merge intervals), `temperature` 0, 400 tokens, 64k context, one discarded
warmup then 5 runs per config, one server resident at a time (`agent-bench/tools/compare-decode.py`).
Apple M5 Max, 64 GB. Background load (CoreSimulator, other apps) was not controlled.

| Config | Quant | Decode t/s (min / median / max) |
|---|---|---|
| Unsloth `llama-server`, flash-attn, no draft | `UD-Q4_K_XL`, 16 GB | 32.1 / 36.7 / 37.0 |
| Unsloth `llama-server` + `dspark` speculative draft (62% accepted) | `UD-Q4_K_XL`, 16 GB | 49.9 / 50.4 / 50.6 |
| Ollama 0.40.17, MLX runner (`inkling-2-mini-ctx64k`) | `nvfp4`, 20 GB | 23.4 / 40.1 / 43.1 |

Reading: speculative decoding is the real gain (about 1.4x over the same server without it,
about 1.25x over Ollama's median). Without the draft model Ollama's median is slightly
higher than Unsloth's. Ollama's spread is wide (23 to 43). The quants differ, so this is
a runtime-plus-quant comparison. Speed only: pass rates on agent-bench are untested.

Stock `llama.cpp` 1.0.0 cannot load the model (`unknown model architecture: 'inkling2'`);
support is in open upstream PRs, so Unsloth's own build is required.

## agent-bench, pi harness, 3 runs (`-p unsloth inkling-2-mini-unsloth`)

Unsloth `llama-server` at 64k with the `dspark` draft model, `reasoning_effort` medium, one server resident.
Every run passed all tasks (visible 8/8, hidden 5/5, 6/6, 7/7, no tampering). Seconds per run:

| Task | Run 1 | Run 2 | Run 3 | Ollama `ctx64k` | Ollama `ctx256k` |
|---|---|---|---|---|---|
| ledger | 51 | 39 | 67 | 38 | 55 |
| shop | 120 | 136 | 132 | 178 | 186 |
| planner | 167 | 153 | 184 | 261 | 227 |
| total | 338 | 328 | 383 | 477 | 468 |

About 20 to 30% less wall time than Ollama's single runs on the longer tasks; ledger is within noise.
The report table carries run 1 only. Ollama has one run per context, so its spread is unknown.

## More Inkling setups and Flint, pi harness, 3 runs each

Every run passed all visible and hidden tests unless noted. Seconds per run (ledger / shop / planner = total):

| Setup | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| Unsloth, 64k (above) | 51 / 120 / 167 = 338 | 39 / 136 / 153 = 328 | 67 / 132 / 184 = 383 |
| Unsloth, 256k (`-c 262144`, alias `inkling-2-mini-unsloth-256k`) | 79 / 148 / 238 = 465 | 80 / 126 / 203 = 409 | 52 / 214 / 312 = 578 |
| MTPLX 2.13 Bare Speed (`mtplx serve`, port 8001) | 19 / 47 / 98 = 164 | 20 / 63 / 115 = 198 | 29 / 53 / 103 = 185 |
| Flint 40B-A2.5B on rec, 256k | 18 / 62 / 79 = 159 | 14 / 49 / 98 = 161 | 17 / 55 / 98 = 170 |
| oMLX 0.8.3 (`Inkling-2-Mini-oQ4e-mtp`, port 8000, Lightning MTP on) | 26 / 79 / 126 = 231 | 16 / 103 / 107 = 226 | 44 / 79 / 119 = 242 |

- Flint run 2 missed 2 of 6 hidden shop tests (4/6); every other run passed everything.
- Decode speed, 400-token greedy answer, median of runs: MTPLX 129 tok/s (two runs, 128.9 to 129.1);
  oMLX 0.8.3 76.0 tok/s (three runs, 74.5 to 78.7); Unsloth 50.4 tok/s (table above).
  MTPLX's own claim is 128.8 peak (a cached prompt); oMLX's release notes claim 96.8 tok/s on an M5 Max.
- Unsloth at 256k is 25 to 50% slower than at 64k with a wide spread; the cause was not investigated.
- MTPLX's first three runs were discarded: its memory guard refused prefill ("insufficient memory",
  free pages 0.4 GiB) while oMLX, Splash and rec were resident, so the agent died after 2 to 5 tool
  calls. The reported runs were made after stopping those servers; check a run's events for
  "insufficient memory" before trusting it.
- MTPLX ran at its default 749k context and `sustained` profile; Bare Speed is a 4-bit pack (16 GB).
  Runs of other setups had other servers idle or stopped. Ollama has one run per context, so its spread is unknown.
- oMLX 0.8.3 came from the notarized `.dmg` (the Homebrew HEAD build failed without the Metal toolchain),
  served with `omlx-cli serve --model-dir ... --port 8000`; model `mlx-community/Inkling-2-Mini-oQ4e-mtp`.
  MTPLX was stopped first. All runs passed every visible and hidden test (one ledger tool call failed in run 1).
