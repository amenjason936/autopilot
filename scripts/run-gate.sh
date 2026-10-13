#!/bin/bash
# run-gate.sh [--dry-run] [--lite] <workdir> <evidence-file> <label> <command>...
# Exit: 0 passed/preview; 1 failed; 64 usage/policy; 65 dirty code; 66 missing;
# 69 missing tool; 70 internal; 73 exists/locked; 76 unsafe retry; 77 sandbox failed; 129/130/143 signal.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
# shellcheck source=runner.sh
. "$SCRIPT_DIR/runner.sh"
ORIGINAL_ARGC=$#
runner_options "$@"
shift "$OPTIONS_CONSUMED"
[ $# -ge 4 ] || die 64 'usage: run-gate.sh [--dry-run] [--lite] <workdir> <evidence-file> <label> <command>...'
runner_init "$1" "$2" "$3"
shift 3
if [ "$DRY_RUN" -eq 1 ]; then runner_preview "$@"; exit 0; fi
runner_lock
runner_tree tree
runner_preflight
runner_header 'Machine gate'
if [ -n "${GATE_SETUP:-}" ]; then
  runner_phase setup "$GATE_SETUP"
  if ! { [ "$PHASE_FAILED" -eq 0 ] && runner_clean_tree; }; then runner_finish 1 'FAILED: setup failed or changed code'; fi
fi
runner_phase gate "$@"
[ "$PHASE_FAILED" -eq 0 ] || runner_finish 1 FAILED
if ! { runner_unchanged && runner_clean_tree; }; then runner_finish 1 'FAILED: HEAD or code changed during gate'; fi
runner_finish 0 passed
