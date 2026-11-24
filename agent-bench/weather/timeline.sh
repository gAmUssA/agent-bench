#!/usr/bin/env bash
# Screenshots one window every N seconds until the stop file appears.
#
#   timeline.sh <window-id> <out-dir> <interval-seconds> <stop-file>
#
# Captures that window only (never the screen), so other apps' content is not recorded.
# Frames are out-dir/t-0001.png, t-0002.png, ... Exit 0 when the stop file exists; 1 on a usage error.
set -euo pipefail
[ $# -eq 4 ] || { echo "usage: timeline.sh <window-id> <out-dir> <interval-seconds> <stop-file>" >&2; exit 1; }
wid=$1 out=$2 every=$3 stop=$4
mkdir -p "$out"
n=0
while [ ! -e "$stop" ]; do
  n=$((n + 1))
  screencapture -x -o -l "$wid" "$(printf '%s/t-%04d.png' "$out" "$n")" || echo "timeline: capture $n failed; check Screen Recording permission and the window id" >&2
  sleep "$every"
done
