#!/usr/bin/env bash
# The Flappy Bird completion gate. Exit 0 when gate.py passes, 1 with the reason on stdout otherwise.
#
#   gate.sh <project-dir> <out-dir>      writes screenshots (ready, playing, over, bot) to <out-dir>
#
# Needs: uv and Google Chrome. Playwright is fetched by uv; it drives the installed Chrome, no browser download.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
[ $# -eq 2 ] || { echo "usage: gate.sh <project-dir> <out-dir>" >&2; exit 1; }
exec uv run --no-project --with playwright --with pillow python "$here/gate.py" "$1" "$2"
