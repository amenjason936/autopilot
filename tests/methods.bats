#!/usr/bin/env bats
load test_helper

@test "lite requires <=50 changed lines, one stage, no network or publish" {
  base="$(git -C "$REPO" rev-parse HEAD)"
  printf 'one\n' >"$REPO/small"
  commit_fixture
  printf '{"stages":1,"network":false,"publish":false}' >"$CASE/run.json"
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 0 ]
  export AUTOPILOT_BASE="$base" AUTOPILOT_RUN_CONFIG="$CASE/run.json"
  run bash "$SKILL/scripts/run-gate.sh" --dry-run --lite "$REPO" "$EVID/lite.md" lite true
  [ "$status" -eq 0 ]
  for config in '{"stages":2,"network":false,"publish":false}' '{"stages":1,"network":true,"publish":false}' '{"stages":1,"network":false,"publish":true}'; do
    printf '%s' "$config" >"$CASE/run.json"
    run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
    [ "$status" -eq 1 ]
  done
  printf '{"stages":1,"network":false,"publish":false}' >"$CASE/run.json"
  seq 51 >"$REPO/large"
  commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 1 ]
}

@test "mutant suggestions touch only added diff lines and produce applicable patches" {
  cat >"$REPO/subject.py" <<'PY'
def keep(x):
    return x + 20

def check(x):
    if x < 10:
        return 0
    return x
PY
  commit_fixture
  base="$(git -C "$REPO" rev-parse HEAD)"
  sed 's/x < 10/x <= 10/' "$REPO/subject.py" >"$CASE/new"
  cp "$CASE/new" "$REPO/subject.py"
  commit_fixture
  run bash "$SKILL/scripts/suggest-mutants.sh" "$REPO" "$base" HEAD "$CASE/candidates"
  [ "$status" -eq 0 ]
  run python3 -c 'import json,sys; a=json.load(open(sys.argv[1])); assert len(a)>=3; assert all(x["line"]==5 and x["selected_by"] is None for x in a)' "$CASE/candidates/candidates.json"
  [ "$status" -eq 0 ]
  for patch in "$CASE/candidates/"*.patch; do
    run git -C "$REPO" apply --check "$patch"
    [ "$status" -eq 0 ]
  done
}

@test "findings schema checks verdict extra keys line range and multiple JSON documents" {
  printf '{"verdict":"approve","summary":"ok","findings":[],"limits":"none"}' >"$CASE/findings.json"
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/findings.json"
  [ "$status" -eq 0 ]
  printf '{"verdict":"needs-attention","summary":"ok","findings":[],"limits":"none"}' >"$CASE/findings.json"
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/findings.json"
  [ "$status" -eq 70 ]
  printf '{}\n{}\n' >"$CASE/findings.json"
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/findings.json"
  [ "$status" -eq 70 ]
}

@test "review prompt binds record to head and refuses overwrites" {
  printf 'frozen record\n' >"$REPO/record.md"
  commit_fixture
  printf 'uncommitted newer record\n' >"$REPO/record.md"
  run bash "$SKILL/scripts/codex-review.sh" --prompt-only "$REPO" HEAD "$REPO/record.md" "$CASE/findings.json"
  [ "$status" -eq 0 ]
  [ "$(cat "$CASE/findings.run-record.md")" = 'frozen record' ]
  [[ "$output" == *'untrusted'* ]]
  run bash "$SKILL/scripts/codex-review.sh" --prompt-only "$REPO" HEAD "$REPO/record.md" "$CASE/findings.json"
  [ "$status" -eq 73 ]
}

@test "review CLI validates synthetic findings and redacts its log without a live model" {
  printf 'record\n' >"$REPO/record.md"
  commit_fixture
  mkdir "$CASE/bin"
  cat >"$CASE/bin/codex" <<'MOCK'
#!/bin/bash
while [ $# -gt 0 ]; do
  if [ "$1" = --output-last-message ]; then out="$2"; shift; fi
  shift
done
printf 'sk-syntheticLogSecret\n'
printf '{"verdict":"approve","summary":"ok","findings":[],"limits":"mock CLI only"}' >"$out"
MOCK
  chmod +x "$CASE/bin/codex"
  export PATH="$CASE/bin:$PATH"
  run bash "$SKILL/scripts/codex-review.sh" "$REPO" HEAD "$REPO/record.md" "$CASE/review.json"
  [ "$status" -eq 0 ]
  ! grep -q sk-syntheticLogSecret "$CASE/review.log"
  [ ! -d "$CASE/review.json.lock" ]
}

@test "suggested patches preserve files without a final newline" {
  printf 'value = 1' >"$REPO/end.py"
  commit_fixture
  base="$(git -C "$REPO" rev-parse HEAD)"
  printf 'value = 2' >"$REPO/end.py"
  commit_fixture
  run bash "$SKILL/scripts/suggest-mutants.sh" "$REPO" "$base" HEAD "$CASE/patches"
  [ "$status" -eq 0 ]
  for patch in "$CASE/patches/"*.patch; do
    run git -C "$REPO" apply --check "$patch"
    [ "$status" -eq 0 ]
  done
}
