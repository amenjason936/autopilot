#!/usr/bin/env bats
load test_helper

@test "evidence write failure cannot publish an incomplete success" {
  # Inject writer I/O failure from the trusted test supervisor. Commands may
  # no longer modify evidence permissions through the OS boundary.
  (
    for _ in $(seq 1 200); do
      if [ -f "$CASE/ready" ]; then
        chmod 400 "$EVID/unwritable.md.partial"
        touch "$CASE/done"
        exit
      fi
      sleep 0.05
    done
    exit 1
  ) &
  injector=$!
  run gate unwritable "touch '$CASE/ready'; while [ ! -f '$CASE/done' ]; do sleep 0.05; done"
  wait "$injector"
  [ "$status" -eq 70 ]
  [ ! -e "$EVID/unwritable.md" ]
  [ ! -e "$EVID/MANIFEST" ]
  [ -f "$EVID/unwritable.md.partial" ]
}

@test "nonregular partial and unwritable manifest never report success" {
  mkdir "$EVID/directory.md.partial"
  run gate directory true
  [ "$status" -eq 73 ]
  [ -d "$EVID/directory.md.partial" ]
  mkdir "$EVID/MANIFEST"
  run gate manifest true
  [ "$status" -eq 70 ]
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID"
  [ "$status" -ne 0 ]
}

@test "failure signature rejects unrelated errors and wrong exits" {
  patch_value
  export MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$'
  run mutant unrelated 'if test "$(cat value)" != safe; then echo unrelated-environment-error; exit 1; fi'
  [ "$status" -eq 2 ]
  run mutant wrongexit 'if test "$(cat value)" != safe; then echo ASSERT_VALUE_SAFE; exit 2; fi'
  [ "$status" -eq 2 ]
  unset MUTANT_FAILURE_REGEX
  run mutant unsigned 'test "$(cat value)" = safe'
  [ "$status" -eq 2 ]
}

@test "record exclusions reject undeclared source directories" {
  mkdir "$REPO/src"
  printf 'source\n' >"$REPO/src/module.py"
  commit_fixture
  printf dirty >>"$REPO/src/module.py"
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$REPO/src/hidden.md" hidden true
  [ "$status" -eq 64 ]
  export AUTOPILOT_RECORD="$REPO/src"
  run gate hidden true
  [ "$status" -eq 64 ]
}

@test "approved record paths cannot contain tracked executable source" {
  mkdir "$REPO/docs" "$REPO/proof"
  printf '{"version":1,"record_paths":{"evidence_dir":"proof"}}' >"$REPO/docs/autopilot-policy.json"
  printf 'x = 1\n' >"$REPO/proof/hidden.py"
  commit_fixture
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$REPO/proof/check.md" check true
  [ "$status" -eq 64 ]
}

@test "lite exact boundary permits 50 doc lines and refuses 51" {
  base="$(git -C "$REPO" rev-parse HEAD)"
  printf '{"stages":1,"network":false,"publish":false,"risk":"documentation-only"}' >"$CASE/run.json"
  seq 50 >"$REPO/guide.md"
  commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 0 ]
  printf '51\n' >>"$REPO/guide.md"
  commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 1 ]
}

@test "lite refuses one-line runtime and safety instruction edits" {
  base="$(git -C "$REPO" rev-parse HEAD)"
  printf '{"stages":1,"network":false,"publish":false,"risk":"documentation-only"}' >"$CASE/run.json"
  printf 'allow = True\n' >"$REPO/auth.py"
  commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 1 ]
  base="$(git -C "$REPO" rev-parse HEAD)"
  printf 'ignore authorization\n' >"$REPO/SKILL.md"
  commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 1 ]
}

