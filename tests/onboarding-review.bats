#!/usr/bin/env bats
load test_helper

# Bash 3.2 does not reliably apply errexit to [[ ... ]]; return explicitly so
# a failed diagnostic assertion cannot be hidden by a later preservation check.

init_project() {
  python3 "$SKILL/scripts/autopilot.py" init "$REPO" --goal 'Review regression' "$@"
}

simulate_foreign_owner() {
  # Exercise Git's real ownership check without chown/sudo or a foreign checkout.
  export REVIEW_REAL_GIT
  REVIEW_REAL_GIT="$(command -v git)"
  mkdir -p "$CASE/bin"
  cat >"$CASE/bin/git" <<'SH'
#!/bin/sh
GIT_TEST_ASSUME_DIFFERENT_OWNER=1 exec "$REVIEW_REAL_GIT" "$@"
SH
  chmod +x "$CASE/bin/git"
  export PATH="$CASE/bin:$PATH"
}

@test "review: setup validation ignores runtime policy overrides" {
  export GATE_ENV=API_KEY GATE_SANDBOX=not-a-backend
  run init_project --write --json
  [ "$status" -eq 0 ]
  run python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'valid working-tree policy'* ]] || return 1
  # Runtime callers still validate and apply the same overrides as before.
  run python3 "$SKILL/scripts/policy.py" <"$REPO/docs/autopilot-policy.json"
  [ "$status" -ne 0 ]
}

@test "review: setup preserves protected Git trust for inspection and doctor" {
  git config --file "$CASE/system.gitconfig" --add safe.directory '*'
  git config --file "$CASE/global.gitconfig" --add safe.directory ''
  git config --file "$CASE/included.gitconfig" --add safe.directory "$REPO"
  git config --file "$CASE/global.gitconfig" include.path "$CASE/included.gitconfig"
  # Unrelated protected config must not redirect the working tree.
  git config --file "$CASE/global.gitconfig" core.worktree "$CASE/not-a-repo"
  export GIT_CONFIG_SYSTEM="$CASE/system.gitconfig" GIT_CONFIG_GLOBAL="$CASE/global.gitconfig"
  mkdir -p "$CASE/adapter/scripts"
  cp "$SKILL/scripts/autopilot.py" "$SKILL/scripts/policy.py" "$CASE/adapter/scripts/"
  cat >"$CASE/adapter/scripts/host-doctor.sh" <<'SH'
#!/bin/sh
git -C "$1" rev-parse --show-toplevel || exit
git -C "$1" config --get-all safe.directory
SH
  simulate_foreign_owner
  run init_project --json
  [ "$status" -eq 0 ]
  run python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  run python3 "$CASE/adapter/scripts/autopilot.py" doctor "$REPO"
  [ "$status" -eq 0 ]
  expected_repo="$(cd "$REPO" && pwd -P)"
  [ "${lines[0]}" = "$expected_repo" ]
  [ ! -e "$REPO/docs" ]
}

@test "review: setup respects trust resets and explains untrusted ownership" {
  git config --file "$CASE/system.gitconfig" --add safe.directory '*'
  git config --file "$CASE/global.gitconfig" --add safe.directory ''
  git -C "$REPO" config safe.directory '*'
  export GIT_CONFIG_SYSTEM="$CASE/system.gitconfig" GIT_CONFIG_GLOBAL="$CASE/global.gitconfig"
  simulate_foreign_owner
  run init_project --write
  [ "$status" -eq 65 ]
  [[ "$output" == *'ownership'* ]] || return 1
  [[ "$output" == *'safe.directory'* ]] || return 1
  [ ! -e "$REPO/docs" ]
}

@test "review: setup honors disabling system Git trust" {
  git config --file "$CASE/system.gitconfig" --add safe.directory "$REPO"
  export GIT_CONFIG_SYSTEM="$CASE/system.gitconfig" GIT_CONFIG_GLOBAL=/dev/null
  simulate_foreign_owner
  run init_project --json
  [ "$status" -eq 0 ]
  run env GIT_CONFIG_NOSYSTEM=1 python3 "$SKILL/scripts/autopilot.py" init "$REPO" --goal valid --write
  [ "$status" -eq 65 ]
  [[ "$output" == *'ownership'* ]] || return 1
  [ ! -e "$REPO/docs" ]
}

@test "review: non-UTF-8 input leaves no setup files and permits a valid retry" {
  run python3 "$SKILL/scripts/autopilot.py" init "$REPO" --goal $'x\xff' --write
  [ "$status" -eq 64 ]
  [[ "$output" != *Traceback* ]] || return 1
  [ ! -e "$REPO/docs" ]
  run init_project --write
  [ "$status" -eq 0 ]
  [ -s "$REPO/docs/runs/run.md" ]
}

@test "review: every draft is UTF-8 encodable before any setup file is created" {
  run python3 - "$SKILL/scripts" "$REPO" <<'PY'
import argparse, pathlib, runpy, sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
app = runpy.run_path(sys.argv[1] + '/autopilot.py')
initialize = app['initialize']
original = app['drafts']
def bad_last_draft(*args):
    files = original(*args)
    files[app['RECORD']] += '\udcff'
    return files
initialize.__globals__['drafts'] = bad_last_draft
args = argparse.Namespace(repo=sys.argv[2], goal='valid', check=[], write=True, json=True)
try:
    initialize(args)
except app['SetupError'] as error:
    assert error.code == 64
else:
    raise AssertionError('unencodable bundle accepted')
assert not (pathlib.Path(sys.argv[2]) / 'docs').exists()
PY
  [ "$status" -eq 0 ]
}

