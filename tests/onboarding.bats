#!/usr/bin/env bats
load test_helper

init_project() {
  python3 "$SKILL/scripts/autopilot.py" init "$REPO" --goal 'Fix the boundary case' "$@"
}

@test "setup preview includes inspectable drafts without executing checks or writing files" {
  run init_project --check "touch '$CASE/command-ran'" --json
  [ "$status" -eq 0 ]
  [ ! -e "$REPO/docs" ]
  [ ! -e "$CASE/command-ran" ]
  printf '%s' "$output" >"$CASE/preview.json"
  python3 - "$CASE/preview.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d['mode'] == 'preview' and d['executed_checks'] is False
p = json.loads(d['files']['docs/autopilot-policy.json'])
assert p['deny_network'] is True and p['fallback'] == 'park'
assert not p.get('share_dirs') and not p.get('allow_loopback') and not p.get('read_paths')
assert 'touch' in d['files']['docs/autopilot.md']
PY
}

@test "setup creates proposed files without sample successes or a commit" {
  before="$(git -C "$REPO" rev-parse HEAD)"
  run init_project --write --check 'bash checks.sh'
  [ "$status" -eq 0 ]
  [ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
  grep -q '^Status: proposed' "$REPO/docs/autopilot.md"
  grep -q 'Fix the boundary case' "$REPO/docs/runs/run.md"
  grep -q '^- status: planned' "$REPO/docs/runs/run.md"
  grep -q '^- tested commit: not tested' "$REPO/docs/runs/run.md"
  ! grep -q '| all green |\|streams 1 GB\|| blocking-fixed |' "$REPO/docs/runs/run.md"
  [ ! -e "$REPO/docs/evidence" ]
  run python3 "$SKILL/scripts/policy.py" <"$REPO/docs/autopilot-policy.json"
  [ "$status" -eq 0 ]
}

@test "setup preflights the whole bundle and preserves existing files" {
  mkdir -p "$REPO/docs/runs"
  printf 'existing user record\n' >"$REPO/docs/runs/run.md"
  run init_project --write
  [ "$status" -eq 73 ]
  [ ! -e "$REPO/docs/autopilot.md" ]
  [ ! -e "$REPO/docs/autopilot-policy.json" ]
  [ "$(cat "$REPO/docs/runs/run.md")" = 'existing user record' ]
}

@test "setup refuses a symlinked parent without writing outside the repository" {
  mkdir "$CASE/outside"
  ln -s "$CASE/outside" "$REPO/docs"
  run init_project --write
  [ "$status" -eq 64 ]
  [ -z "$(ls -A "$CASE/outside")" ]
}

@test "setup refuses ignored configuration before creating any file" {
  printf 'docs/runs/\n' >>"$REPO/.gitignore"
  run init_project --write
  [ "$status" -eq 64 ]
  [[ "$output" == *'ignored by Git'* ]]
  [ ! -e "$REPO/docs" ]
}

@test "setup requires an existing initial commit and never initializes a repository" {
  mkdir "$CASE/empty" "$CASE/unborn"
  git -C "$CASE/unborn" init -q
  for candidate in "$CASE/empty" "$CASE/unborn" "$CASE/absent"; do
    run python3 "$SKILL/scripts/autopilot.py" init "$candidate" --goal example --write
    [ "$status" -eq 65 ]
    [ ! -e "$candidate/docs" ]
  done
  [ ! -e "$CASE/empty/.git" ]
  [ ! -e "$CASE/absent" ]
}

@test "status distinguishes missing, draft, committed and modified files without accepting a run" {
  run python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"docs/autopilot.md": "missing"'* ]]
  init_project --write >/dev/null
  run python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"docs/runs/run.md": "uncommitted"'* ]]
  commit_fixture
  before="$(git -C "$REPO" rev-parse HEAD)"
  index_before="$(git -C "$REPO" hash-object .git/index)"
  run python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"docs/runs/run.md": "committed"'* ]]
  [[ "$output" == *'authorization, gates and evidence are not evaluated'* ]]
  [ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
  [ "$(git -C "$REPO" hash-object .git/index)" = "$index_before" ]
  printf 'local draft\n' >>"$REPO/docs/runs/run.md"
  run python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"docs/runs/run.md": "modified"'* ]]
}

@test "status respects custom policy and record paths and init preserves that choice" {
  mkdir -p "$REPO/config" "$REPO/runs"
  printf '{"version":1,"record_paths":{"run_record":"runs/custom.md"}}\n' >"$REPO/config/policy.json"
  printf '# existing run\n' >"$REPO/runs/custom.md"
  commit_fixture
  run env GATE_POLICY=config/policy.json python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"runs/custom.md": "committed"'* ]]
  run env GATE_POLICY=config/policy.json python3 "$SKILL/scripts/autopilot.py" init "$REPO" --goal example --write
  [ "$status" -eq 64 ]
  [ ! -e "$REPO/docs" ]
}

@test "status rejects invalid policies and redirected record paths" {
  mkdir -p "$REPO/docs"
  printf '{"version":1,"record_paths":{"run_record":"../secret"}}\n' >"$REPO/docs/autopilot-policy.json"
  run python3 "$SKILL/scripts/autopilot.py" status "$REPO"
  [ "$status" -eq 64 ]
  printf '{"version":1,"record_paths":{"run_record":"record.md"}}\n' >"$REPO/docs/autopilot-policy.json"
  printf 'private canary\n' >"$CASE/secret"
  ln -s "$CASE/secret" "$REPO/record.md"
  run python3 "$SKILL/scripts/autopilot.py" status "$REPO"
  [ "$status" -eq 64 ]
  [[ "$output" != *'private canary'* ]]
}

@test "setup inspection ignores Git overrides and does not execute repository callbacks" {
  printf '#!/bin/sh\ntouch "%s"\n' "$CASE/callback-ran" >"$CASE/callback"
  chmod +x "$CASE/callback"
  git -C "$REPO" config core.fsmonitor "$CASE/callback"
  run env GIT_DIR="$CASE/not-a-repo" python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"docs/autopilot.md": "missing"'* ]]
  run init_project --json
  [ "$status" -eq 0 ]
  [ ! -e "$CASE/callback-ran" ]
}

@test "installed package can initialize a project without repository-only resources" {
  package="$CASE/package"
  mkdir -p "$package/scripts" "$package/agents"
  for name in SKILL.md VERSION AUDITOR-BRIEF.md CONTRACT-TEMPLATE.md RUN-RECORD-TEMPLATE.md; do
    cp "$SKILL/$name" "$package/"
  done
  for name in install-skill.py autopilot.py policy.py run-gate.sh; do
    cp "$SKILL/scripts/$name" "$package/scripts/"
  done
  cp "$SKILL/agents/openai.yaml" "$package/agents/"
  dest="$CASE/installed/autopilot"
  run python3 "$package/scripts/install-skill.py" --host codex --dest "$dest"
  [ "$status" -eq 0 ]
  run python3 "$dest/scripts/autopilot.py" init "$REPO" --goal example --write --json
  [ "$status" -eq 0 ]
  [ -f "$REPO/docs/autopilot-policy.json" ]
  [ ! -e "$dest/scripts/__pycache__" ]
}

@test "doctor entry point preserves the existing diagnosis exit and never requests host fixes" {
  mkdir -p "$CASE/adapter/scripts"
  cp "$SKILL/scripts/autopilot.py" "$SKILL/scripts/policy.py" "$CASE/adapter/scripts/"
  cat >"$CASE/adapter/scripts/host-doctor.sh" <<'SH'
#!/bin/bash
printf 'doctor args: %s\n' "$@"
exit 2
SH
  run python3 "$CASE/adapter/scripts/autopilot.py" doctor "$REPO"
  [ "$status" -eq 2 ]
  [[ "$output" == *"doctor args: $REPO"* ]]
  [[ "$output" != *'--fix'* ]]
  [ ! -e "$REPO/docs" ]
}

@test "generated configuration works with the existing pinned gate" {
  require_os_sandbox
  init_project --write >/dev/null
  commit_fixture
  run bash "$SKILL/scripts/run-gate.sh" "$REPO" "$REPO/docs/evidence/gate-base.md" gate-base 'test "$(cat value)" = safe'
  [ "$status" -eq 0 ]
  run bash "$SKILL/scripts/verify-evidence.sh" "$REPO/docs/evidence"
  [ "$status" -eq 0 ]
  [[ "$output" == *'verified: 1 evidence file(s)'* ]]
}
