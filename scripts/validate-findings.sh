#!/bin/bash
# Checks an adversary findings file against codex-findings.schema.json, more
# strictly than structured output can: exactly one JSON document, no missing
# or extra keys, whole positive line numbers, confidence in 0..1, non-empty
# file, and a verdict that agrees with the severities.
#   validate-findings.sh <findings.json>
# Exit status: 0 valid; 64 usage; 66 not found; 69 missing tool; 70 invalid
# (or a jq too old to run the check — the message says which).
set -uo pipefail

{ [ $# -eq 1 ] || [ $# -eq 7 ]; } || { echo "usage: validate-findings.sh <findings.json>" >&2; exit 64; }
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd -P)/lib.sh"
require jq
[ -s "$1" ] || die 66 "findings file missing or empty: $1"

# jq syntax intentionally contains literal dollar signs.
# shellcheck disable=SC2016
FILTER='
  def strings($o; $ks): all($ks[]; ($o[.] | type) == "string");
  def line($v): ($v | type) == "number" and $v == ($v | floor) and $v >= 1;
  length == 1
  and (.[0] | type) == "object"
  and (.[0] as $r
    | ($r | keys) == ["findings", "limits", "summary", "verdict"]
    and strings($r; ["summary", "limits"])
    and ($r.verdict == "approve" or $r.verdict == "needs-attention")
    and ($r.findings | type) == "array"
    and all($r.findings[];
      . as $f
      | type == "object"
      and keys == ["confidence", "file", "how_to_confirm", "line_end", "line_start",
                   "recommendation", "severity", "title", "what_goes_wrong", "why_vulnerable"]
      and strings($f; ["title", "file", "what_goes_wrong", "why_vulnerable", "how_to_confirm", "recommendation"])
      and ($f.file | length) > 0
      and ($f.severity == "blocking" or $f.severity == "minor")
      and line($f.line_start) and line($f.line_end) and $f.line_end >= $f.line_start
      and ($f.confidence | type) == "number" and $f.confidence >= 0 and $f.confidence <= 1)
    and (($r.verdict == "approve") == ([$r.findings[] | select(.severity == "blocking")] | length == 0)))
'
ERR="$(jq -se "$FILTER" "$1" 2>&1 >/dev/null)"
STATUS=$?
case "$STATUS" in
  0) echo "valid: $1" ;;
  1) die 70 "findings do not match the schema or contradict the verdict: $1" ;;
  3) die 70 "jq could not compile the check (jq $(jq --version 2>&1) too old?): $ERR" ;;
  *) die 70 "findings are not valid JSON: $1${ERR:+ — $ERR}" ;;
esac

# A one-argument call validates structure only and cannot authorize review reuse.
if [ $# -eq 7 ]; then
  SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
  python3 "$SKILL_DIR/scripts/review_identity.py" verify "$@" "$SKILL_DIR" || die 70 'findings do not belong to the expected review request and snapshot'
fi
