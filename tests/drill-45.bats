#!/usr/bin/env bats
load test_helper
# Regressions for the fourth (token-watcher) and fifth (CardiacTrim) end-to-end runs.

record_fixture() {
  mkdir -p "$REPO/docs"
  printf '{"version":1,"record_paths":{"evidence_dir":"docs/ev","run_record":"docs/run.md"}}' >"$REPO/docs/autopilot-policy.json"
  printf '# run\n' >"$REPO/docs/run.md"
  commit_fixture
}

@test "a scratch gate ignores the run's uncommitted record paths and reports the code commit" {
  record_fixture
  code="$(git -C "$REPO" rev-parse HEAD)"
  export AUTOPILOT_RECORD="$REPO/docs/run.md"
  run gate s1 true
  [ "$status" -eq 0 ]
  unset AUTOPILOT_RECORD
  printf '# run\n- current: stage 1\n' >"$REPO/docs/run.md"
  printf 'pending\n' >"$CASE/review.md"
  python3 "$SKILL/scripts/evidence.py" register "$EVID" "$CASE/review.md"
  mkdir -p "$REPO/docs/ev"; cp "$EVID"/* "$REPO/docs/ev/"
  run bash "$SKILL/scripts/run-gate.sh" "$REPO" "$CASE/scratch/try.md" try true
  [ "$status" -eq 0 ]
  grep -q "^- tested commit: $code$" "$CASE/scratch/try.md"
}

@test "a committed MANIFEST naming an uncommitted file gets a specific refusal" {
  record_fixture
  mkdir -p "$REPO/docs/ev"
  printf 'x\n' >"$REPO/docs/ev/review.log"
  (cd "$REPO/docs/ev" && printf '%s  review.log\n' "$(sha256_of_file review.log)" >MANIFEST)
  git -C "$REPO" add docs/ev/MANIFEST docs/autopilot-policy.json
  git -C "$REPO" commit -qm 'manifest without its file'
  run bash "$SKILL/scripts/run-gate.sh" "$REPO" "$REPO/docs/ev/g.md" g true
  [ "$status" -eq 64 ]
  [[ "$output" == *'lists files that are not committed: review.log'* ]]
  [[ "$output" == *'git add -f'* ]]
}

sha256_of_file() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

@test "register refuses a name the repository ignores" {
  record_fixture
  printf '*.log\n' >>"$REPO/.gitignore"
  mkdir -p "$REPO/docs/ev"
  printf 'meta\n' >"$CASE/r1.log"
  run python3 "$SKILL/scripts/evidence.py" register "$REPO/docs/ev" "$CASE/r1.log"
  [ "$status" -eq 1 ]
  [[ "$output" == *'would be skipped by .gitignore'* ]]
  [ ! -e "$REPO/docs/ev/r1.log" ]
  run python3 "$SKILL/scripts/evidence.py" register "$REPO/docs/ev" "$CASE/r1.log" r1.log.txt
  [ "$status" -eq 0 ]
}

@test "verify fails when MANIFEST lists a missing file even if only other files are named" {
  printf 'a\n' >"$CASE/a.md"; printf 'b\n' >"$CASE/b.md"
  python3 "$SKILL/scripts/evidence.py" register "$EVID" "$CASE/a.md"
  python3 "$SKILL/scripts/evidence.py" register "$EVID" "$CASE/b.md"
  rm "$EVID/b.md"
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID" a.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'MANIFEST lists missing files: b.md'* ]]
}

@test "candidates skip test files, docstring lines and return None variants" {
  mkdir -p "$REPO/tests"
  printf 'def f(x):\n    return x\n' >"$REPO/lib.py"
  printf 'def test_f():\n    assert 1\n' >"$REPO/tests/test_lib.py"
  commit_fixture
  base="$(git -C "$REPO" rev-parse HEAD)"
  cat >"$REPO/lib.py" <<'PY'
def f(x):
    """Digest with SHA-256
    over 2 passes - 1 key."""
    if x > 3:
        return None
    return x[0]
PY
  printf 'def test_f():\n    assert 1 < 2\n' >"$REPO/tests/test_lib.py"
  commit_fixture
  run bash "$SKILL/scripts/suggest-mutants.sh" "$REPO" "$base" HEAD "$CASE/c1"
  [ "$status" -eq 0 ]
  [[ "$output" == *'1 test file(s) skipped'* ]]
  run python3 - "$CASE/c1" <<'PY'
import json, pathlib, sys
rows = json.load(open(pathlib.Path(sys.argv[1]) / 'candidates.json'))
assert all(r['file'] == 'lib.py' for r in rows), 'ASSERT_TESTS_SKIPPED'
assert not [r for r in rows if r['line'] in (2, 3)], 'ASSERT_DOCSTRING_SKIPPED'
assert not [r for r in rows if r['line'] == 5], 'ASSERT_RETURN_NONE_SKIPPED'
patches = [(pathlib.Path(sys.argv[1]) / r['patch']).read_text() for r in rows if r['line'] == 6]
assert not any('x[-1]' in p for p in patches), 'ASSERT_INDEX_ZERO_EQUIVALENT_SKIPPED'
assert any(r['line'] == 4 for r in rows)
PY
  [ "$status" -eq 0 ]
  run bash "$SKILL/scripts/suggest-mutants.sh" --include-tests "$REPO" "$base" HEAD "$CASE/c2"
  [ "$status" -eq 0 ]
  grep -q 'tests/test_lib.py' "$CASE/c2/candidates.json"
  run bash "$SKILL/scripts/suggest-mutants.sh" "$REPO" "$base" HEAD "$CASE/c2"
  [ "$status" -eq 73 ]
  [[ "$output" == *'output directory exists'* ]]
}

@test "mutant status keeps results across docs and added-test changes, not code changes" {
  mkdir -p "$REPO/test"
  printf 'safe\n' >"$REPO/value"
  printf 'test "$(cat value)" = safe || { echo ASSERT_VALUE_SAFE; exit 1; }\n' >"$REPO/test/check.sh"
  commit_fixture
  patch_value
  export MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$' MUTANT_FAILURE_EXIT=1
  run mutant m1 'bash test/check.sh'
  [ "$status" -eq 0 ]
  printf '# notes\n' >"$REPO/README.md"; printf 'true\n' >>"$REPO/test/check.sh"; commit_fixture
  run python3 "$SKILL/scripts/mutant-status.py" --docs '*.md' --check "$REPO" "$EVID"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'m1.md\tKILLED'*$'\tcurrent\t'* ]]
  printf 'other\n' >"$REPO/helper.txt"; commit_fixture
  run python3 "$SKILL/scripts/mutant-status.py" --docs '*.md' --check "$REPO" "$EVID"
  [ "$status" -eq 1 ]
  [[ "$output" == *'helper.txt changed'* ]]
}

small_config() { printf '{"stages":1,"network":false,"publish":false,"risk":"small-change"}' >"$CASE/run.json"; }

@test "lite small-change admits a small code fix with its test and refuses what it must" {
  mkdir -p "$REPO/src" "$REPO/tests" "$REPO/docs"
  printf '{"version":1,"record_paths":{"evidence_dir":"docs/ev","run_record":"docs/run.md"}}' >"$REPO/docs/autopilot-policy.json"
  printf 'export const f = (x) => x;\n' >"$REPO/src/f.js"
  commit_fixture
  base="$(git -C "$REPO" rev-parse HEAD)"
  small_config
  printf 'export const f = (x) => x > 0 ? x : 0;\n' >"$REPO/src/f.js"
  seq 60 | sed 's/^/assert(1);/' >"$REPO/tests/f.test.js"
  seq 300 >"$REPO/docs/run.md"
  commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'lite eligible (small-change): 2 files, 2 changed lines outside tests'* ]]
  export AUTOPILOT_BASE="$base" AUTOPILOT_RUN_CONFIG="$CASE/run.json"
  run bash "$SKILL/scripts/run-gate.sh" --dry-run --lite "$REPO" "$EVID/lite.md" lite true
  [ "$status" -eq 0 ]
  # 41 lines outside tests is over the limit.
  seq 41 | sed 's/^/export const v& = &;/' >"$REPO/src/g.js"; commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *'over the limits'* ]]
  git -C "$REPO" reset -q --hard HEAD~1
  for name in package.json src/auth.js .github/workflows/ci.yml tsconfig.json; do
    mkdir -p "$REPO/$(dirname "$name")"; printf '{}\n' >"$REPO/$name"; commit_fixture
    run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
    [ "$status" -eq 1 ]
    git -C "$REPO" reset -q --hard HEAD~1
  done
  git -C "$REPO" rm -q src/f.js; commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *'file deleted: src/f.js'* ]]
  git -C "$REPO" reset -q --hard HEAD~1
  for n in 1 2 3 4; do printf 'x\n' >"$REPO/src/m$n.js"; done; commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 1 ]
}

restrictive_policy() {
  mkdir -p "$REPO/docs"
  printf '{"version":1,"deny_network":true%s}' "${1:+,\"fallback\":\"$1\"}" >"$REPO/docs/autopilot-policy.json"
  commit_fixture
}

@test "host doctor recommends strict, env-clean, degraded or park from the host and the policy" {
  run bash "$SKILL/scripts/host-doctor.sh" "$REPO"
  [[ "$output" == *'recommendation: '* ]]
  unavailable_backend
  run bash "$SKILL/scripts/host-doctor.sh" "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *'recommendation: env-clean'* ]]
  restrictive_policy
  run bash "$SKILL/scripts/host-doctor.sh" "$REPO"
  [[ "$output" == *'OS sandbox ('*'): unusable'* ]]
  [[ "$status" -eq 2 || "$status" -eq 1 ]]
  [[ "$output" == *'recommendation: park'* || "$output" == *'recommendation: install'* ]]
  restrictive_policy env-clean
  run bash "$SKILL/scripts/host-doctor.sh" "$REPO"
  if [[ "$output" != *'recommendation: install'* ]]; then
    [ "$status" -eq 0 ]
    [[ "$output" == *'recommendation: degraded'* ]]
  fi
}

@test "a restrictive policy parks without a usable backend unless it approves the env-clean fallback" {
  unavailable_backend
  restrictive_policy
  run gate parked true
  [ "$status" -eq 77 ]
  [[ "$output" == *'host-doctor.sh'* || "$output" == *'sandbox preflight failed'* ]]
  restrictive_policy env-clean
  run gate degraded 'printf "%s|%s" "$HTTPS_PROXY" "$npm_config_offline"'
  [ "$status" -eq 0 ]
  grep -q '^- RED LINES NOT OS-ENFORCED: the policy denies network' "$EVID/degraded.md"
  grep -q '^- source protection: NOT OS-ENFORCED' "$EVID/degraded.md"
  grep -q 'http://127.0.0.1:9|true' "$EVID/degraded.md"
}

@test "fallback accepts only park or env-clean and appears in the effective policy only when set" {
  run bash -c "printf '{\"version\":1,\"fallback\":\"anything\"}' | python3 '$SKILL/scripts/policy.py'"
  [ "$status" -ne 0 ]
  run bash -c "printf '{\"version\":1,\"deny_network\":true}' | python3 '$SKILL/scripts/policy.py'"
  [ "$status" -eq 0 ]
  [[ "$output" != *fallback* ]]
  run bash -c "printf '{\"version\":1,\"deny_network\":true,\"fallback\":\"env-clean\"}' | python3 '$SKILL/scripts/policy.py'"
  [[ "$output" == *'"fallback": "env-clean"'* ]]
}

@test "a mutant signature matches coloured output as the evidence shows it" {
  patch_value
  export MUTANT_FAILURE_REGEX='^ FAIL  check > value is safe$' MUTANT_FAILURE_EXIT=1
  run mutant colour "test \"\$(cat value)\" = safe || { printf '\\033[41m\\033[1m FAIL \\033[22m\\033[49m check > value is safe\\n'; exit 1; }"
  [ "$status" -eq 0 ]
  grep -q '^- result: KILLED' "$EVID/colour.md"
}

@test "lite skips generated paths, records its result in evidence, and matches sensitive words not substrings" {
  mkdir -p "$REPO/src" "$REPO/dist" "$REPO/docs"
  printf '{"version":1,"generated_paths":["dist"]}' >"$REPO/docs/autopilot-policy.json"
  printf 'a\n' >"$REPO/src/author.ts"; commit_fixture
  base="$(git -C "$REPO" rev-parse HEAD)"
  printf '{"stages":1,"network":false,"publish":false,"risk":"small-change"}' >"$CASE/run.json"
  printf 'b\n' >"$REPO/src/author.ts"
  for n in 1 2 3 4 5; do seq 30 >"$REPO/dist/out$n.js"; done
  commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'5 generated file(s) under dist not counted'* ]]
  export AUTOPILOT_BASE="$base" AUTOPILOT_RUN_CONFIG="$CASE/run.json"
  run bash "$SKILL/scripts/run-gate.sh" --lite "$REPO" "$EVID/lite-gate.md" lite-gate true
  [ "$status" -eq 0 ]
  grep -q '^- lite: lite eligible (small-change)' "$EVID/lite-gate.md"
  unset AUTOPILOT_BASE AUTOPILOT_RUN_CONFIG
  printf 'x\n' >"$REPO/src/authMiddleware.ts"; commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *'safety-sensitive change: src/authMiddleware.ts'* ]]
  run bash "$SKILL/scripts/suggest-mutants.sh" "$REPO" "$base" HEAD "$CASE/cands"
  ! grep -q '"dist/' "$CASE/cands/candidates.json"
}

@test "host doctor tells a missing policy from a missing contract" {
  mkdir -p "$REPO/docs"; printf '# contract\n' >"$REPO/docs/autopilot.md"; commit_fixture
  run bash "$SKILL/scripts/host-doctor.sh" "$REPO"
  [[ "$output" == *'contract present but no valid committed docs/autopilot-policy.json'* ]]
}
