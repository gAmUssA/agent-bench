---
title: Home
---

<section class="hero">
<h1>Local models, graded as agents</h1>
<p class="lead">Benchmarks for local models on Apple Silicon: how fast a model decodes, and whether it can finish real edit-and-test tasks inside an agent harness. The grader compiles and runs the output, and hidden tests catch cheating, so a pass means the code worked.</p>
<div class="btns"><a class="btn" href="#latest">Latest results</a><a class="btn ghost" href="https://github.com/gAmUssA/agent-bench">View on GitHub</a></div>
</section>

<section class="card" id="latest">
<h2>Inkling 2 Mini, five ways to run it</h2>
<p class="sub">Median wall time for three agent tasks (ledger, shop, planner), pi harness, 3 runs each. Shorter is faster. M5 Max, 64 GB.</p>
<ul class="bars" aria-label="Median total seconds per setup">
<li title="Runs: 159, 161, 170 s"><div class="name">Flint 40B-A2.5B<small>rec, 262k context</small></div><div class="track"><div class="bar" style="width:32.2%"></div><span class="val">161 s · 159–170</span></div></li>
<li title="Runs: 164, 198, 185 s"><div class="name">MTPLX 2.13<small>Bare Speed, 749k context</small></div><div class="track"><div class="bar" style="width:37%"></div><span class="val">185 s · 164–198</span></div></li>
<li title="Runs: 231, 226, 242 s"><div class="name">oMLX 0.8.3<small>oQ4e-mtp, 262k context</small></div><div class="track"><div class="bar" style="width:46.2%"></div><span class="val">231 s · 226–242</span></div></li>
<li title="Runs: 338, 328, 383 s"><div class="name">Unsloth llama.cpp<small>64k context</small></div><div class="track"><div class="bar" style="width:67.6%"></div><span class="val">338 s · 328–383</span></div></li>
<li title="Runs: 465, 409, 578 s"><div class="name">Unsloth llama.cpp<small>256k context</small></div><div class="track"><div class="bar" style="width:93%"></div><span class="val">465 s · 409–578</span></div></li>
</ul>
<p class="note">Labels show the median, then the range across 3 runs. Bars start at zero.</p>
</section>

| Setup | Median total | Greedy decode | All tests passed |
|---|---|---|---|
| Flint 40B-A2.5B (rec) | 161 s | not measured | 8 of 9 task runs |
| MTPLX 2.13 Bare Speed | 185 s | 129 tok/s | yes |
| oMLX 0.8.3 | 231 s | 76 tok/s | yes |
| Unsloth `llama.cpp`, 64k | 338 s | 50 tok/s | yes |
| Unsloth `llama.cpp`, 256k | 465 s | not measured | yes |

Read the method, the caveats and the setup of each run in [Inkling 2 Mini setups compared](bench-results/unsloth-vs-ollama-inkling).

<h2 id="results">All results</h2>
<ul class="grid">
<li><a href="bench-results/unsloth-vs-ollama-inkling"><strong>Inkling 2 Mini</strong><span>Unsloth, Ollama, MTPLX, oMLX and Flint compared</span></a></li>
<li><a href="bench-results/agent-m5-max-64gb"><strong>Agent runs, M5 Max 64 GB</strong><span>pi, OpenCode and Claude Code harnesses</span></a></li>
<li><a href="bench-results/agent-m1-max-64gb"><strong>Agent runs, M1 Max 64 GB</strong><span>The same tasks on older silicon</span></a></li>
<li><a href="bench-results/m5-max-64gb"><strong>Coding benchmark, M5 Max 64 GB</strong><span>One-shot compile-and-run grading</span></a></li>
<li><a href="bench-results/m5-max-36gb"><strong>Coding benchmark, M5 Max 36 GB</strong><span>Per-machine record</span></a></li>
<li><a href="bench-results/m1-max-64gb"><strong>Coding benchmark, M1 Max 64 GB</strong><span>Per-machine record</span></a></li>
<li><a href="bench-results/m3-pro-36gb"><strong>Coding benchmark, M3 Pro 36 GB</strong><span>Per-machine record</span></a></li>
<li><a href="bench-results/m2-pro-32gb"><strong>Coding benchmark, M2 Pro 32 GB</strong><span>Per-machine record</span></a></li>
<li><a href="bench-results/README"><strong>Method</strong><span>How records are made and what is pinned</span></a></li>
</ul>