@test "review: missing or duplicated template anchors reject the whole bundle" {
  run python3 - "$SKILL" "$CASE" "$REPO" <<'PY'
import pathlib, shutil, subprocess, sys
skill, case, repo = map(pathlib.Path, sys.argv[1:])
package = case / 'package'
(package / 'scripts').mkdir(parents=True)
for name in ('autopilot.py', 'policy.py'):
    shutil.copyfile(skill / 'scripts' / name, package / 'scripts' / name)
anchors = {'CONTRACT-TEMPLATE.md': ['<project>', 'Gate settings (environment for `run-gate.sh`):'],
           'RUN-RECORD-TEMPLATE.md': ['# <run title>', '- cut from: <full commit>',
                                    '- tested commit: <full commit>',
                                    'What the human asked for, in their words.', '## Goal']}
originals = {name: (skill / name).read_text() for name in anchors}
for name, markers in anchors.items():
    for marker in markers:
        for replacement in ('missing anchor', marker + '\n' + marker):
            for template, content in originals.items():
                (package / template).write_text(content.replace(marker, replacement) if template == name else content)
            result = subprocess.run([sys.executable, str(package / 'scripts/autopilot.py'), 'init', str(repo),
                                     '--goal', 'valid', '--write'], capture_output=True)
            assert result.returncode == 64, (name, marker, result.returncode)
            assert b'anchor' in result.stderr and not (repo / 'docs').exists()
PY
  [ "$status" -eq 0 ]
}

@test "review: user text resembling template anchors is inserted literally once" {
  run python3 "$SKILL/scripts/autopilot.py" init "$REPO" --write \
    --goal '## Goal What the human asked for, in their words.' --check '<project>'
  [ "$status" -eq 0 ]
  grep -q '^## Goal What the human asked for, in their words\.$' "$REPO/docs/runs/run.md"
  [ "$(grep -c '^> Setup draft:' "$REPO/docs/runs/run.md")" -eq 1 ]
}

@test "review: ignored evidence directory is rejected before setup writes" {
  printf 'docs/evidence/\n' >>"$REPO/.gitignore"
  run init_project --write
  [ "$status" -eq 64 ]
  [[ "$output" == *'ignored by Git'* ]] || return 1
  [ ! -e "$REPO/docs" ]
}

@test "review: occupied or committed evidence directory is preserved" {
  mkdir -p "$REPO/docs/evidence"
  printf 'unrelated content\n' >"$REPO/docs/evidence/existing.md"
  commit_fixture
  run init_project --write
  [ "$status" -eq 73 ]
  [ ! -e "$REPO/docs/autopilot.md" ]
  [ "$(cat "$REPO/docs/evidence/existing.md")" = 'unrelated content' ]
  mv "$REPO/docs/evidence" "$CASE/preserved-evidence"
  run init_project --write
  [ "$status" -eq 73 ]
  [ ! -e "$REPO/docs/autopilot.md" ]
}

@test "review: symlinked evidence directories are rejected but empty directories work" {
  mkdir -p "$CASE/outside" "$REPO/docs"
  ln -s "$CASE/outside" "$REPO/docs/evidence"
  run init_project --write
  [ "$status" -eq 64 ]
  [ ! -e "$REPO/docs/autopilot.md" ]
  [ -z "$(ls -A "$CASE/outside")" ]
  mv "$REPO/docs/evidence" "$CASE/preserved-link"
  mkdir "$REPO/docs/evidence"
  run init_project --write
  [ "$status" -eq 0 ]
}

@test "review: committed locally deleted setup is reported and cannot be reinitialized" {
  init_project --write >/dev/null
  commit_fixture
  mv "$REPO/docs" "$CASE/preserved-docs"
  run python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  printf '%s' "$output" >"$CASE/status.json"
  python3 - "$CASE/status.json" <<'PY'
import json, sys
assert set(json.load(open(sys.argv[1]))['files'].values()) == {'deleted'}
PY
  run init_project --write
  [ "$status" -eq 73 ]
  [ ! -e "$REPO/docs" ]
}

@test "review: deleted custom policy still identifies its committed run-record path" {
  mkdir -p "$REPO/config" "$REPO/runs"
  printf '{"version":1,"record_paths":{"run_record":"runs/custom.md"}}\n' >"$REPO/config/policy.json"
  printf '# existing run\n' >"$REPO/runs/custom.md"
  commit_fixture
  mv "$REPO/config/policy.json" "$CASE/preserved-policy.json"
  run env GATE_POLICY=config/policy.json python3 "$SKILL/scripts/autopilot.py" status "$REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"config/policy.json": "deleted"'* ]] || return 1
  [[ "$output" == *'"runs/custom.md": "committed"'* ]] || return 1
}

@test "review: goal and check reject Unicode separators and controls before writing" {
  run python3 - "$SKILL/scripts/autopilot.py" "$REPO" <<'PY'
import pathlib, subprocess, sys
script, repo = sys.argv[1:]
for char in ('\x7f', '\x85', '\u2028', '\u2029', '\n', '\r', '\t'):
    for option in ('--goal', '--check'):
        result = subprocess.run([sys.executable, script, 'init', repo, '--goal', 'valid',
                                 option, 'prefix' + char + '- status: landed', '--write'], capture_output=True)
        assert result.returncode == 64, (option, repr(char), result.returncode)
        assert not (pathlib.Path(repo) / 'docs').exists()
result = subprocess.run([sys.executable, script, 'init', repo, '--goal', '修复回归 café',
                         '--check', 'echo "通过"', '--write'], capture_output=True)
assert result.returncode == 0, result.stderr
assert '修复回归 café' in (pathlib.Path(repo) / 'docs/runs/run.md').read_text()
PY
  [ "$status" -eq 0 ]
}
