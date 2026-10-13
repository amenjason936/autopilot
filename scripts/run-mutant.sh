#!/bin/bash
# run-mutant.sh [--dry-run] <workdir> <evidence-file> <label> <patch> <command>...
# Exit: 0 KILLED/preview; 1 SURVIVED; 2 INCONCLUSIVE (setup/baseline/infrastructure);
# 64 usage/policy/record patch; 65 dirty/invalid patch; 66 missing; 69 missing tool;
# 70 internal; 73 exists/locked; 77 sandbox failed; 129/130/143 signal.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
# shellcheck source=runner.sh
. "$SCRIPT_DIR/runner.sh"
ORIGINAL_ARGC=$#
runner_options "$@"
shift "$OPTIONS_CONSUMED"
[ "$LITE" -eq 0 ] && [ $# -ge 5 ] || die 64 'usage: run-mutant.sh [--dry-run] <workdir> <evidence-file> <label> <patch> <command>...'
[ -f "$4" ] && [ ! -L "$4" ] || die 66 'patch not found or symlink'
PATCH="$(resolve_path "$4")"
runner_init "$1" "$2" "$3"
if [ -n "${MUTANT_FAILURE_REGEX:-}" ]; then
  python3 "$SCRIPT_DIR/failure_signature.py" validate "$MUTANT_FAILURE_REGEX" "${MUTANT_FAILURE_EXIT:-1}" || die 64 'invalid mutant failure signature'
fi
shift 4
if [ "$DRY_RUN" -eq 1 ]; then
  runner_preview "$@"
  printf 'patch sha256: %s; baseline and mutant each run in a fresh worktree\n' "$(sha256_of "$PATCH")"
  exit 0
fi
runner_lock
# Copy the patch now: later edits to the caller's patch cannot alter this run.
cp "$PATCH" "$WORK/mutant.patch" || die 70 'cannot freeze patch'
PATCH="$WORK/mutant.patch"
runner_header Mutant
runner_tree tree
runner_probe || runner_finish 77 'INCONCLUSIVE: sandbox preflight (red line)'
git -C "$TREE" apply --check "$PATCH" >"$OUTPUT" 2>&1 || die 65 'patch does not apply at pinned HEAD'
MUTATED="$(git -C "$TREE" apply --numstat "$PATCH" | cut -f3)"
[ -n "$MUTATED" ] || die 65 'empty patch'
while IFS= read -r file; do
  for rel in ${RECORD_RELS[@]+"${RECORD_RELS[@]}"}; do
    case "$file" in "$rel"|"$rel"/*) die 64 'patch touches a record path' ;; esac
  done
done <<EOF
$MUTATED
EOF
{
  printf -- '- failure signature: %s; expected exit: %s\n' "${MUTANT_FAILURE_REGEX:-<unset; KILLED is unavailable>}" "${MUTANT_FAILURE_EXIT:-1}"
  printf -- '- mutated files: %s\n- patch sha256: %s\n\n```diff\n' "$MUTATED" "$(sha256_of "$PATCH")"
  cat "$PATCH"
  printf '\n```\n'
} | clean_output >>"$PARTIAL" || die 70 'cannot write mutation evidence'
SETUP="${MUTANT_SETUP:-${GATE_SETUP:-}}"
if [ -n "$SETUP" ]; then
  runner_phase 'baseline setup' "$SETUP"
  if ! { [ "$PHASE_FAILED" -eq 0 ] && runner_clean_tree; }; then runner_finish 2 'INCONCLUSIVE: baseline setup'; fi
fi
runner_phase 'baseline (unpatched)' "$@"
if ! { [ "$PHASE_FAILED" -eq 0 ] && runner_clean_tree && runner_unchanged; }; then runner_finish 2 'INCONCLUSIVE: baseline failed or changed code'; fi
BASELINE_TREE="$TREE"
runner_tree mutant
runner_probe || runner_finish 77 'INCONCLUSIVE: sandbox preflight (red line)'
if [ -n "$SETUP" ]; then
  runner_phase 'mutant setup' "$SETUP"
  if ! { [ "$PHASE_FAILED" -eq 0 ] && runner_clean_tree; }; then runner_finish 2 'INCONCLUSIVE: mutant setup'; fi
fi
git -C "$TREE" apply "$PATCH" >"$OUTPUT" 2>&1 || runner_finish 2 'INCONCLUSIVE: patch no longer applies'
[ -d "$TREE$SUBDIR" ] || runner_finish 2 'INCONCLUSIVE: patch removed workdir'
runner_phase 'mutant (patched)' "$@"
runner_unchanged || runner_finish 2 'INCONCLUSIVE: HEAD or source tree changed'
[ "$PHASE_INFRA" -eq 0 ] || runner_finish 2 'INCONCLUSIVE: timeout, signal or command unavailable'
[ "$PHASE_FAILED" -eq 1 ] || runner_finish 1 SURVIVED
[ "$PHASE_MATCHED" -eq 1 ] && [ "$PHASE_UNEXPECTED" -eq 0 ] || runner_finish 2 'INCONCLUSIVE: failure does not match the frozen signature'
runner_finish 0 KILLED
