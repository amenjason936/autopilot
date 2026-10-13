#!/bin/bash
# Runs the machine gate on committed code and records it as evidence.
#   run-gate.sh <workdir> <evidence-file> <label> <command> [<command> ...]
# Each command is one shell string, run in <workdir> under `bash -o pipefail`
# with stdin closed and no controlling terminal. Every command runs even after
# a failure, so one run shows everything that is red.
#
# Record paths — the evidence file's directory and $AUTOPILOT_RECORD (the run
# record) — may be dirty: the run updates them between commits. Everything
# else must be committed. The tested commit is the latest commit that changed
# anything outside the record paths, so record commits never move it.
#
# Env: AUTOPILOT_RECORD run record path; GATE_TIMEOUT seconds per command
#   (default 3600, 0 = none); GATE_TAIL_LINES output lines kept for a passing
#   command (default 40); GATE_FAIL_LINES for a failing one (default 200);
#   GATE_KEEP_REGEX lines always kept (the suite's verdict line); GATE_ENV
#   space-separated variable names whose values the evidence records.
# The evidence is written to <evidence-file>.partial and renamed when the gate
# finishes; a leftover .partial is a cut-off run and is replaced.
# Exit status: 0 all passed; 1 any failed, timed out, or the gate changed the
# tree; 64 usage or bad setting; 65 uncommitted code; 66 not found / not a git
# work tree; 69 missing tool; 70 internal; 73 evidence file already exists;
# 129/130/143 interrupted.
set -uo pipefail

[ $# -ge 4 ] || {
  echo "usage: run-gate.sh <workdir> <evidence-file> <label> <command> [<command> ...]" >&2
  exit 64
}
SCRIPT="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
. "$(dirname "$SCRIPT")/lib.sh"
require git perl

# Resolve paths before cd, so relative paths mean the caller's.
EVIDENCE="$(abs_path "$2")" || exit 70
RECORD=""
[ -n "${AUTOPILOT_RECORD:-}" ] && { RECORD="$(abs_path "$AUTOPILOT_RECORD")" || exit 70; }
WORKDIR="$(cd "$1" 2>/dev/null && pwd -P)" || die 66 "workdir not found: $1"
LABEL="$3"
shift 3
TIMEOUT="${GATE_TIMEOUT:-3600}"
TAIL_LINES="${GATE_TAIL_LINES:-40}"
FAIL_LINES="${GATE_FAIL_LINES:-200}"
KEEP_REGEX="${GATE_KEEP_REGEX:-}"
require_seconds GATE_TIMEOUT "$TIMEOUT"
require_seconds GATE_TAIL_LINES "$TAIL_LINES"
require_seconds GATE_FAIL_LINES "$FAIL_LINES"
set -f
ENV_NAMES=(${GATE_ENV:-})
set +f
for NAME in ${ENV_NAMES[@]+"${ENV_NAMES[@]}"}; do
  echo "$NAME" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$' || die 64 "GATE_ENV: not a variable name: $NAME"
done

