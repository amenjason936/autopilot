#!/usr/bin/env bats
load test_helper

@test "fallback rejects persistent helper tampering before using it or running another command" {
  isolate_runner
  unavailable_backend
  marker="$CASE/helper-executed"
  printf 'open("%s", "w").write("executed")\n' "$marker" >"$CASE/payload"
  run gate helper "cp '$CASE/payload' '$SKILL/scripts/failure_signature.py'; true" "touch '$CASE/next-command'"
  [ "$status" -eq 70 ]
  [[ "$output" == *'runner integrity check failed'* ]]
  [ ! -e "$marker" ]
  [ ! -e "$CASE/next-command" ]
  [ ! -e "$EVID/helper.md" ]
  [ ! -e "$EVID/MANIFEST" ]
}

@test "fallback detects frozen policy and source snapshot changes after each command" {
  isolate_runner
  unavailable_backend
  for name in policy.json tree-source.json; do
    run gate "control-$name" "printf corrupted > \"\$(dirname \"\$TMPDIR\")/$name\"; true" "touch '$CASE/next-command'"
    [ "$status" -eq 70 ]
    [[ "$output" == *'runner integrity check failed'* ]]
    [ ! -e "$CASE/next-command" ]
    [ ! -e "$EVID/control-$name.md" ]
  done
}

@test "fallback helper inventory catches added import shadows without executing them" {
  isolate_runner
  unavailable_backend
  printf 'open("%s", "w").write("executed")\n' "$CASE/import-executed" >"$CASE/payload"
  run gate shadow "cp '$CASE/payload' '$SKILL/scripts/hashlib.py'; true"
  [ "$status" -eq 70 ]
  [[ "$output" == *'runner integrity check failed'* ]]
  [ ! -e "$CASE/import-executed" ]
  [ ! -e "$EVID/shadow.md" ]
}

@test "fallback refuses setup tampering before a mutant can run or claim KILLED" {
  isolate_runner
  unavailable_backend
  patch_value
  export MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$'
  export MUTANT_SETUP="printf '\n# altered by setup\n' >> '$SKILL/scripts/source_state.py'; true"
  run mutant setup "touch '$CASE/detector-ran'; test \"\$(cat value)\" = safe || { echo ASSERT_VALUE_SAFE; exit 1; }"
  [ "$status" -eq 70 ]
  [[ "$output" == *'runner integrity check failed'* ]]
  [ ! -e "$CASE/detector-ran" ]
  [ ! -e "$EVID/setup.md" ]
}

@test "fallback checker and failure diagnostic do not reload tampered checker or redactor" {
  isolate_runner
  unavailable_backend
  printf 'open("%s", "w").write("executed")\n' "$CASE/checker-executed" >"$CASE/payload"
  run gate checker "cp '$CASE/payload' '$SKILL/scripts/integrity.py'; cp '$CASE/payload' '$SKILL/scripts/redact.py'; true"
  [ "$status" -eq 70 ]
  [[ "$output" == *'runner integrity check failed'* ]]
  [ ! -e "$CASE/checker-executed" ]
  [ ! -e "$EVID/checker.md" ]
}

@test "fallback rejects a rewritten snapshot that matches unauthorized source edits" {
  isolate_runner
  unavailable_backend
  run gate snapshot "printf changed >value; python3 '$SKILL/scripts/source_state.py' freeze \"\$PWD\" \"\$(dirname \"\$TMPDIR\")/policy.json\" \"\$(dirname \"\$TMPDIR\")/tree-source.json\"; true"
  [ "$status" -eq 70 ]
  [[ "$output" == *'runner integrity check failed'* ]]
  [ ! -e "$EVID/snapshot.md" ]
}

@test "fallback helper inventory detects missing and symlink-replaced helpers" {
  isolate_runner
  unavailable_backend
  run gate missing "mv '$SKILL/scripts/policy.py' '$CASE/policy-backup'; true"
  [ "$status" -eq 70 ]
  [[ "$output" == *'runner integrity check failed'* ]]
  cp "$CASE/policy-backup" "$SKILL/scripts/policy.py"
  # Same bytes through a symlink must not count as an unchanged helper.
  run gate linked "mv '$SKILL/scripts/policy.py' '$CASE/policy-backup-2'; ln -s '$CASE/policy-backup-2' '$SKILL/scripts/policy.py'; true"
  [ "$status" -eq 70 ]
  [[ "$output" == *'runner integrity check failed'* ]]
}

@test "fallback mutant retains control checks after refreshing the patched source snapshot" {
  isolate_runner
  unavailable_backend
  patch_value
  export MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$'
  run mutant patchcontrol 'if test "$(cat value)" = broken; then printf corrupted > "$(dirname "$TMPDIR")/mutant.patch"; echo ASSERT_VALUE_SAFE; exit 1; fi'
  [ "$status" -eq 70 ]
  [[ "$output" == *'runner integrity check failed'* ]]
  [ ! -e "$EVID/patchcontrol.md" ]
  run mutant positive 'test "$(cat value)" = safe || { echo ASSERT_VALUE_SAFE; exit 1; }'
  [ "$status" -eq 0 ]
  grep -q 'result: KILLED' "$EVID/positive.md"
}

@test "initial helper symlinks cannot hide mutable targets outside the checked directory" {
  isolate_runner
  unavailable_backend
  mv "$SKILL/scripts/policy.py" "$CASE/policy-target"
  ln -s "$CASE/policy-target" "$SKILL/scripts/policy.py"
  run gate initiallink "touch '$CASE/executed'"
  [ "$status" -eq 70 ]
  [[ "$output" == *'runner integrity check failed'* ]]
  [ ! -e "$CASE/executed" ]
  [ ! -e "$EVID/initiallink.md" ]
}
