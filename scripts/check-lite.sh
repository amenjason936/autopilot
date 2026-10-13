#!/bin/bash
# check-lite.sh <repo> <base> <head> <run-config.json>
# Exit: 0 eligible; 1 not eligible; 64 usage/config; 65 bad ref; 69 no tool.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
require git python3
[ $# -eq 4 ] || die 64 'usage: check-lite.sh <repo> <base> <head> <run-config.json>'
python3 "$SCRIPT_DIR/lite.py" "$@"