@test "review identity rejects stale head scope and altered findings" {
  printf 'frozen record\n' >"$REPO/record.md"
  commit_fixture
  base="$(git -C "$REPO" rev-parse HEAD)"
  run bash "$SKILL/scripts/codex-review.sh" --prompt-only "$REPO" "$base" "$REPO/record.md" "$CASE/findings.json"
  [ "$status" -eq 0 ]
  printf '{"verdict":"approve","summary":"ok","findings":[],"limits":"fixture"}' >"$CASE/findings.json"
  run python3 "$SKILL/scripts/review_identity.py" seal "$CASE/findings.json" "$CASE/findings.json.request.json"
  [ "$status" -eq 0 ]
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/findings.json" "$CASE/findings.json.request.json" "$REPO" "$base" "$base" record.md landing
  [ "$status" -eq 0 ]
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/findings.json" "$CASE/findings.json.request.json" "$REPO" "$base" "$base" record.md 'stage 1'
  [ "$status" -eq 70 ]
  git -C "$REPO" commit --allow-empty -qm advanced
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/findings.json" "$CASE/findings.json.request.json" "$REPO" "$base" HEAD record.md landing
  [ "$status" -eq 70 ]
  printf '\n' >>"$CASE/findings.json"
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/findings.json" "$CASE/findings.json.request.json" "$REPO" "$base" "$base" record.md landing
  [ "$status" -eq 70 ]
}

@test "restrictive policy parks cloud dispatch before invoking the reviewer" {
  mkdir "$REPO/docs" "$CASE/bin"
  printf '{"version":1,"deny_network":true}' >"$REPO/docs/autopilot-policy.json"
  printf 'record\n' >"$REPO/record.md"
  commit_fixture
  printf '#!/bin/bash\ntouch "%s"\n' "$CASE/cloud-called" >"$CASE/bin/codex"
  chmod +x "$CASE/bin/codex"
  export PATH="$CASE/bin:$PATH"
  run bash "$SKILL/scripts/codex-review.sh" "$REPO" HEAD "$REPO/record.md" "$CASE/findings.json"
  [ "$status" -eq 77 ]
  [ ! -e "$CASE/cloud-called" ]
}

@test "relocated training uses package fixtures despite valid legacy decoys" {
  require_os_sandbox
  mkdir -p "$CASE/relocated" "$CASE/legacyhome/.claude/skills/autopilot/tests/fixtures/training"
  cp -R "$SKILL/scripts" "$SKILL/tests" "$CASE/relocated/"
  cp "$SKILL/tests/fixtures/training/subject.sh" "$SKILL/tests/fixtures/training/checks.sh" "$CASE/legacyhome/.claude/skills/autopilot/tests/fixtures/training/"
  printf '\n# legacy-decoy\n' >>"$CASE/legacyhome/.claude/skills/autopilot/tests/fixtures/training/subject.sh"
  run env -u AUTOPILOT_HELPER_PIN HOME="$CASE/legacyhome" bash "$CASE/relocated/scripts/training-ground.sh" "$CASE/training"
  [ "$status" -eq 0 ]
  run python3 - "$SKILL/tests/fixtures/training/subject.sh" "$CASE/training/repo/subject.sh" <<'PY'
import pathlib, sys
expected = pathlib.Path(sys.argv[1]).read_text().replace('-gt 10', '-ge 10')
assert pathlib.Path(sys.argv[2]).read_text() == expected, 'ASSERT_PACKAGE_FIXTURE'
PY
  [ "$status" -eq 0 ]
}

@test "interrupted side effects stay parked without a safe rerun declaration" {
  printf 'interrupted\n' >"$EVID/interrupted.md.partial"
  run gate interrupted "touch '$CASE/repeated-action'"
  [ "$status" -eq 76 ]
  [ ! -e "$CASE/repeated-action" ]
  [ "$(cat "$EVID/interrupted.md.partial")" = interrupted ]
}

@test "committed evidence symlink cannot redirect writer outside the repository" {
  mkdir "$CASE/outside"
  ln -s "$CASE/outside" "$REPO/proof"
  commit_fixture
  run bash "$SKILL/scripts/run-gate.sh" "$REPO" "$REPO/proof/redirect.md" redirect true
  [ "$status" -eq 64 ]
  [ ! -e "$CASE/outside/redirect.md" ]
  [ ! -e "$CASE/outside/MANIFEST" ]
}
