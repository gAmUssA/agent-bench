---
layout: default
---

# agent-bench

Local-model benchmarks on Apple Silicon: how fast a model decodes, and whether it can finish
real edit-and-test tasks as an agent (pi, OpenCode, Claude Code harnesses). The grader compiles
and runs the output, and hidden tests catch cheating, so a pass means the code worked.

## Latest: Inkling 2 Mini on an M5 Max, 64 GB

Three agent tasks (ledger, shop, planner), pi harness, 3 runs each. Seconds for all three tasks:

| Setup | Total seconds | Greedy decode | All tests passed |
|---|---|---|---|
| Flint 40B-A2.5B (rec) | 159–170 | not measured | 8 of 9 task runs |
| MTPLX 2.13 Bare Speed | 164–198 | 129 tok/s | yes |
| oMLX 0.8.3 | 226–242 | 76 tok/s | yes |
| Unsloth `llama.cpp`, 64k | 328–383 | 50 tok/s | yes |
| Unsloth `llama.cpp`, 256k | 409–578 | not measured | yes |

Details, caveats and the method: [Inkling 2 Mini setups compared](bench-results/unsloth-vs-ollama-inkling).

## All results

- [Inkling 2 Mini: Unsloth, Ollama, MTPLX, oMLX, Flint](bench-results/unsloth-vs-ollama-inkling)
- Agent runs: [M5 Max 64 GB](bench-results/agent-m5-max-64gb), [M1 Max 64 GB](bench-results/agent-m1-max-64gb)
- Coding benchmark by machine: [M5 Max 64 GB](bench-results/m5-max-64gb), [M5 Max 36 GB](bench-results/m5-max-36gb),
  [M1 Max 64 GB](bench-results/m1-max-64gb), [M3 Pro 36 GB](bench-results/m3-pro-36gb),
  [M2 Pro 32 GB](bench-results/m2-pro-32gb)
- [How the records are made and what is pinned](bench-results/README)

Source and harness: [github.com/gAmUssA/agent-bench](https://github.com/gAmUssA/agent-bench).
