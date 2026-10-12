#!/bin/bash
# Codex adversary for the autopilot review gate. Codex runs in its read-only
# sandbox inside a throwaway worktree checked out at the pinned head, so it
# reviews exactly that commit while the run keeps working. The only files this
# writes are the findings file and its log.
#   codex-review.sh [--prompt-only] <repo> <base-ref> <run-record> <out-file> [focus ...]
# --prompt-only prints the adversary prompt for a fallback reviewer (no codex
# needed) instead of running codex; that reviewer writes <out-file>, and
# validate-findings.sh checks it.
# Put <out-file> outside the work tree — e.g. under
# "$(git rev-parse --git-common-dir)/autopilot/" — so it never dirties a gate.
# Env: CODEX_REVIEW_HEAD (default HEAD; pin it when work continues during the
# review), CODEX_REVIEW_EFFORT (default high), CODEX_REVIEW_TIMEOUT seconds
# (default 1800), CODEX_REVIEW_MODEL (unset: codex's own configured model —
# the contract pins this, so a run never reads ~/.codex to pick one).
# Exit status: 0 findings written and valid (or prompt printed); 64 usage or
# bad setting; 65 bad ref; 66 not found; 69 missing tool; 70 codex wrote no
# or invalid findings; 75 timed out; 129/130/143 interrupted; otherwise
# codex's own status.
set -euo pipefail

usage() {
  echo "usage: codex-review.sh [--prompt-only] <repo> <base-ref> <run-record> <out-file> [focus ...]" >&2
  exit 64
}
PROMPT_ONLY=0
if [ "${1:-}" = "--prompt-only" ]; then
  PROMPT_ONLY=1
  shift
fi
[ $# -ge 4 ] || usage

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$SKILL_DIR/scripts/lib.sh"
require git
[ "$PROMPT_ONLY" -eq 1 ] || require perl jq codex

REPO="$(cd "$1" 2>/dev/null && pwd -P)" || die 66 "repo not found: $1"
BASE="$2"
RECORD="$3"
OUT="$(abs_path "$4")"
shift 4
FOCUS="${*:-none}"
EFFORT="${CODEX_REVIEW_EFFORT:-high}"
TIMEOUT="${CODEX_REVIEW_TIMEOUT:-1800}"
MODEL="${CODEX_REVIEW_MODEL:-}"
HEAD_REF="${CODEX_REVIEW_HEAD:-HEAD}"
require_seconds CODEX_REVIEW_TIMEOUT "$TIMEOUT"

BASE_SHA="$(git -C "$REPO" rev-parse --verify --quiet "$BASE^{commit}")" ||
  die 65 "base ref does not resolve to a commit: $BASE"
HEAD_SHA="$(git -C "$REPO" rev-parse --verify --quiet "$HEAD_REF^{commit}")" ||
  die 65 "head ref does not resolve to a commit: $HEAD_REF"
[ -f "$RECORD" ] || die 66 "run record not found: $RECORD"
SCHEMA="$SKILL_DIR/codex-findings.schema.json"

# inputs <repository line> <record path> <output line>
inputs() {
  printf '<inputs>\n'
  printf 'Repository: %s\n' "$1"
  printf 'Base: %s (%s)\n' "$BASE_SHA" "$BASE"
  printf 'Head: %s (%s)\n' "$HEAD_SHA" "$HEAD_REF"
  printf 'Run record: %s\n' "$2"
  printf 'Contract: docs/autopilot.md at the head, if present\n'
  printf 'Focus: %s\n' "$FOCUS"
  printf 'Schema: %s\n' "$SCHEMA"
  printf 'Output: %s\n' "$3"
  printf '</inputs>\n\n'
  cat "$SKILL_DIR/CODEX-BRIEF.md"
}

if [ "$PROMPT_ONLY" -eq 1 ]; then
  inputs "$REPO (its working tree may be newer than the head: read the head with \`git show $HEAD_SHA:<path>\`, or check it out in a worktree of your own)" \
    "$(cd "$(dirname "$RECORD")" && pwd -P)/$(basename "$RECORD")" \
    "write the JSON to $OUT, then run: bash $SKILL_DIR/scripts/validate-findings.sh $OUT"
  exit 0
fi

LOG="${OUT%.json}.log"
# Never let a previous round's findings pass for this one.
rm -f "$OUT" "$LOG" "$OUT.invalid"

WORK="$(make_temp_dir codex)"
TREE="$WORK/tree"
cleanup() {
  git -C "$REPO" worktree remove --force "$TREE" >/dev/null 2>&1 || true
  git -C "$REPO" worktree prune >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT
git -C "$REPO" worktree add --quiet --detach "$TREE" "$HEAD_SHA" ||
  die 70 "cannot check out $HEAD_SHA in a temporary worktree"

# Snapshot the run record: the live one keeps changing during the review.
cp "$RECORD" "$WORK/run-record.md"
inputs "$TREE (a checkout of the head; the original is $REPO)" \
  "$WORK/run-record.md (snapshot taken when this review started)" \
  "your final message, as JSON" >"$WORK/prompt.md"

# The -c values keep the TOML string quotes the effort flag already uses. The
# array is never empty: bash 3.2 (what macOS ships) faults on expanding an
# empty array under set -u.
CODEX_ARGS=(exec --sandbox read-only --cd "$TREE" --color never
  -c "model_reasoning_effort=\"$EFFORT\"")
if [ -n "$MODEL" ]; then
  CODEX_ARGS+=(-c "model=\"$MODEL\"")
fi
CODEX_ARGS+=(--output-schema "$SCHEMA" --output-last-message "$OUT")

set +e
with_timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" - <"$WORK/prompt.md" >"$LOG" 2>&1
STATUS=$?
set -e

if [ "$TIMED_OUT" -eq 1 ]; then
  rm -f "$OUT"
  die 75 "codex review timed out after ${TIMEOUT}s; log: $LOG"
fi
if [ "$STATUS" -ne 0 ]; then
  rm -f "$OUT"
  echo "codex exited $STATUS; log: $LOG" >&2
  tail -20 "$LOG" >&2
  exit "$STATUS"
fi
[ -s "$OUT" ] || die 70 "codex wrote no findings; log: $LOG"

if ! bash "$SKILL_DIR/scripts/validate-findings.sh" "$OUT" >/dev/null; then
  mv "$OUT" "$OUT.invalid"
  die 70 "codex findings fail validation: $OUT.invalid; log: $LOG"
fi
echo "head: $HEAD_SHA"
echo "findings: $OUT"
echo "log: $LOG"
