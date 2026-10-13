#!/usr/bin/env bats
load test_helper

@test "mutant KILLED requires green baseline and red mutant" {
  patch_value
  export MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$'
  run mutant killed 'test "$(cat value)" = safe || { echo ASSERT_VALUE_SAFE; exit 1; }'
  [ "$status" -eq 0 ]
  grep -q 'result: KILLED' "$EVID/killed.md"
  [ "$(cat "$REPO/value")" = safe ]
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID"
  [ "$status" -eq 0 ]
}

@test "mutant SURVIVED identifies weak tests" {
  patch_value
  run mutant survived 'test -f value'
  [ "$status" -eq 1 ]
  grep -q 'result: SURVIVED' "$EVID/survived.md"
}

@test "red baseline and failed setup are INCONCLUSIVE" {
  patch_value
  run mutant baseline false
  [ "$status" -eq 2 ]
  export MUTANT_SETUP=false
  run mutant setup true
  [ "$status" -eq 2 ]
}

@test "mutant missing command is not a KILLED result" {
  patch_value
  run mutant missing 'if test "$(cat value)" = safe; then true; else absent_autopilot_test_command; fi'
  [ "$status" -eq 2 ]
}

@test "mutant setup cannot change baseline source" {
  patch_value
  export MUTANT_SETUP='printf broken > value'
  run mutant changed true
  [ "$status" -eq 2 ]
}

@test "mutant preserves prior partial and refuses invalid patch" {
  patch_value
  export GATE_RERUN_POLICY=safe
  printf old >"$EVID/retry.md.partial"
  export MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$'
  run mutant retry 'test "$(cat value)" = safe || { echo ASSERT_VALUE_SAFE; exit 1; }'
  [ "$status" -eq 0 ]
  run bash -c 'cat "$1"/retry.md.partial.*' _ "$EVID"
  [ "$output" = old ]
  printf nonsense >"$CASE/change.patch"
  run mutant bad true
  [ "$status" -eq 65 ]
}
