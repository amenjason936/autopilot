#!/bin/bash
# Runs the machine gate on a clean commit and records it as evidence.
#   run-gate.sh <workdir> <evidence-file> <label> <command> [<command> ...]
# Each command is one shell string, run in <workdir>. Every command runs even
# after a failure, so one run shows everything that is red.
# Exit status: 0 when all passed, 1 when any failed, 65 when the tree is dirty.
set -uo pipefail

[ $# -ge 4 ] || {
  echo "usage: run-gate.sh <workdir> <evidence-file> <label> <command> [<command> ...]" >&2
  exit 64
}
WORKDIR="$(cd "$1" && pwd)" || { echo "workdir not found: $1" >&2; exit 66; }
EVIDENCE="$2"
LABEL="$3"
shift 3
TAIL_LINES="${GATE_TAIL_LINES:-15}"

cd "$WORKDIR" || exit 66
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "working tree is dirty: commit first, so the evidence names the code it tested" >&2
  git status --short >&2
  exit 65
fi
COMMIT="$(git rev-parse --short HEAD)"
mkdir -p "$(dirname "$EVIDENCE")"
OUTPUT="$(mktemp -t autopilot-gate)"
trap 'rm -f "$OUTPUT"' EXIT

{
  printf '# Machine gate — %s\n\n' "$LABEL"
  printf -- '- commit: %s\n' "$COMMIT"
  printf -- '- working tree: clean (the gate refuses to start otherwise)\n'
  printf -- '- recorded by: %s (sha256 %s)\n' "$0" "$(shasum -a 256 "$0" | cut -c1-16)"
  printf -- '- started: %s\n' "$(date -u +%FT%TZ)"
  printf -- '- workdir: %s\n\n' "$WORKDIR"
} >"$EVIDENCE"

FAILED=0
NUMBER=0
for COMMAND in "$@"; do
  NUMBER=$((NUMBER + 1))
  STARTED=$(date +%s)
  bash -c "$COMMAND" >"$OUTPUT" 2>&1
  STATUS=$?
  SECONDS_TAKEN=$(($(date +%s) - STARTED))
  [ "$STATUS" -eq 0 ] || FAILED=1
  {
    printf '## %d. `%s`\n\n' "$NUMBER" "$COMMAND"
    printf 'exit %d · %d s\n\n' "$STATUS" "$SECONDS_TAKEN"
    printf '```\n'
    # Strip terminal colour codes so the evidence reads as plain text.
    tail -n "$TAIL_LINES" "$OUTPUT" | sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g'
    printf '```\n\n'
  } >>"$EVIDENCE"
  echo "[$NUMBER] exit $STATUS (${SECONDS_TAKEN}s): $COMMAND"
done

if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
  printf -- '- note: the gate itself changed tracked files:\n\n```\n%s\n```\n\n' \
    "$(git status --short --untracked-files=no)" >>"$EVIDENCE"
fi
printf -- '- finished: %s\n- result: %s\n' "$(date -u +%FT%TZ)" \
  "$([ "$FAILED" -eq 0 ] && echo passed || echo FAILED)" >>"$EVIDENCE"
exit "$FAILED"
