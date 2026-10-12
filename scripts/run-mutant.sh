#!/bin/bash
# Proves a check can fail: breaks the code on purpose and records the check
# going red. Runs in a throwaway worktree at HEAD, so the run's own tree is
# never touched.
#   run-mutant.sh <workdir> <evidence-file> <label> <patch-file> <command> [<command> ...]
# The commands first run on the unpatched commit and must all pass (otherwise
# a red result could come from the worktree, not the patch). Then the patch is
# applied and the mutant is killed when at least one command fails.
# Env: MUTANT_SETUP shell string run in the worktree before anything else
# (install or link dependencies the worktree lacks), GATE_TIMEOUT seconds per
# command (default 3600), GATE_TAIL_LINES (default 40).
# Exit status: 0 mutant killed; 1 mutant survived — the check proves nothing;
# 2 baseline red or setup failed — inconclusive; 64 usage; 65 patch does not
# apply; 66 not found; 69 missing tool; 70 internal; 73 evidence exists.
set -uo pipefail

[ $# -ge 5 ] || {
  echo "usage: run-mutant.sh <workdir> <evidence-file> <label> <patch-file> <command> [<command> ...]" >&2
  exit 64
}
SCRIPT="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
. "$(dirname "$SCRIPT")/lib.sh"
require git perl

EVIDENCE="$(abs_path "$2")" || exit 70
[ -f "$4" ] || die 66 "patch not found: $4"
PATCH="$(abs_path "$4")" || exit 70
WORKDIR="$(cd "$1" 2>/dev/null && pwd -P)" || die 66 "workdir not found: $1"
LABEL="$3"
shift 4
TIMEOUT="${GATE_TIMEOUT:-3600}"
TAIL_LINES="${GATE_TAIL_LINES:-40}"

cd "$WORKDIR" || die 66 "cannot enter $WORKDIR"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die 66 "not a git work tree: $WORKDIR"
TOP="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
SUBDIR="${WORKDIR#"$TOP"}"
COMMIT="$(git rev-parse --verify HEAD)" || die 66 "HEAD does not name a commit"
[ -e "$EVIDENCE" ] && die 73 "evidence file already exists: $EVIDENCE"

WORK="$(make_temp_dir mutant)" || exit 70
TREE="$WORK/tree"
OUTPUT="$WORK/output"
cleanup() {
  git -C "$TOP" worktree remove --force "$TREE" >/dev/null 2>&1 || true
  git -C "$TOP" worktree prune >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT
git -C "$TOP" worktree add --quiet --detach "$TREE" "$COMMIT" || die 70 "cannot create a worktree at $COMMIT"
git -C "$TREE" apply --check "$PATCH" 2>"$OUTPUT" || die 65 "patch does not apply at $COMMIT: $(cat "$OUTPUT")"

{
  printf '# Mutant — %s\n\n' "$LABEL"
  printf -- '- commit: %s\n' "$COMMIT"
  printf -- '- recorded by: %s (sha256 %s)\n' "$SCRIPT" "$(sha256_of "$SCRIPT")"
  printf -- '- started: %s\n' "$(date -u +%FT%TZ)"
  printf -- '- patch (sha256 %s):\n\n```diff\n' "$(sha256_of "$PATCH")"
  cat "$PATCH"
  printf '```\n\n'
} >"$EVIDENCE"

# run_phase <phase> <command...>: runs each command in the worktree, records
# it, and prints how many failed.
run_phase() {
  local phase="$1" failures=0 command status
  shift
  printf '## %s\n\n' "$phase" >>"$EVIDENCE"
  for command in "$@"; do
    (cd "$TREE$SUBDIR" && with_timeout "$TIMEOUT" bash -o pipefail -c "$command" </dev/null) >"$OUTPUT" 2>&1
    status=$?
    [ "$status" -eq 0 ] || failures=$((failures + 1))
    {
      printf '```sh\n%s\n```\n\nexit %d%s\n\n```\n' "$command" "$status" \
        "$([ "$status" -eq 124 ] && echo " (timed out after ${TIMEOUT}s)")"
      tail -n "$TAIL_LINES" "$OUTPUT" | strip_colour | sed -E 's/[[:space:]]+$//'
      printf '```\n\n'
    } >>"$EVIDENCE"
    echo "[$phase] exit $status: $command" >&2
  done
  echo "$failures"
}

finish() {
  printf -- '- finished: %s\n- result: %s\n' "$(date -u +%FT%TZ)" "$2" >>"$EVIDENCE"
  echo "$2" >&2
  exit "$1"
}

if [ -n "${MUTANT_SETUP:-}" ]; then
  [ "$(run_phase setup "$MUTANT_SETUP")" -eq 0 ] || finish 2 "INCONCLUSIVE: setup failed"
fi
[ "$(run_phase "baseline (unpatched)" "$@")" -eq 0 ] ||
  finish 2 "INCONCLUSIVE: the check is red without the patch"
git -C "$TREE" apply "$PATCH" || die 70 "patch failed to apply after --check passed"
[ "$(run_phase "mutant (patched)" "$@")" -gt 0 ] ||
  finish 1 "SURVIVED: the check stayed green with the code broken — it proves nothing"
finish 0 "KILLED: the check went red"
