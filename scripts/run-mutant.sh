#!/bin/bash
# Proves a check can fail: breaks the code on purpose and records the check
# going red. Runs in a throwaway worktree at HEAD, so the run's own tree is
# never touched.
#   run-mutant.sh <workdir> <evidence-file> <label> <patch-file> <command> [<command> ...]
# The commands first run on the unpatched commit and must all pass (otherwise
# a red result could come from the worktree, not the patch). Then the patch is
# applied and the mutant is killed when at least one command fails.
# Code must be committed, as for run-gate.sh: the check under test has to be
# in the worktree. Record paths (the evidence directory, $AUTOPILOT_RECORD)
# may be dirty, and a patch that touches them is refused. Make the patch with
# `git diff -- <files> > <patch>` after breaking the code, check the mutated
# files this prints are the ones you meant, then restore them with
# `git checkout -- <files>`. Keep the patch outside the work tree (e.g.
# "$(git rev-parse --git-common-dir)/autopilot/"): the evidence embeds it,
# and a raw patch fails whitespace checks.
# Env: AUTOPILOT_RECORD run record path; MUTANT_SETUP shell string run in the
# worktree before anything else (install or link dependencies the worktree
# lacks); GATE_TIMEOUT seconds per command (default 3600); GATE_TAIL_LINES
# (default 40).
# Exit status: 0 mutant killed; 1 mutant survived — the check proves nothing;
# 2 inconclusive (setup failed, baseline red, or the patch removed the
# workdir); 64 usage, bad setting, or the patch touches a record path; 65
# uncommitted code or the patch does not apply; 66 not found; 69 missing
# tool; 70 internal; 73 evidence exists; 129/130/143 interrupted.
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
RECORD=""
[ -n "${AUTOPILOT_RECORD:-}" ] && { RECORD="$(abs_path "$AUTOPILOT_RECORD")" || exit 70; }
WORKDIR="$(cd "$1" 2>/dev/null && pwd -P)" || die 66 "workdir not found: $1"
LABEL="$3"
shift 4
TIMEOUT="${GATE_TIMEOUT:-3600}"
TAIL_LINES="${GATE_TAIL_LINES:-40}"
require_seconds GATE_TIMEOUT "$TIMEOUT"
require_seconds GATE_TAIL_LINES "$TAIL_LINES"

