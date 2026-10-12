#!/bin/bash
# Codex adversary for the autopilot review gate. Codex runs in its read-only
# sandbox, so the only file this writes is the findings file.
#   codex-review.sh <repo> <base-ref> <run-record> <out-file> [focus ...]
# Env: CODEX_REVIEW_HEAD (default HEAD; pin it when work continues during the
# review), CODEX_REVIEW_EFFORT (default high), CODEX_REVIEW_TIMEOUT seconds
# (default 1800), CODEX_REVIEW_MODEL (unset: codex's own configured model —
# contracts usually pin this, so a run never reads ~/.codex to pick one).
set -euo pipefail

usage() {
  echo "usage: codex-review.sh <repo> <base-ref> <run-record> <out-file> [focus ...]" >&2
  exit 64
}
[ $# -ge 4 ] || usage

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$1" && pwd)" || { echo "repo not found: $1" >&2; exit 66; }
BASE="$2"
RECORD="$3"
OUT="$4"
shift 4
FOCUS="${*:-none}"
EFFORT="${CODEX_REVIEW_EFFORT:-high}"
TIMEOUT="${CODEX_REVIEW_TIMEOUT:-1800}"

command -v codex >/dev/null || { echo "codex CLI not found on PATH" >&2; exit 69; }
git -C "$REPO" rev-parse --verify --quiet "$BASE^{commit}" >/dev/null ||
  { echo "base ref does not resolve to a commit: $BASE" >&2; exit 65; }
HEAD_REF="${CODEX_REVIEW_HEAD:-HEAD}"
git -C "$REPO" rev-parse --verify --quiet "$HEAD_REF^{commit}" >/dev/null ||
  { echo "head ref does not resolve to a commit: $HEAD_REF" >&2; exit 65; }
[ -f "$RECORD" ] || { echo "run record not found: $RECORD" >&2; exit 66; }
RECORD="$(cd "$(dirname "$RECORD")" && pwd)/$(basename "$RECORD")"

CONTRACT="$REPO/docs/autopilot.md"
[ -f "$CONTRACT" ] || CONTRACT="none (no contract in this repository)"

mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
LOG="${OUT%.json}.log"
PROMPT="$(mktemp -t autopilot-codex-prompt)"
trap 'rm -f "$PROMPT"' EXIT

{
  printf '<inputs>\n'
  printf 'Repository: %s\n' "$REPO"
  printf 'Base ref: %s (%s)\n' "$BASE" "$(git -C "$REPO" rev-parse --short "$BASE^{commit}")"
  printf 'Head: %s\n' "$(git -C "$REPO" rev-parse --short "$HEAD_REF^{commit}")"
  printf 'Run record: %s\n' "$RECORD"
  printf 'Contract: %s\n' "$CONTRACT"
  printf 'Focus: %s\n' "$FOCUS"
  printf '</inputs>\n\n'
  cat "$SKILL_DIR/CODEX-BRIEF.md"
} >"$PROMPT"

# The contract pins the model when the account's ~/.codex default is unusable
# (refused for its plan, say); runs must not read ~/.codex to find one, so the
# pin travels as an env var instead. The -c value keeps the TOML string quotes
# the effort flag already uses.
MODEL="${CODEX_REVIEW_MODEL:-}"

# perl's alarm gives a portable timeout; macOS ships no timeout(1).
# The array is never empty: bash 3.2 (what macOS ships) faults on expanding an
# empty array under set -u.
CODEX_ARGS=(exec --sandbox read-only --cd "$REPO" --color never
  -c "model_reasoning_effort=\"$EFFORT\"")
if [ -n "$MODEL" ]; then
  CODEX_ARGS+=(-c "model=\"$MODEL\"")
fi
CODEX_ARGS+=(--output-schema "$SKILL_DIR/codex-findings.schema.json"
  --output-last-message "$OUT")

set +e
perl -e 'alarm shift; exec @ARGV or die "exec failed: $!"' "$TIMEOUT" \
  codex "${CODEX_ARGS[@]}" \
  - <"$PROMPT" >"$LOG" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 142 ]; then
  echo "codex review timed out after ${TIMEOUT}s; log: $LOG" >&2
  exit 75
fi
if [ "$STATUS" -ne 0 ]; then
  echo "codex exited $STATUS; log: $LOG" >&2
  tail -20 "$LOG" >&2
  exit "$STATUS"
fi
[ -s "$OUT" ] || { echo "codex wrote no findings; log: $LOG" >&2; exit 70; }
echo "findings: $OUT"
echo "log: $LOG"
