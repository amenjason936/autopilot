#!/bin/bash
# Runs the machine gate on a clean commit and records it as evidence.
#   run-gate.sh <workdir> <evidence-file> <label> <command> [<command> ...]
# Each command is one shell string, run in <workdir> under `bash -o pipefail`
# with stdin closed. Every command runs even after a failure, so one run shows
# everything that is red.
# Env: GATE_TIMEOUT seconds per command (default 3600, 0 = none),
#   GATE_TAIL_LINES output lines kept for a passing command (default 40),
#   GATE_FAIL_LINES for a failing one (default 200), GATE_KEEP_REGEX lines
#   always kept whatever the tail (e.g. the suite's verdict line), GATE_ENV
#   space-separated variable names whose values the evidence records.
# Exit status: 0 all passed; 1 any failed, timed out, or the gate changed the
# tree; 64 usage; 65 tree dirty before the gate; 66 not found / not a git
# work tree; 69 missing tool; 70 internal; 73 evidence file already exists.
set -uo pipefail

[ $# -ge 4 ] || {
  echo "usage: run-gate.sh <workdir> <evidence-file> <label> <command> [<command> ...]" >&2
  exit 64
}
SCRIPT="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
. "$(dirname "$SCRIPT")/lib.sh"
require git perl

# Resolve the evidence path before cd, so a relative path means the caller's.
EVIDENCE="$(abs_path "$2")" || exit 70
WORKDIR="$(cd "$1" 2>/dev/null && pwd -P)" || die 66 "workdir not found: $1"
LABEL="$3"
shift 3
TIMEOUT="${GATE_TIMEOUT:-3600}"
TAIL_LINES="${GATE_TAIL_LINES:-40}"
FAIL_LINES="${GATE_FAIL_LINES:-200}"
KEEP_REGEX="${GATE_KEEP_REGEX:-}"

cd "$WORKDIR" || die 66 "cannot enter $WORKDIR"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die 66 "not a git work tree: $WORKDIR"
TOP="$(git rev-parse --show-toplevel)" || die 66 "cannot find the repository top"
TOP="$(cd "$TOP" && pwd -P)"
COMMIT="$(git rev-parse --verify HEAD)" || die 66 "HEAD does not name a commit"

[ -e "$EVIDENCE" ] && die 73 "evidence file already exists: $EVIDENCE
Evidence is never overwritten. Name each run's file after its commit, e.g. <label>-${COMMIT:0:12}.md"

DIRTY="$(git status --porcelain)" || die 66 "git status failed"
if [ -n "$DIRTY" ]; then
  echo "working tree is dirty: commit first (red evidence included), so the evidence names the code it tested" >&2
  printf '%s\n' "$DIRTY" >&2
  exit 65
fi

OUTPUT="$(make_temp gate)" || exit 70
trap 'rm -f "$OUTPUT"' EXIT

{
  printf '# Machine gate — %s\n\n' "$LABEL"
  printf -- '- commit: %s\n' "$COMMIT"
  printf -- '- working tree: clean (the gate refuses to start otherwise)\n'
  printf -- '- recorded by: %s (sha256 %s)\n' "$SCRIPT" "$(sha256_of "$SCRIPT")"
  printf -- '- started: %s\n' "$(date -u +%FT%TZ)"
  printf -- '- workdir: %s\n' "$WORKDIR"
  printf -- '- timeout per command: %s s\n' "$TIMEOUT"
  for NAME in ${GATE_ENV:-}; do
    printf -- '- env %s=%s\n' "$NAME" "${!NAME-<unset>}"
  done
  printf '\n'
} >"$EVIDENCE"

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
    if [ "$STATUS" -eq 124 ]; then
      printf 'TIMED OUT after %d s\n\n' "$TIMEOUT"
    else
      printf 'exit %d · %d s\n\n' "$STATUS" "$SECONDS_TAKEN"
    fi
    printf 'last %s of %s output lines:\n\n```\n' "$KEEP" "$(wc -l <"$OUTPUT" | tr -d ' ')"
    tail -n "$KEEP" "$OUTPUT" | strip_colour | sed -E 's/[[:space:]]+$//'
    printf '```\n\n'
    if [ -n "$KEEP_REGEX" ]; then
      printf 'lines matching `%s`:\n\n```\n' "$KEEP_REGEX"
      strip_colour <"$OUTPUT" | grep -nE -- "$KEEP_REGEX" | tail -n 20 | sed -E 's/[[:space:]]+$//'
      printf '```\n\n'
    fi
  } >>"$EVIDENCE"
  echo "[$NUMBER] exit $STATUS (${SECONDS_TAKEN}s): $COMMAND"
done

# A gate that changed the tree did not test the commit it names, and leaves
# the next gate a dirty tree. Either is a failure; the evidence file is exempt.
EXCLUDE="$(exclude_pathspec "$TOP" "$EVIDENCE")"
AFTER="$(git -C "$TOP" status --porcelain -- ':(top)' ${EXCLUDE:+"$EXCLUDE"})" || die 70 "git status failed"
if [ -n "$AFTER" ]; then
  FAILED=1
  printf -- '- FAILED: the gate changed the working tree (revert tracked changes; .gitignore build output):\n\n```\n%s\n```\n\n' \
    "$AFTER" >>"$EVIDENCE"
  echo "the gate changed the working tree:" >&2
  printf '%s\n' "$AFTER" >&2
fi
printf -- '- finished: %s\n- result: %s\n' "$(date -u +%FT%TZ)" \
  "$([ "$FAILED" -eq 0 ] && echo passed || echo FAILED)" >>"$EVIDENCE"
exit "$FAILED"
