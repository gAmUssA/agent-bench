#!/usr/bin/env bash
# Runs the weather contest for each named setup, one after another, with every other model server stopped.
#
#   [TASK=weather|flappy] contest.sh <setup>...        setups: flint, mtplx, sonnet (Claude Code), ember and deepseek (Fireworks API, in pi); the last three need no local server; TASK picks the task directory (default weather)
#
# For each setup: stop all servers, start its server, run run.sh in its own Rex session (weather-<setup>),
# render the session's screen to a PNG every INTERVAL seconds (default 60), and stop the server when run.sh finishes.
# Output: $WEATHER_ROOT/<setup>/{app,out,frames}; frames/t-NNNN.png and .txt come from `rex capture` of that
# session only. Exit 0 when every setup ran (pass or fail is in out/result.json), 1 on a setup or usage error.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
task=${TASK:-weather}
task_dir=$(cd -- "$here/../$task" && pwd -P) || { echo "unknown TASK '$task'; use weather or flappy" >&2; exit 1; }
export WEATHER_ROOT=${WEATHER_ROOT:-$HOME/.cache/agent-bench/$task}
interval=${INTERVAL:-60}
[ $# -ge 1 ] || { echo "usage: contest.sh <setup>..." >&2; exit 1; }

stop_all() {
  pkill -f omlx-server; pkill -f llama-server; pkill -f "mtplx serve"; rec stop >/dev/null 2>&1
  for _ in $(seq 1 30); do pgrep -f "omlx-server|llama-server|mtplx serve|rec serve" >/dev/null || break; sleep 2; done
  sleep 10
}

setup_vars() { # sets prov model start health
  case $1 in
    flint)
      prov=rec model=flint
      start="zsh -c 'source ~/projects/dotfiles/zsh_custom/flint.zsh; flint-serve'"
      health="rec status | jq -e .ready" ;;
    mtplx)
      prov=mtplx model=mtplx-inkling-2-mini-bare-speed
      start="nohup mtplx serve --model Youssofal/Inkling-2-Mini-MTPLX-Bare-Speed --model-search-dir /Volumes/StudioStack/models/huggingface/hub --port 8001 >$WEATHER_ROOT/mtplx-serve.log 2>&1 &"
      health="curl -sf http://127.0.0.1:8001/v1/models" ;;
    ember)
      prov=fireworks model=accounts/fireworks/models/ember-1
      start="true"
      health="true" ;;
    deepseek)
      prov=fireworks model=accounts/fireworks/models/deepseek-v4p1-flash
      start="true"
      health="true" ;;
    sonnet)
      prov=claude model=claude-sonnet-5-5
      start="true"
      health="true" ;;
    *) echo "unknown setup '$1'; use flint, mtplx, sonnet, ember or deepseek" >&2; return 1 ;;
  esac
}

frame() { # name n
  local dir=$WEATHER_ROOT/$1/frames
  mkdir -p "$dir"
  local txt png
  txt=$(printf '%s/t-%04d.txt' "$dir" "$2"); png=${txt%.txt}.png
  if rex capture -s "$task-$1" --trim >"$txt" 2>/dev/null; then
    uv run --no-project --with pillow python "$here/render-frame.py" "$txt" "$png" "$task-$1  $(date +%H:%M:%S)" || echo "frame $2 not rendered" >&2
  else
    echo "frame $2: rex capture failed" >&2
  fi
}

mkdir -p "$WEATHER_ROOT"
for name in "$@"; do
  setup_vars "$name" || exit 1
  echo "$(date +%H:%M:%S) === $name: stopping servers"
  stop_all
  echo "$(date +%H:%M:%S) $name: starting the model server"
  bash -c "$start" >>"$WEATHER_ROOT/server-start.log" 2>&1
  up=0
  for _ in $(seq 1 120); do timeout 30 bash -c "$health" >/dev/null 2>&1 && { up=1; break; }; sleep 3; done
  [ "$up" -eq 1 ] || { echo "$name: model server did not come up; see $WEATHER_ROOT/server-start.log" >&2; exit 1; }

  rm -rf "${WEATHER_ROOT:?}/$name/out/result.json"
  rex new "$task-$name" --cwd "$here" --keep-open --interactive -- \
    env WEATHER_ROOT="$WEATHER_ROOT" TASK_DIR="$task_dir" bash "$here/run.sh" "$name" "$prov" "$model" --health "$health" --restart "$start" >/dev/null
  n=0
  while [ ! -f "$WEATHER_ROOT/$name/out/result.json" ]; do
    n=$((n + 1)); frame "$name" "$n"; sleep "$interval"
  done
  n=$((n + 1)); frame "$name" "$n"
  echo "$(date +%H:%M:%S) $name: $(cat "$WEATHER_ROOT/$name/out/result.json")"
  stop_all
done
echo "contest finished"
