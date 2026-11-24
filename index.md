---
title: Home
---

<section class="hero">
<h1>Local models, graded as agents</h1>
<p class="lead">Benchmarks for local models on Apple Silicon: how fast a model decodes, and whether it can finish real edit-and-test tasks inside an agent harness. The grader compiles and runs the output, and hidden tests catch cheating, so a pass means the code worked.</p>
<div class="btns"><a class="btn" href="#latest">Latest results</a><a class="btn ghost" href="https://github.com/gAmUssA/agent-bench">View on GitHub</a></div>
</section>

<aside class="notice">
<strong>Your mileage may vary.</strong> These numbers come from one Mac Studio (M5 Max, 64 GB), one day, 3 runs per setup and three small Python tasks. Other chips, memory sizes, software versions or tasks will give different results, and run-to-run spread is large. If you think a result is wrong, <a href="https://github.com/gAmUssA/agent-bench/issues/new?template=result-looks-wrong.yml">open an issue</a>.
</aside>

<section class="card" id="recommendations">
<h2>Recommendations</h2>
<ul class="recs">
<li><strong>Best Inkling 2 Mini setup: MTPLX.</strong> Every test passed, 188 s median for the three agent tasks, 125 tok/s decode. Its memory guard refuses work when RAM is tight, so stop other model servers first.</li>
<li><strong>Fastest overall: Flint on rec.</strong> 233 tok/s decode and 132 s. It is a different model, and it missed a hidden test in 2 of 3 runs, so check what it writes.</li>
<li><strong>Easiest: oMLX 0.8.3.</strong> A Mac app with an OpenAI-compatible server. Every test passed, 247 s, about a third slower than MTPLX.</li>
<li><strong>Slowest: Unsloth llama.cpp.</strong> 52 tok/s and 375–405 s. Pick it for GGUF portability, not speed. Longer context (256k) cost no extra time here.</li>
</ul>
</section>

<section class="card" id="latest">
<h2>Inkling 2 Mini, five ways to run it</h2>
<p class="sub">Median wall time for three agent tasks (ledger, shop, planner), pi harness, 3 runs each. Shorter is faster.</p>
<ul class="bars" aria-label="Median total seconds per setup">
<li title="Runs: 146, 131, 132 s"><div class="name">Flint 40B-A2.5B<small>rec, 262k context</small></div><div class="track"><div class="bar" style="width:26.4%"></div><span class="val">132 s · 131–146</span></div></li>
<li title="Runs: 188, 254, 169 s"><div class="name">MTPLX 2.13<small>Bare Speed, 749k context</small></div><div class="track"><div class="bar" style="width:37.6%"></div><span class="val">188 s · 169–254</span></div></li>
<li title="Runs: 250, 247, 212 s"><div class="name">oMLX 0.8.3<small>oQ4e-mtp, 262k context</small></div><div class="track"><div class="bar" style="width:49.4%"></div><span class="val">247 s · 212–250</span></div></li>
<li title="Runs: 375, 397, 356 s"><div class="name">Unsloth llama.cpp<small>256k context</small></div><div class="track"><div class="bar" style="width:75%"></div><span class="val">375 s · 356–397</span></div></li>
<li title="Runs: 405, 406, 394 s"><div class="name">Unsloth llama.cpp<small>64k context</small></div><div class="track"><div class="bar" style="width:81%"></div><span class="val">405 s · 394–406</span></div></li>
</ul>
<p class="note">Labels show the median, then the range across 3 runs. Bars start at zero.</p>
</section>

| Setup | Median total | Greedy decode | Hidden tests |
|---|---|---|---|
| Flint 40B-A2.5B (rec) | 132 s | 233 tok/s | 1 of 3 runs clean; 2 missed 1 of 6 shop tests |
| MTPLX 2.13 Bare Speed | 188 s | 125 tok/s | all passed |
| oMLX 0.8.3 | 247 s | 75 tok/s | all passed |
| Unsloth `llama.cpp`, 256k | 375 s | 52 tok/s | all passed |
| Unsloth `llama.cpp`, 64k | 405 s | 52 tok/s | all passed |

Method, versions and per-run numbers: [Inkling 2 Mini setups compared](bench-results/inkling-2-mini-m5-max-studio).

<section class="card" id="machine">
<h2>Test machine</h2>
<table>
<tbody>
<tr><td>Computer</td><td>Mac Studio (Mac17,14)</td></tr>
<tr><td>Chip</td><td>Apple M5 Max · 18 CPU cores (6 Super + 12 Performance) · 40 GPU cores</td></tr>
<tr><td>Memory</td><td>64 GB unified</td></tr>
<tr><td>OS</td><td>macOS 27.0.1</td></tr>
<tr><td>Harness</td><td>pi 1.6.0</td></tr>
<tr><td>Memory pressure</td><td>About 26 GB of swap in use during the runs, left over from earlier sessions. See the method page.</td></tr>
</tbody>
</table>
</section>

<h2 id="results">All results</h2>
<ul class="grid">
<li><a href="bench-results/inkling-2-mini-m5-max-studio"><strong>Inkling 2 Mini, M5 Max Studio</strong><span>Five setups: method, versions, every run</span></a></li>
<li><a href="bench-results/flappy-bird-contest"><strong>Flappy Bird contest</strong><span>Five setups build a mobile game</span></a></li>
<li><a href="bench-results/weather-app-contest"><strong>Weather-app contest</strong><span>Five setups build a native macOS app</span></a></li>
<li><a href="bench-results/unsloth-vs-ollama-inkling"><strong>Unsloth vs Ollama</strong><span>Earlier decode comparison and first agent runs</span></a></li>
<li><a href="bench-results/agent-m5-max-64gb"><strong>Agent runs, M5 Max 64 GB</strong><span>pi, OpenCode and Claude Code harnesses</span></a></li>
<li><a href="bench-results/agent-m1-max-64gb"><strong>Agent runs, M1 Max 64 GB</strong><span>The same tasks on older silicon</span></a></li>
<li><a href="bench-results/m5-max-64gb"><strong>Coding benchmark, M5 Max 64 GB</strong><span>One-shot compile-and-run grading</span></a></li>
<li><a href="bench-results/m5-max-36gb"><strong>Coding benchmark, M5 Max 36 GB</strong><span>Per-machine record</span></a></li>
<li><a href="bench-results/m1-max-64gb"><strong>Coding benchmark, M1 Max 64 GB</strong><span>Per-machine record</span></a></li>
<li><a href="bench-results/m3-pro-36gb"><strong>Coding benchmark, M3 Pro 36 GB</strong><span>Per-machine record</span></a></li>
<li><a href="bench-results/m2-pro-32gb"><strong>Coding benchmark, M2 Pro 32 GB</strong><span>Per-machine record</span></a></li>
<li><a href="bench-results/"><strong>Method</strong><span>How records are made and what is pinned</span></a></li>
</ul>