cd "$WORKDIR" || die 66 "cannot enter $WORKDIR"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die 66 "not a git work tree: $WORKDIR"
TOP="$(git rev-parse --show-toplevel)" || die 66 "cannot find the repository top"
TOP="$(cd "$TOP" && pwd -P)"
git rev-parse --verify --quiet HEAD >/dev/null || die 66 "HEAD does not name a commit"
EVIDENCE_DIR="$(dirname "$EVIDENCE")"
case "$WORKDIR/" in
  "$EVIDENCE_DIR"/*) die 64 "the evidence directory contains the workdir: give evidence its own directory" ;;
esac
record_specs "$TOP" "$EVIDENCE_DIR" "$RECORD"
HEAD_SHA="$(git rev-parse --verify HEAD)"
TESTED="$(tested_commit "$TOP")" || die 70 "cannot find the tested commit"

[ -e "$EVIDENCE" ] && die 73 "evidence file already exists: $EVIDENCE
Evidence is never overwritten: use a label unique to this run of the check, e.g. ${LABEL}-rerun-${TESTED:0:12}.md"
REPLACED=""
if [ -e "$EVIDENCE.partial" ]; then
  REPLACED="$(sed -n 's/^- started: //p' "$EVIDENCE.partial" | head -1)"
  echo "replacing a cut-off run: $EVIDENCE.partial" >&2
  rm -f "$EVIDENCE.partial"
fi

DIRTY="$(cd "$TOP" && git_code status --porcelain)" || die 66 "git status failed"
if [ -n "$DIRTY" ]; then
  echo "uncommitted code: commit it first, so the evidence names the code it tested" >&2
  printf '%s\n' "$DIRTY" >&2
  exit 65
fi

OUTPUT="$(make_temp gate)" || exit 70
PARTIAL="$EVIDENCE.partial"
trap 'rm -f "$OUTPUT"' EXIT

{
  printf '# Machine gate — %s\n\n' "$LABEL"
  printf -- '- tested commit: %s\n' "$TESTED"
  [ "$HEAD_SHA" = "$TESTED" ] || printf -- '- HEAD: %s (record commits only since the tested commit)\n' "$HEAD_SHA"
  printf -- '- code: committed (the gate refuses to start otherwise)\n'
  [ -z "$REPLACED" ] || printf -- '- replaces a cut-off run of this label started %s\n' "$REPLACED"
  printf -- '- recorded by: %s (sha256 %s)\n' "$SCRIPT" "$(sha256_of "$SCRIPT")"
  printf -- '- started: %s\n' "$(date -u +%FT%TZ)"
  printf -- '- workdir: %s\n' "$WORKDIR"
  printf -- '- timeout per command: %s s\n' "$TIMEOUT"
  for NAME in ${ENV_NAMES[@]+"${ENV_NAMES[@]}"}; do
    printf -- '- env %s=%s\n' "$NAME" "${!NAME-<unset>}"
  done
  printf '\n'
} >"$PARTIAL"

FAILED=0
NUMBER=0
for COMMAND in "$@"; do
  NUMBER=$((NUMBER + 1))
  STARTED=$(date +%s)
  with_timeout "$TIMEOUT" bash -o pipefail -c "$COMMAND" </dev/null >"$OUTPUT" 2>&1
  STATUS=$?
  SECONDS_TAKEN=$(($(date +%s) - STARTED))
  KEEP="$TAIL_LINES"
  if [ "$STATUS" -ne 0 ]; then
    FAILED=1
    KEEP="$FAIL_LINES"
  fi
  {
    printf '## %d. %s\n\n' "$NUMBER" "$([ "$STATUS" -eq 0 ] && echo passed || echo FAILED)"
    printf '```sh\n%s\n```\n\n' "$COMMAND"
    if [ "$TIMED_OUT" -eq 1 ]; then
      printf 'TIMED OUT after %d s\n\n' "$TIMEOUT"
    else
      printf 'exit %d · %d s\n\n' "$STATUS" "$SECONDS_TAKEN"
    fi
    printf 'last %s of %s output lines:\n\n```\n' "$KEEP" "$(awk 'END { print NR }' "$OUTPUT")"
    tail -n "$KEEP" "$OUTPUT" | clean_output
    printf '```\n\n'
    if [ -n "$KEEP_REGEX" ]; then
      printf 'lines matching `%s`:\n\n```\n' "$KEEP_REGEX"
      strip_colour <"$OUTPUT" | grep -anE -- "$KEEP_REGEX" | tail -n 20 | clean_output
      printf '```\n\n'
    fi
  } >>"$PARTIAL"
  echo "[$NUMBER] exit $STATUS (${SECONDS_TAKEN}s): $COMMAND"
done

# A gate that changed code did not test the commit it names, and leaves the
# next gate a dirty tree. Either is a failure; record paths are exempt.
AFTER="$(cd "$TOP" && git_code status --porcelain)" || die 70 "git status failed"
if [ -n "$AFTER" ]; then
  FAILED=1
  printf -- '- FAILED: the gate changed the working tree (revert tracked changes; .gitignore build output):\n\n```\n%s\n```\n\n' \
    "$AFTER" >>"$PARTIAL"
  echo "the gate changed the working tree:" >&2
  printf '%s\n' "$AFTER" >&2
fi
printf -- '- finished: %s\n- result: %s\n' "$(date -u +%FT%TZ)" \
  "$([ "$FAILED" -eq 0 ] && echo passed || echo FAILED)" >>"$PARTIAL"
mv "$PARTIAL" "$EVIDENCE" || die 70 "cannot rename $PARTIAL"
echo "evidence: $EVIDENCE (tested commit $TESTED)"
exit "$FAILED"