cd "$WORKDIR" || die 66 "cannot enter $WORKDIR"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die 66 "not a git work tree: $WORKDIR"
TOP="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
SUBDIR="${WORKDIR#"$TOP"}"
git rev-parse --verify --quiet HEAD >/dev/null || die 66 "HEAD does not name a commit"
EVIDENCE_DIR="$(dirname "$EVIDENCE")"
case "$WORKDIR/" in
  "$EVIDENCE_DIR"/*) die 64 "the evidence directory contains the workdir: give evidence its own directory" ;;
esac
record_specs "$TOP" "$EVIDENCE_DIR" "$RECORD"
COMMIT="$(git rev-parse --verify HEAD)"
TESTED="$(tested_commit "$TOP")" || die 70 "cannot find the tested commit"
[ -e "$EVIDENCE" ] && die 73 "evidence file already exists: $EVIDENCE"
DIRTY="$(cd "$TOP" && git_code status --porcelain)" || die 66 "git status failed"
if [ -n "$DIRTY" ]; then
  echo "uncommitted code: commit the check first, so the worktree has it" >&2
  printf '%s\n' "$DIRTY" >&2
  exit 65
fi

WORK="$(make_temp_dir mutant)" || exit 70
TREE="$WORK/tree"
OUTPUT="$WORK/output"
PARTIAL="$EVIDENCE.partial"
rm -f "$PARTIAL"
cleanup() {
  git -C "$TOP" worktree remove --force "$TREE" >/dev/null 2>&1 || true
  git -C "$TOP" worktree prune >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT
git -C "$TOP" worktree add --quiet --detach "$TREE" "$COMMIT" || die 70 "cannot create a worktree at $COMMIT"
git -C "$TREE" apply --check "$PATCH" 2>"$OUTPUT" || die 65 "patch does not apply at $COMMIT: $(cat "$OUTPUT")"
MUTATED="$(git -C "$TREE" apply --numstat "$PATCH" | cut -f3)"
# A patch made with a bare `git diff` also carries the dirty run record.
while IFS= read -r FILE; do
  for REL in ${RECORD_RELS[@]+"${RECORD_RELS[@]}"}; do
    case "$FILE" in
      "$REL" | "$REL"/*) die 64 "the patch touches a record path ($FILE): make it with \`git diff -- <the files you broke>\`" ;;
    esac
  done
done <<EOF
$MUTATED
EOF
echo "mutating: $(printf '%s\n' "$MUTATED" | paste -sd ' ' -)" >&2

{
  printf '# Mutant — %s\n\n' "$LABEL"
  printf -- '- tested commit: %s\n' "$TESTED"
  [ "$COMMIT" = "$TESTED" ] || printf -- '- HEAD: %s (record commits only since the tested commit)\n' "$COMMIT"
  printf -- '- recorded by: %s (sha256 %s)\n' "$SCRIPT" "$(sha256_of "$SCRIPT")"
  printf -- '- started: %s\n' "$(date -u +%FT%TZ)"
  printf -- '- mutated files: %s\n' "$(printf '%s\n' "$MUTATED" | paste -sd ' ' -)"
  printf -- '- patch: %s (sha256 %s; shown with trailing whitespace stripped)\n\n```diff\n' "$PATCH" "$(sha256_of "$PATCH")"
  clean_output <"$PATCH"
  printf '```\n\n'
} >"$PARTIAL"

# run_phase <phase> <command...>: runs each command in the worktree, records
# it, and prints how many failed. Runs in a command substitution, so the cd
# stays local to it.
run_phase() {
  local phase="$1" failures=0 command status
  shift
  printf '## %s\n\n' "$phase" >>"$PARTIAL"
  cd "$TREE$SUBDIR" || return 1
  for command in "$@"; do
    with_timeout "$TIMEOUT" bash -o pipefail -c "$command" </dev/null >"$OUTPUT" 2>&1
    status=$?
    [ "$status" -eq 0 ] || failures=$((failures + 1))
    {
      printf '```sh\n%s\n```\n\nexit %d%s\n\n```\n' "$command" "$status" \
        "$([ "$TIMED_OUT" -eq 1 ] && echo " (timed out after ${TIMEOUT}s)")"
      tail -n "$TAIL_LINES" "$OUTPUT" | clean_output
      printf '```\n\n'
    } >>"$PARTIAL"
    echo "[$phase] exit $status: $command" >&2
  done
  echo "$failures"
}

finish() {
  printf -- '- finished: %s\n- result: %s\n' "$(date -u +%FT%TZ)" "$2" >>"$PARTIAL"
  mv "$PARTIAL" "$EVIDENCE" || die 70 "cannot rename $PARTIAL"
  echo "$2" >&2
  exit "$1"
}

if [ -n "${MUTANT_SETUP:-}" ]; then
  FAILURES="$(run_phase setup "$MUTANT_SETUP")" || finish 2 "INCONCLUSIVE: workdir missing in the worktree"
  [ "$FAILURES" -eq 0 ] || finish 2 "INCONCLUSIVE: setup failed"
fi
FAILURES="$(run_phase "baseline (unpatched)" "$@")" || finish 2 "INCONCLUSIVE: workdir missing in the worktree"
[ "$FAILURES" -eq 0 ] || finish 2 "INCONCLUSIVE: the check is red without the patch"
git -C "$TREE" apply "$PATCH" || die 70 "patch failed to apply after --check passed"
[ -d "$TREE$SUBDIR" ] || finish 2 "INCONCLUSIVE: the patch removed the workdir"
FAILURES="$(run_phase "mutant (patched)" "$@")" || finish 2 "INCONCLUSIVE: workdir missing in the worktree"
[ "$FAILURES" -gt 0 ] ||
  finish 1 "SURVIVED: the check stayed green with the code broken — it proves nothing"
finish 0 "KILLED: the check went red"
