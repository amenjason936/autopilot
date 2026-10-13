#!/bin/bash
# verify-evidence.sh <evidence-dir> [file ...]
# Exit: 0 verified; 1 missing/tampered/invalid; 64 usage; 66 no directory; 69 no tool.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
require python3
[ $# -ge 1 ] || die 64 'usage: verify-evidence.sh <evidence-dir> [file ...]'
python3 "$SCRIPT_DIR/evidence.py" verify "$@"
