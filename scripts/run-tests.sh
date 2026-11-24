#!/usr/bin/env bash
# Runs every tests/test_*.sh; exits non-zero when any fails or none are found.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
shopt -s nullglob
tests=(tests/test_*.sh)
if [ "${#tests[@]}" -eq 0 ]; then echo "no tests found under tests/" >&2; exit 1; fi
failed=0
for t in "${tests[@]}"; do
  if bash "$t"; then echo "ok   $t"; else echo "FAIL $t" >&2; failed=$((failed + 1)); fi
done
echo "suites=${#tests[@]} failed=$failed"
[ "$failed" -eq 0 ]
