#!/usr/bin/env bash
# agent-bench.sh report carry-over, against a stub rec and a loopback
# /v1/models. No model is run: -h nosuch skips every harness, and the stub
# server answers 200 only for the bearer the stub rec printed. The report the
# script writes is seeded per case at the temp AGENT_BENCH_REPORT and the data
# table is read back from it. The data-table assertions use literal expected
# rows, not the production carry-over regex, as their oracle.
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

main() (
  local repo sandbox server="" key port report run_path
  local -a rows
  local -a report_lines data
  local i j
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/agent-bench-report-test.XXXXXX")
  report="$sandbox/report.md"
  # shellcheck disable=SC2329 # invoked indirectly via the EXIT trap
  cleanup() {
    if [[ -n "$server" ]]; then
      if kill -0 "$server" 2>/dev/null; then
        if ! kill "$server" 2>/dev/null; then
          echo "warning: could not signal agent-bench server $server during cleanup" >&2
        fi
      fi
    fi
    rm -rf -- "$sandbox"
    return 0
  }
  trap cleanup EXIT

  key=bench-report-preflight
  rec_ok="#!/bin/sh
if [ \"\${1-}\" = auth ] && [ \"\${2-}\" = token ]; then
  printf '%s\\n' '$key'
fi
exit 0"
  mkdir -p "$sandbox/bin" "$sandbox/home"
  ln -s "$(command -v python3)" "$sandbox/bin/python3"
  run_path="$sandbox/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  for tool in pi opencode claude ollama splash; do
    printf '#!/bin/sh\nexit 0\n' >"$sandbox/bin/$tool"
    chmod +x "$sandbox/bin/$tool"
  done
  install_rec() {
    printf '%s\n' "$1" >"$sandbox/bin/rec"
    chmod +x "$sandbox/bin/rec"
  }

  # $1 is the base URL. Succeeds iff the preflight passes and the script exits 0.
  run_bench() {
    env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
      -u all_proxy -u ALL_PROXY -u REC_API_KEY -u AGENT_BENCH_APPEND \
      PATH="$run_path" \
      NO_PROXY='*' no_proxy='*' \
      HOME="$sandbox/home" \
      REC_BASE_URL="$1" \
      AGENT_BENCH_OUT="$sandbox/out" \
      AGENT_BENCH_REPORT="$report" \
      AGENT_BENCH_WARMUP=0 \
      "$repo/agent-bench/agent-bench.sh" -p rec -h nosuch x
  }

  cat >"$sandbox/server.py" <<'PY'
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

expected = sys.argv[1]
log_path = sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        auth = self.headers.get("Authorization", "")
        with open(log_path, "a", encoding="utf-8") as fh:
            fh.write(self.command + " " + path + " " + auth + "\n")
        if path == "/v1/models" and auth == "Bearer " + expected:
            body = b'{"object":"list","data":[]}\n'
            self.send_response(200)
        else:
            body = b"unauthorized\n"
            self.send_response(401)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


server = HTTPServer(("127.0.0.1", 0), Handler)
sys.stdout.write(str(server.server_address[1]) + "\n")
sys.stdout.flush()
server.serve_forever()
PY
  install_rec "$rec_ok"

  mkfifo "$sandbox/ready"
  python3 -u "$sandbox/server.py" "$key" "$sandbox/seen" >"$sandbox/ready" 2>"$sandbox/server.err" &
  server=$!
  IFS= read -r port <"$sandbox/ready" || fail "models server exited before publishing a port: $(cat "$sandbox/server.err")"
  [[ "$port" =~ ^[0-9]+$ ]] || fail "models server published no port: ${port:-}"

  # Load the report's data table: everything after the rows-header row and its
  # separator. The assertions compare that table against literal expected rows,
  # not against the production carry-over regex, so a loosened regex cannot
  # make a wrong report pass by moving the oracle.
  load_data() {
    report_lines=()
    while IFS= read -r l; do
      report_lines+=( "$l" )
    done <"$report"
    local hdr=-1
    for i in "${!report_lines[@]}"; do
      if [[ "${report_lines[i]}" == "| harness | task | model | digest | visible | hidden | tests untouched | time | turns | tool calls | failed | malformed | end |" ]]; then
        hdr=$i
        break
      fi
    done
    if [[ $hdr -lt 0 ]]; then
      fail "report has no data table header"
    fi
    data=()
    for ((j = hdr + 2; j < ${#report_lines[@]}; j++)); do
      data+=( "${report_lines[j]}" )
    done
  }

  # The expected data rows: the seeded pi/opencode/claude runs, as the report
  # must carry them verbatim into a rebuilt report.
  # shellcheck disable=SC2016 # the row literals are report data, not shell
  rows=(
    '| pi | ledger | `ollama/ledger__easy` | `abc123def4567890` | **4/8** | 4/8 | ✅ | 12s | 3 | 5 | 0 | 0 | done |'
    '| opencode | shop | `ollama/shop__harder` | `def456abc7890123` | 2/8 | 4/8 | ✅ | 30s | 5 | 8 | 1 | 0 | done |'
    '| claude | planner | `ollama/planner__hardest` | `7890123456789012` | 5/8 | 7/8 | ✅ | 60s | 9 | 12 | 2 | 1 | done |'
  )

  # ---- CASE 1: a previous report's pi/opencode/claude data rows survive a fresh run
  cat >"$report" <<'REPORT'
# Agent bench — Apple M1, 64 GB

Generated by `agent-bench/agent-bench.sh`; tasks and grading are described
in its header. Each row is ONE run — sampling makes single runs noisy.

*failed* = tool results flagged as errors, incl. test runs that exit
non-zero (normal). *malformed* = calls the harness rejected for bad
arguments — the number that says whether a model drives tools reliably.

| field | value |
|---|---|
| pi | 1.6.0 |
| opencode | 0.5.0 |
| claude | 2.1.0 |
| ollama | 0.40.17 |
| python | 3.15.2 |
| timeout | 1200s per run |
| recorded | 2026-11-21 |

| harness | task | model | digest | visible | hidden | tests untouched | time | turns | tool calls | failed | malformed | end |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| pi | ledger | `ollama/ledger__easy` | `abc123def4567890` | **4/8** | 4/8 | ✅ | 12s | 3 | 5 | 0 | 0 | done |
| opencode | shop | `ollama/shop__harder` | `def456abc7890123` | 2/8 | 4/8 | ✅ | 30s | 5 | 8 | 1 | 0 | done |
| claude | planner | `ollama/planner__hardest` | `7890123456789012` | 5/8 | 7/8 | ✅ | 60s | 9 | 12 | 2 | 1 | done |
REPORT
  if ! run_bench "http://127.0.0.1:$port"; then fail "agent-bench report run exited nonzero"; fi
  load_data
  [[ ${#data[@]} -eq 3 ]] || fail "ACCEPT: expected 3 carried data rows, got ${#data[@]}"
  for row in "${rows[@]}"; do
    found=0
    for d in "${data[@]}"; do
      case "$d" in
        "$row") found=1 ;;
      esac
    done
    [[ $found -eq 1 ]] || fail "ACCEPT: data row not carried into the new report: $row"
  done
  printf 'PASS: old pi/opencode/claude data rows survive a fresh run\n'

  # ---- CASE 2: header version rows are not carried over as data rows
  cat >"$report" <<'REPORT'
# Agent bench — Apple M1, 64 GB

Generated by `agent-bench/agent-bench.sh`; tasks and grading are described
in its header. Each row is ONE run — sampling makes single runs noisy.

| field | value |
|---|---|
| pi | 1.6.0 |
| opencode | 0.9.0 |
| claude | 2.2.0 |
| ollama | 0.40.17 |
| python | 3.15.2 |
| timeout | 1200s per run |
| recorded | 2026-11-21 |

| harness | task | model | digest | visible | hidden | tests untouched | time | turns | tool calls | failed | malformed | end |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
REPORT
  if ! run_bench "http://127.0.0.1:$port"; then fail "agent-bench report run exited nonzero"; fi
  load_data
  [[ ${#data[@]} -eq 0 ]] || fail "header version rows were carried over as data rows: ${data[*]}"
  printf 'PASS: header version rows are not carried over as data rows\n'

  # ---- CASE 3: repeated runs carry the same data rows, no duplicates
  cat >"$report" <<'REPORT'
# Agent bench — Apple M1, 64 GB

Generated by `agent-bench/agent-bench.sh`; tasks and grading are described
in its header. Each row is ONE run — sampling makes single runs noisy.

*failed* = tool results flagged as errors, incl. test runs that exit
non-zero (normal). *malformed* = calls the harness rejected for bad
arguments — the number that says whether a model drives tools reliably.

| field | value |
|---|---|
| pi | 1.6.0 |
| opencode | 0.5.0 |
| claude | 2.1.0 |
| ollama | 0.40.17 |
| python | 3.15.2 |
| timeout | 1200s per run |
| recorded | 2026-11-21 |

| harness | task | model | digest | visible | hidden | tests untouched | time | turns | tool calls | failed | malformed | end |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| pi | ledger | `ollama/ledger__easy` | `abc123def4567890` | **4/8** | 4/8 | ✅ | 12s | 3 | 5 | 0 | 0 | done |
| opencode | shop | `ollama/shop__harder` | `def456abc7890123` | 2/8 | 4/8 | ✅ | 30s | 5 | 8 | 1 | 0 | done |
| claude | planner | `ollama/planner__hardest` | `7890123456789012` | 5/8 | 7/8 | ✅ | 60s | 9 | 12 | 2 | 1 | done |
REPORT
  if ! run_bench "http://127.0.0.1:$port"; then fail "agent-bench report run exited nonzero"; fi
  load_data
  [[ ${#data[@]} -eq 3 ]] || fail "IDEMPOTENT: expected 3 data rows, got ${#data[@]}"
  for row in "${rows[@]}"; do
    found=0
    for d in "${data[@]}"; do
      case "$d" in
        "$row") found=1 ;;
      esac
    done
    [[ $found -eq 1 ]] || fail "IDEMPOTENT: data row not carried into the repeat report: $row"
  done
  printf '%s\n' "${data[@]}" >"$sandbox/carried1"
  if ! run_bench "http://127.0.0.1:$port"; then fail "agent-bench report run exited nonzero"; fi
  load_data
  [[ ${#data[@]} -eq 3 ]] || fail "IDEMPOTENT: expected 3 data rows on repeat, got ${#data[@]}"
  for row in "${rows[@]}"; do
    found=0
    for d in "${data[@]}"; do
      case "$d" in
        "$row") found=1 ;;
      esac
    done
    [[ $found -eq 1 ]] || fail "IDEMPOTENT: data row not carried into the repeat report: $row"
  done
  printf '%s\n' "${data[@]}" >"$sandbox/carried2"
  cmp -s "$sandbox/carried1" "$sandbox/carried2" || fail "second report run changed the carried rows"
  printf 'PASS: repeated runs carry the same data rows\n'

  # Short probe: the EXIT cleanup must still run (and still rm the sandbox) when
  # the server has already exited. A dead child makes the guarded kill skip, the
  # unconditional rm still runs, and the cleanup must not abort under set -e or
  # rewrite the probe's outcome.
  probe_sandbox=$(mktemp -d "${TMPDIR:-/tmp}/agent-bench-report-probe.XXXXXX")
  PROBE_SANDBOX="$probe_sandbox" bash -c '
    set -euo pipefail
    server=999999
    sandbox="${PROBE_SANDBOX}"
    cleanup() {
      if [[ -n "$server" ]]; then
        if kill -0 "$server" 2>/dev/null; then
          if ! kill "$server" 2>/dev/null; then
            echo "warning: could not signal agent-bench server $server during cleanup" >&2
          fi
        fi
      fi
      rm -rf -- "$sandbox"
      return 0
    }
    trap cleanup EXIT
    printf "PROBE_BODY_COMPLETED\n"
  '
  [[ ! -e "$probe_sandbox" ]] || fail "cleanup probe left the sandbox behind: $probe_sandbox"
  printf 'PASS: cleanup still runs when the server has already exited\n'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
