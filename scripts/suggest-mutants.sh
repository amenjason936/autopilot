#!/bin/bash
# suggest-mutants.sh [--include-tests] <repo> <base> <head> <new-output-dir>
# Test files are skipped unless --include-tests; so are lines inside Python docstrings.
# Creates candidates against head; only changed lines are mutated. Does not run code.
# Exit: 0 candidates written; 64 usage; 65 ref/input; 69 missing tool; 73 output exists.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
require git python3
{ [ $# -eq 4 ] || { [ $# -eq 5 ] && [ "$1" = --include-tests ]; }; } || die 64 'usage: suggest-mutants.sh [--include-tests] <repo> <base> <head> <new-output-dir>'
python3 "$SCRIPT_DIR/suggest_mutants.py" "$@"
