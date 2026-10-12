#!/bin/bash
# Codex adversary for the autopilot review gate. Codex runs in its read-only
# sandbox inside a throwaway worktree checked out at the pinned head, so it
# reviews exactly that commit while the run keeps working. The only files this
# writes are the findings file and its log.
#   codex-review.sh <repo> <base-ref> <run-record> <out-file> [focus ...]
# Env: CODEX_REVIEW_HEAD (default HEAD; pin it when work continues during the
# review), CODEX_REVIEW_EFFORT (default high), CODEX_REVIEW_TIMEOUT seconds
# (default 1800), CODEX_REVIEW_MODEL (unset: codex's own configured model —
# the contract pins this, so a run never reads ~/.codex to pick one).
# Exit status: 0 findings written and valid; 64 usage; 65 bad ref; 66 not
# found; 69 missing tool (codex absent: fall back per SKILL.md); 70 codex wrote
# no or invalid findings; 75 timed out; otherwise codex's own status.
set -euo pipefail

usage() {
  echo "usage: codex-review.sh <repo> <base-ref> <run-record> <out-file> [focus ...]" >&2
  exit 64
}
[ $# -ge 4 ] || usage

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$SKILL_DIR/scripts/lib.sh"
require git perl jq codex

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

BASE_SHA="$(git -C "$REPO" rev-parse --verify --quiet "$BASE^{commit}")" ||
  die 65 "base ref does not resolve to a commit: $BASE"
HEAD_SHA="$(git -C "$REPO" rev-parse --verify --quiet "$HEAD_REF^{commit}")" ||
  die 65 "head ref does not resolve to a commit: $HEAD_REF"
[ -f "$RECORD" ] || die 66 "run record not found: $RECORD"

LOG="${OUT%.json}.log"
# Never let a previous round's findings pass for this one.
rm -f "$OUT" "$LOG"

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
CONTRACT="$TREE/docs/autopilot.md"
[ -f "$CONTRACT" ] || CONTRACT="none (no contract at the reviewed head)"

{
  printf '<inputs>\n'
  printf 'Repository: %s (a checkout of the head commit; the original is %s)\n' "$TREE" "$REPO"
  printf 'Base: %s (%s)\n' "$BASE_SHA" "$BASE"
  printf 'Head: %s (%s)\n' "$HEAD_SHA" "$HEAD_REF"
  printf 'Run record: %s (snapshot taken when this review started)\n' "$WORK/run-record.md"
  printf 'Contract: %s\n' "$CONTRACT"
  printf 'Focus: %s\n' "$FOCUS"
  printf '</inputs>\n\n'
  cat "$SKILL_DIR/CODEX-BRIEF.md"
} >"$WORK/prompt.md"

# The -c values keep the TOML string quotes the effort flag already uses. The
# array is never empty: bash 3.2 (what macOS ships) faults on expanding an
# empty array under set -u.
CODEX_ARGS=(exec --sandbox read-only --cd "$TREE" --color never
  -c "model_reasoning_effort=\"$EFFORT\"")
if [ -n "$MODEL" ]; then
  CODEX_ARGS+=(-c "model=\"$MODEL\"")
fi
CODEX_ARGS+=(--output-schema "$SKILL_DIR/codex-findings.schema.json"
  --output-last-message "$OUT")

set +e
with_timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" - <"$WORK/prompt.md" >"$LOG" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 124 ]; then
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

# The schema the model is held to stays within what structured output
# accepts; the stricter checks, and verdict/severity agreement, live here.
if ! jq -e '
  (.verdict | IN("approve", "needs-attention"))
  and (.summary | type == "string")
  and (.limits | type == "string")
  and (.findings | type == "array")
  and all(.findings[];
    (.severity | IN("blocking", "minor"))
    and (.file | type == "string" and length > 0)
    and (.line_start | type == "number" and . >= 1)
    and (.line_end | type == "number" and . >= 1)
    and .line_end >= .line_start
    and (.confidence | type == "number" and . >= 0 and . <= 1))
  and ((.verdict == "approve") == ([.findings[] | select(.severity == "blocking")] | length == 0))
' "$OUT" >/dev/null 2>&1; then
  mv "$OUT" "$OUT.invalid"
  die 70 "codex findings fail validation: $OUT.invalid; log: $LOG"
fi
echo "head: $HEAD_SHA"
echo "findings: $OUT"
echo "log: $LOG"
