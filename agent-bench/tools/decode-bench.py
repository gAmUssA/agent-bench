#!/usr/bin/env python3
"""Greedy decode speed of one OpenAI-compatible server.

One fixed coding prompt, temperature 0, a streamed answer capped at --max-tokens.
One warmup run is discarded, then --runs timed runs. Tokens per second is the
server-reported completion token count divided by the time from the first
streamed content (or reasoning) token to the end, so prefill is excluded.

  decode-bench.py --base-url http://127.0.0.1:8000/v1 --model NAME [--api-key KEY] [--runs 5]

Prints one line per run and a final `SUMMARY min <x> median <y> max <z>` line.
Exits 1 with a message when the server cannot be reached or reports no usage.
"""
import argparse
import json
import statistics
import sys
import time
import urllib.error
import urllib.request

PROMPT = ("Write a Python function that merges overlapping intervals in a list of (start, end) tuples, "
          "with a docstring and three assert-based tests. Output only code.")


def one_run(base_url, model, api_key, max_tokens):
    body = {"model": model, "messages": [{"role": "user", "content": PROMPT}], "max_tokens": max_tokens,
            "temperature": 0, "stream": True, "stream_options": {"include_usage": True}}
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = "Bearer " + api_key
    req = urllib.request.Request(base_url.rstrip("/") + "/chat/completions", json.dumps(body).encode(), headers)
    first = None
    tokens = 0
    with urllib.request.urlopen(req, timeout=900) as resp:
        for raw in resp:
            line = raw.decode().strip()
            if not line.startswith("data: ") or line.endswith("[DONE]"):
                continue
            chunk = json.loads(line[6:])
            if chunk.get("usage"):
                tokens = chunk["usage"]["completion_tokens"]
            choices = chunk.get("choices") or []
            if choices and first is None:
                delta = choices[0].get("delta", {})
                if delta.get("content") or delta.get("reasoning_content") or delta.get("reasoning"):
                    first = time.monotonic()
    end = time.monotonic()
    if first is None or tokens == 0:
        raise ValueError("the server streamed no tokens or no usage count")
    return tokens / (end - first), tokens


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base-url", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--api-key", default="")
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--max-tokens", type=int, default=400)
    args = ap.parse_args()
    try:
        one_run(args.base_url, args.model, args.api_key, args.max_tokens)
        rates = []
        for i in range(args.runs):
            rate, tokens = one_run(args.base_url, args.model, args.api_key, args.max_tokens)
            rates.append(rate)
            print(f"run {i} decode {rate:.1f} t/s tokens {tokens}", flush=True)
    except (urllib.error.URLError, OSError, ValueError) as err:
        print(f"decode-bench: {args.base_url} failed: {err}. Start the server and check --base-url and --model.",
              file=sys.stderr)
        return 1
    print(f"SUMMARY min {min(rates):.1f} median {statistics.median(rates):.1f} max {max(rates):.1f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
