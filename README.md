# agent-bench

Benchmarks for local models on Apple Silicon. Results are published at
**[gamov.io/agent-bench](https://gamov.io/agent-bench)**.

- `agent-bench/agent-bench.sh` runs three edit-and-test tasks (`tasks/ledger`, `shop`, `planner`)
  through an agent harness (`-h pi | opencode | claude`) against a model provider
  (`-p ollama | omlx | rec | splash | unsloth | mtplx | nebius | fireworks | anthropic`).
  Hidden tests and a tamper check grade the result. Usage is in the script header.
- `ollama-code-bench.sh`, `ollama-bench.sh`, `bench-record.sh` run the older single-prompt coding
  and decode benchmarks and record one file per machine.
- `agent-bench/tools/compare-decode.py` measures greedy decode tokens per second.
- `agent-bench/repro/splash/` reproduces the Splash runs from a clean machine.
- `bench-results/` holds the results; the Pages site renders them.

## Setup

The harnesses read provider and model entries from your own agent config: `~/.pi/agent/models.json`
(or a directory given by `PI_CODING_AGENT_DIR`) for pi, `~/.config/opencode/opencode.json` for OpenCode.
A provider's header comment in `agent-bench.sh` names the model alias to register and the server to start.
Raw run output goes to `bench-out/` (gitignored); set `AGENT_BENCH_OUT` and `AGENT_BENCH_REPORT` to redirect it.

## Tests

```bash
bash scripts/run-tests.sh
```

## Publishing results

Pages serves the repository root from `main` (Jekyll, `_config.yml`). Add a markdown file under
`bench-results/` and link it from `index.md`.

Licensed MIT.
