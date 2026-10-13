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
