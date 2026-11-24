#!/usr/bin/env bash
# The weather-app completion gate. Exit 0 only when the project builds, its executable opens a window,
# and that window shows Berlin's live temperature (within 1.5 C of Open-Meteo) and 5 or more weekday names.
# On failure prints what failed to stdout (it becomes the nudge text) and exits 1.
#
#   gate.sh <project-dir> <out-dir>      writes <out-dir>/gate.png (the window) and <out-dir>/gate-ocr.txt
#
# Needs: swift, uv, curl, jq, and Screen Recording permission for the terminal that runs it.
set -euo pipefail

proj=${1:?usage: gate.sh <project-dir> <out-dir>}
out=${2:?usage: gate.sh <project-dir> <out-dir>}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
mkdir -p "$out"
app_pid=""
cleanup() { [ -z "$app_pid" ] || kill "$app_pid" 2>/dev/null || true; return 0; }
trap cleanup EXIT

fail() { printf '%s\n' "$*"; exit 1; }

cd "$proj" || fail "the project directory $proj does not exist"
[ -f Package.swift ] || fail "There is no Package.swift in the project root. Create a Swift package here."

if ! timeout 900 swift build -c release >"$out/gate-build.log" 2>&1; then
  fail "swift build -c release failed. Last lines of the build output:
$(tail -n 40 "$out/gate-build.log")"
fi

bin_dir=$(swift build -c release --show-bin-path)
exe=""
while IFS= read -r f; do
  case "$f" in *Tests*|*.dylib|*.o|*.swiftmodule|*.build) continue ;; esac
  exe=$f; break
done < <(find "$bin_dir" -maxdepth 1 -type f -perm -u+x | sort)
[ -n "$exe" ] || fail "swift build succeeded but there is no executable product in $bin_dir. Add an executableTarget."

"$exe" >"$out/gate-app.log" 2>&1 &
app_pid=$!

win=""
for _ in $(seq 1 20); do
  kill -0 "$app_pid" 2>/dev/null || fail "The app exited right after launch. Its output:
$(tail -n 20 "$out/gate-app.log")"
  if win=$(uv run --no-project --with pyobjc-framework-Quartz python "$here/window-info.py" "$app_pid" 2>/dev/null); then break; fi
  win=""; sleep 1
done
[ -n "$win" ] || fail "The app is running but opened no window of at least 300x200. Set NSApplication's activation policy to .regular and activate it, and show a WindowGroup."

sleep 10   # let the network calls finish
screencapture -x -o -l "${win%% *}" "$out/gate.png"
swiftc -O "$here/ocr.swift" -o "$out/ocr" 2>"$out/gate-ocr-build.log" || fail "internal: the OCR helper did not compile: $(tail -n 5 "$out/gate-ocr-build.log")"
"$out/ocr" "$out/gate.png" >"$out/gate-ocr.txt"

truth=$(curl -sf --max-time 20 "https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&current=temperature_2m" | jq -r '.current.temperature_2m') \
  || fail "internal: could not fetch the reference temperature from Open-Meteo"

# grep exits 1 when nothing matches (an empty window); only exit 2 and up is a tool failure.
days=$({ grep -oEi '\b(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[a-z]*\b' "$out/gate-ocr.txt" || test $? -eq 1; } | cut -c1-3 | tr 'A-Z' 'a-z' | sort -u | wc -l | tr -d ' ')
match=$({ grep -oE -- '-?[0-9]+([.,][0-9]+)?' "$out/gate-ocr.txt" || test $? -eq 1; } | tr ',' '.' | awk -v t="$truth" 'BEGIN{ok=0} {d=$1-t; if (d<0) d=-d; if (d<=1.5) ok=1} END{print ok}')

[ "$days" -ge 5 ] || fail "The window shows $days distinct weekday names; the 7-day forecast must show at least 5 (Mon, Tue, ...). Text read from the window:
$(head -n 30 "$out/gate-ocr.txt")"
[ "$match" -eq 1 ] || fail "No number on the window is within 1.5 of Berlin's real current temperature (${truth} C). Show the live temperature in Celsius from Open-Meteo. Text read from the window:
$(head -n 30 "$out/gate-ocr.txt")"
echo "gate passed: window ${win}, $days weekday names, live temperature near ${truth} C"
