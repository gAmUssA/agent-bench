#!/usr/bin/env bash
# Supervised weather-app run: pi works on prompt.txt in rounds until gate.sh passes.
# A model saying "done" never ends the run; only the gate, the round limit or the time limit does.
#
#   run.sh <name> <pi-provider> <pi-model> [--health <command>] [--restart <command>]
#
#   --health   shell command that succeeds while the model server is up; checked before every round
#   --restart  shell command that starts the server again when the health check fails
#
# Provider "claude" runs `claude -p` instead of pi; the model is a Claude model id.
# Env: TASK_DIR (directory holding prompt.txt, nudge.txt and gate.sh; default: this directory)  WEATHER_ROOT (default ${TMPDIR:-/tmp}/weather)  MAX_ROUNDS (12)  MAX_SECS (10800)  ROUND_TIMEOUT (2700)
# Layout: $WEATHER_ROOT/<name>/{app,session,out,state}. Rerunning with the same name resumes the session.
# Exit: 0 gate passed, 1 limit reached or setup error. Writes out/result.json either way.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
task=${TASK_DIR:-$here}
usage() { echo "usage: run.sh <name> <pi-provider> <pi-model> [--health <command>] [--restart <command>]" >&2; exit 1; }
[ $# -ge 3 ] || usage
name=$1 prov=$2 model=$3; shift 3
health="" restart=""
while [ $# -gt 0 ]; do
  case $1 in
    --health) health=${2:?--health needs a command}; shift 2 ;;
    --restart) restart=${2:?--restart needs a command}; shift 2 ;;
    *) usage ;;
  esac
done

root=${WEATHER_ROOT:-${TMPDIR:-/tmp}/weather}/$name
max_rounds=${MAX_ROUNDS:-12} max_secs=${MAX_SECS:-10800} round_timeout=${ROUND_TIMEOUT:-2700}
mkdir -p "$root/app" "$root/session" "$root/out"
state=$root/state
[ -f "$state" ] || printf 'round=0\nstart=%s\n' "$(date +%s)" >"$state"
round=0 start=0
# shellcheck source=/dev/null
. "$state"

say() { printf '%s [%s] %s\n' "$(date +%H:%M:%S)" "$name" "$*" | tee -a "$root/out/run.log"; }
save() { printf 'round=%s\nstart=%s\n' "$round" "$start" >"$state"; }
finish() { # status
  local now; now=$(date +%s)
  printf '{"name":"%s","provider":"%s","model":"%s","status":"%s","rounds":%s,"seconds":%s}\n' \
    "$name" "$prov" "$model" "$1" "$round" "$((now - start))" >"$root/out/result.json"
  say "result: $1 after $round rounds, $((now - start)) s"
  [ "$1" = passed ]
}

ensure_server() {
  [ -n "$health" ] || return 0
  timeout 30 bash -c "$health" >/dev/null 2>&1 && return 0
  say "model server health check failed: $health"
  [ -n "$restart" ] || { say "no --restart given"; return 1; }
  bash -c "$restart" >>"$root/out/restart.log" 2>&1 &
  for _ in $(seq 1 120); do timeout 30 bash -c "$health" >/dev/null 2>&1 && { say "model server is back"; return 0; }; sleep 5; done
  return 1
}

failure="the project does not exist yet"
while :; do
  now=$(date +%s)
  [ $((now - start)) -lt "$max_secs" ] || exit_status=timeout
  [ "$round" -lt "$max_rounds" ] || exit_status=rounds
  if [ -n "${exit_status:-}" ]; then finish "$exit_status" || exit 1; fi

  ensure_server || { finish server-down || exit 1; }
  round=$((round + 1)); save
  if [ "$round" -eq 1 ]; then
    prompt=$(<"$task/prompt.txt"); cont=()
  else
    nudge=$(<"$task/nudge.txt"); prompt=${nudge//\{\{FAILURE\}\}/$failure}; cont=(-c)
  fi
  say "round $round: $([ "$prov" = claude ] && echo claude -p || echo pi -p) (timeout ${round_timeout}s)"
  if [ "$prov" = claude ]; then
    # Claude Code with only project settings: no user CLAUDE.md, hooks, skills or MCP servers, like pi's bare flags.
    (cd "$root/app" && timeout "$round_timeout" claude -p "${cont[@]}" --model "$model" \
        --allowedTools "Bash Edit Write Read Glob Grep" --setting-sources project \
        --strict-mcp-config --disable-slash-commands "$prompt" </dev/null) >"$root/out/round-$round.txt" 2>&1
  else
    (cd "$root/app" && timeout "$round_timeout" pi -p "${cont[@]}" --session-dir "$root/session" \
        --no-extensions --no-skills --no-context-files --offline \
        --provider "$prov" --model "$model" "$prompt" </dev/null) >"$root/out/round-$round.txt" 2>&1
  fi
  say "round $round: harness exited $? ($(wc -c <"$root/out/round-$round.txt" | tr -d ' ') bytes of output)"

  if failure=$("$task/gate.sh" "$root/app" "$root/out" 2>&1); then
    say "$failure"
    cp "$root/out/gate.png" "$root/out/final.png" 2>/dev/null || cp "$root/out/bot.png" "$root/out/final.png" 2>/dev/null
    finish passed; exit $?
  fi
  say "gate failed: $(head -n 1 <<<"$failure")"
  printf '%s\n' "$failure" >"$root/out/gate-failure-$round.txt"
done
