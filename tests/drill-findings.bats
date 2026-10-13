#!/usr/bin/env bats
load test_helper
# Regressions for the third token-watcher end-to-end run (sandboxed contract).

@test "JavaScript candidates mutate code outside string and template literals" {
  cat >"$REPO/app.js" <<'JS'
function show(s) {
  return 1;
}
JS
  commit_fixture
  base="$(git -C "$REPO" rev-parse HEAD)"
  cat >"$REPO/app.js" <<'JS'
function show(s) {
  const hasSid = (r) => r.session_id != null && r.session_id !== '';
  if (!s.events?.length) { hide(); return; }
  const title = `${s.tool} · ${s.id.slice(0, 18)} < x`;
  return hasSid(s);
}
JS
  commit_fixture
  run bash "$SKILL/scripts/suggest-mutants.sh" "$REPO" "$base" HEAD "$CASE/candidates"
  [ "$status" -eq 0 ]
  run python3 - "$CASE/candidates" <<'PY'
import json, pathlib, sys
d = pathlib.Path(sys.argv[1])
rows = json.load(open(d / 'candidates.json'))
kinds = {(r['line'], r['kind']) for r in rows}
assert (2, 'comparison') in kinds, kinds
assert (3, 'disable-guard') in kinds, kinds
assert (5, 'return-empty') in kinds, kinds
added = [l for r in rows for l in (d / r['patch']).read_text().splitlines() if l.startswith('+') and not l.startswith('+++')]
assert any("r.session_id == null && r.session_id !== ''" in l for l in added)
assert any("r.session_id != null || r.session_id !== ''" in l for l in added)
assert any('if (false) { hide(); return; }' in l for l in added)
# Nothing inside the template literal on line 4 is touched.
assert not any(r['line'] == 4 for r in rows), [r for r in rows if r['line'] == 4]
PY
  [ "$status" -eq 0 ]
  for patch in "$CASE/candidates/"*.patch; do
    run git -C "$REPO" apply --check "$patch"
    [ "$status" -eq 0 ]
  done
}

@test "register redacts a review file into the evidence directory and its MANIFEST" {
  gate first true
  printf 'reviewer saw API_KEY=abcdef and TOKENMETER_NO_KEYCHAIN=1\n' >"$CASE/review.json"
  run python3 "$SKILL/scripts/evidence.py" register "$EVID" "$CASE/review.json"
  [ "$status" -eq 0 ]
  grep -q 'API_KEY=<redacted>\|<redacted>' "$EVID/review.json"
  ! grep -q abcdef "$EVID/review.json"
  grep -q 'TOKENMETER_NO_KEYCHAIN=1' "$EVID/review.json"
  [ ! -e "$EVID/.autopilot.lock" ]
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID" first.md review.json
  [ "$status" -eq 0 ]
  # An existing name is refused and leaves the MANIFEST unchanged.
  before="$(cat "$EVID/MANIFEST")"
  run python3 "$SKILL/scripts/evidence.py" register "$EVID" "$CASE/review.json"
  [ "$status" -eq 1 ]
  [ "$(cat "$EVID/MANIFEST")" = "$before" ]
  [ ! -e "$EVID/.autopilot.lock" ]
}

@test "register refuses a symlinked source and waits for a held lock" {
  gate first true
  printf 'x\n' >"$CASE/real"
  ln -s "$CASE/real" "$CASE/link"
  run python3 "$SKILL/scripts/evidence.py" register "$EVID" "$CASE/link" link.txt
  [ "$status" -eq 1 ]
  [ ! -e "$EVID/link.txt" ]
  mkdir "$EVID/.autopilot.lock"
  ( sleep 1; rmdir "$EVID/.autopilot.lock" ) &
  run python3 "$SKILL/scripts/evidence.py" register "$EVID" "$CASE/real" real.txt
  wait
  [ "$status" -eq 0 ]
  grep -q '  real.txt$' "$EVID/MANIFEST"
}

@test "verify names a path argument instead of a generic integrity failure" {
  gate first true
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID" "$EVID/first.md"
  [ "$status" -eq 64 ]
  [[ "$output" == *"relative to the directory"* ]]
}

@test "switch values next to secret-looking names are not redacted" {
  run bash -c 'printf "%s\n" "TOKENMETER_NO_KEYCHAIN=1 KEY_ROTATION=off password: false API_KEY=1abc" | python3 "$1/scripts/redact.py"' _ "$SKILL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TOKENMETER_NO_KEYCHAIN=1"* ]]
  [[ "$output" == *"KEY_ROTATION=off"* ]]
  [[ "$output" == *"password: false"* ]]
  [[ "$output" != *"1abc"* ]]
}

@test "helpers that import siblings write no __pycache__ into scripts (issue #2)" {
  isolate_runner
  rm -rf "$SKILL/scripts/__pycache__"
  gate first true
  python3 "$SKILL/scripts/evidence.py" register "$EVID" "$REPO/value" value.txt
  run python3 "$SKILL/scripts/review_identity.py"
  [ ! -e "$SKILL/scripts/__pycache__" ]
}

@test "gate evidence says whether a command timed out" {
  gate quick true
  grep -q 'exit 0; timed out: no' "$EVID/quick.md"
}
