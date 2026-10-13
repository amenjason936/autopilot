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

@test "a helper change persisted by an aborted gate is refused by the next gate (#3)" {
  isolate_runner
  unavailable_backend
  run gate g1 "printf '\n# tampered\n' >> '$SKILL/scripts/failure_signature.py'; true"
  [ "$status" -eq 70 ]
  run gate g2 true
  [ "$status" -eq 70 ]
  [[ "$output" == *"differs from the run's takeoff pin"* ]]
  [ ! -e "$EVID/g2.md" ]
}

@test "without a pin, a clean skill checkout is the reference and drift names the file" {
  isolate_runner
  unset AUTOPILOT_HELPER_PIN
  git -C "$SKILL" init -q
  git -C "$SKILL" add scripts
  git -C "$SKILL" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit -qm skill
  run gate clean true
  [ "$status" -eq 0 ]
  grep -q '^- helper reference: git checkout ' "$EVID/clean.md"
  printf '\n# tampered\n' >>"$SKILL/scripts/failure_signature.py"
  run gate drift true
  [ "$status" -eq 70 ]
  [[ "$output" == *'scripts/failure_signature.py'* ]]
  git -C "$SKILL" checkout -q -- scripts
  printf 'x = 1\n' >"$SKILL/scripts/hashlib.py"
  run gate untracked true
  [ "$status" -eq 70 ]
  [[ "$output" == *'scripts/hashlib.py'* ]]
  rm "$SKILL/scripts/hashlib.py"
  run gate restored true
  [ "$status" -eq 0 ]
}

@test "without a pin or checkout, INSTALLATION.json is the reference" {
  isolate_runner
  unset AUTOPILOT_HELPER_PIN
  (cd "$SKILL" && python3 -c 'import hashlib,json,pathlib; print(json.dumps({"installed_sha256": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(pathlib.Path("scripts").rglob("*")) if p.is_file()}}))') >"$SKILL/INSTALLATION.json"
  run gate installed true
  [ "$status" -eq 0 ]
  grep -q '^- helper reference: INSTALLATION.json$' "$EVID/installed.md"
  printf '\n# tampered\n' >>"$SKILL/scripts/redact.py"
  run gate changed true
  [ "$status" -eq 70 ]
  [[ "$output" == *'scripts/redact.py'* ]]
  rm -f "$SKILL/INSTALLATION.json"
  run gate none true
  [ "$status" -eq 70 ]
  [[ "$output" == *'no trusted helper reference'* ]]
}

@test "dry run prints the helper inventory digest to pin at takeoff" {
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$EVID/p.md" p true
  [ "$status" -eq 0 ]
  [[ "$output" == *"helper inventory sha256: $AUTOPILOT_HELPER_PIN"* ]]
}

@test "a parked partial names the label and the ways forward" {
  mkdir -p "$EVID"
  : >"$EVID/again.md.partial"
  run gate again true
  [ "$status" -eq 76 ]
  [[ "$output" == *'again.md.partial'* ]]
  [[ "$output" == *'new label'* ]]
}

@test "a dry run without a reference still previews and says a gate would refuse" {
  isolate_runner
  unset AUTOPILOT_HELPER_PIN
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$EVID/p.md" p true
  [ "$status" -eq 0 ]
  [[ "$output" == *'reference: none; a gate would refuse: no trusted helper reference'* ]]
}
