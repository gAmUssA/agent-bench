#!/usr/bin/env bash
# agent-bench/tools/decode-bench.py against a stub streaming server and a closed port.
# The stub streams only a `reasoning` field (as rec does). Accept: three timed runs and a SUMMARY line, with the stub's 7 tokens. Reject: a closed port
# exits 1 and names the URL. Throughput is never asserted (it depends on the clock).
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

main() (
  local repo sandbox port out err code
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/decode-bench-test.XXXXXX")
  trap '[ -z "${server_pid:-}" ] || kill "$server_pid" 2>/dev/null || true; rm -rf "$sandbox"; return 0' EXIT

  cat >"$sandbox/stub.py" <<'PY'
import http.server, json, sys
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        self.rfile.read(int(self.headers["Content-Length"]))
        self.send_response(200); self.send_header("Content-Type", "text/event-stream"); self.end_headers()
        for piece in ("a", "b"):
            self.wfile.write(("data: " + json.dumps({"choices": [{"delta": {"reasoning": piece}}]}) + "\n\n").encode())
        self.wfile.write(("data: " + json.dumps({"choices": [], "usage": {"completion_tokens": 7}}) + "\n\n").encode())
        self.wfile.write(b"data: [DONE]\n\n")
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
print(srv.server_address[1], flush=True)
srv.serve_forever()
PY
  python3 "$sandbox/stub.py" >"$sandbox/port" &
  server_pid=$!
  for _ in $(seq 1 50); do [ -s "$sandbox/port" ] && break; sleep 0.1; done
  port=$(<"$sandbox/port")
  [ -n "$port" ] || fail "the stub server did not start"

  out=$(python3 "$repo/agent-bench/tools/decode-bench.py" --base-url "http://127.0.0.1:$port/v1" --model stub --runs 3)
  [ "$(grep -c '^run ' <<<"$out")" -eq 3 ] || fail "expected 3 timed runs, got: $out"
  grep -q 'tokens 7$' <<<"$out" || fail "the stub's token count is missing: $out"
  grep -q '^SUMMARY min ' <<<"$out" || fail "no SUMMARY line: $out"
  echo "PASS: a stub server gives 3 runs and a summary"

  kill "$server_pid"; wait "$server_pid" 2>/dev/null || true; server_pid=""
  code=0
  err=$(python3 "$repo/agent-bench/tools/decode-bench.py" --base-url "http://127.0.0.1:$port/v1" --model stub --runs 1 2>&1 >/dev/null) || code=$?
  [ "$code" -eq 1 ] || fail "a closed port should exit 1, got $code"
  grep -q "http://127.0.0.1:$port/v1" <<<"$err" || fail "the error does not name the URL: $err"
  echo "PASS: a closed port exits 1 naming the URL"
)

main "$@"
