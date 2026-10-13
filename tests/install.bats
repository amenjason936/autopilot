#!/usr/bin/env bats
load test_helper

setup_package() {
  PACKAGE="$CASE/package"
  mkdir -p "$PACKAGE/scripts" "$PACKAGE/agents"
  cp "$SKILL/SKILL.md" "$SKILL/VERSION" "$SKILL/AUDITOR-BRIEF.md" "$PACKAGE/"
  cp "$SKILL/agents/openai.yaml" "$PACKAGE/agents/"
  cp "$SKILL/scripts/install-skill.py" "$SKILL/scripts/run-gate.sh" "$PACKAGE/scripts/"
  printf 'complete payload\n' >"$PACKAGE/extra-data.txt"
}

@test "installer preview is read-only and ccmr ignores the ordinary Claude config" {
  setup_package
  run env HOME="$CASE/home" CLAUDE_CONFIG_DIR="$CASE/other-claude" python3 "$PACKAGE/scripts/install-skill.py" --host ccmr --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"$CASE/home/.claude-gateway/skills/autopilot"* ]]
  [ ! -e "$CASE/home" ]
  run env HOME="$CASE/home" CLAUDE_CONFIG_DIR="$CASE/other-claude" python3 "$PACKAGE/scripts/install-skill.py" --host claude-code --dry-run
  [[ "$output" == *"$CASE/other-claude/skills/autopilot"* ]]
}

@test "installer replaces the complete bundle and retains old files in backup" {
  setup_package
  dest="$CASE/skills/autopilot"
  mkdir -p "$dest"
  printf legacy >"$dest/stale.txt"
  run python3 "$PACKAGE/scripts/install-skill.py" --host codex --dest "$dest"
  [ "$status" -eq 1 ]
  [ "$(cat "$dest/stale.txt")" = legacy ]
  run python3 "$PACKAGE/scripts/install-skill.py" --host codex --dest "$dest" --replace
  [ "$status" -eq 0 ]
  [ ! -e "$dest/stale.txt" ]
  cmp "$PACKAGE/SKILL.md" "$dest/SKILL.md"
  cmp "$PACKAGE/extra-data.txt" "$dest/extra-data.txt"
  python3 - "$dest" <<'PY'
import pathlib,json,hashlib,sys
p=pathlib.Path(sys.argv[1]);r=json.loads((p/'INSTALLATION.json').read_text())
assert (pathlib.Path(r['backup'])/'previous/stale.txt').read_text()=='legacy'
for name,checksum in r['installed_sha256'].items():
    assert hashlib.sha256((p/name).read_bytes()).hexdigest()==checksum
assert (pathlib.Path(r['backup'])/'receipt.json').read_bytes()==(p/'INSTALLATION.json').read_bytes()
PY
}

@test "ccmr symlink replacement snapshots its target and preserves manual invocation" {
  setup_package
  old="$CASE/claude/autopilot"
  dest="$CASE/gateway/skills/autopilot"
  mkdir -p "$old" "$(dirname "$dest")"
  printf original >"$old/value"
  ln -s "$old" "$dest"
  run python3 "$PACKAGE/scripts/install-skill.py" --host ccmr --dest "$dest" --replace
  [ "$status" -eq 0 ]
  [ ! -L "$dest" ]
  [ "$(cat "$old/value")" = original ]
  grep -q '^disable-model-invocation: true$' "$dest/SKILL.md"
  cmp "$PACKAGE/scripts/run-gate.sh" "$dest/scripts/run-gate.sh"
  python3 - "$dest" "$old" <<'PY'
import pathlib,json,sys
p=pathlib.Path(sys.argv[1]);r=json.loads((p/'INSTALLATION.json').read_text());b=pathlib.Path(r['backup'])
assert (b/'previous').is_symlink()
assert (b/'previous-target/value').read_text()=='original'
assert r['previous_symlink']==sys.argv[2]
PY
}

@test "installer refuses overlapping source and target without writing backups" {
  setup_package
  run python3 "$PACKAGE/scripts/install-skill.py" --host zcode --dest "$PACKAGE/autopilot" --replace
  [ "$status" -eq 1 ]
  [ ! -e "$PACKAGE/autopilot" ]
  [ ! -e "$CASE/skill-backups" ]
}

@test "installer binds Git payload to a clean commit and excludes untracked files" {
  setup_package
  git -C "$PACKAGE" init -q
  git -C "$PACKAGE" config user.name Fixture
  git -C "$PACKAGE" config user.email fixture@example.invalid
  git -C "$PACKAGE" config commit.gpgsign false
  chmod +x "$PACKAGE/scripts/run-gate.sh"
  git -C "$PACKAGE" add .
  git -C "$PACKAGE" commit -qm fixture
  printf private >"$PACKAGE/untracked.txt"
  dest="$CASE/installed/autopilot"
  run python3 "$PACKAGE/scripts/install-skill.py" --host zcode --dest "$dest"
  [ "$status" -eq 0 ]
  [ ! -e "$dest/untracked.txt" ]
  [ ! -e "$dest/.git" ]
  [ -x "$dest/scripts/run-gate.sh" ]
  grep -q '^disable-model-invocation: true$' "$dest/SKILL.md"
  expected="$(git -C "$PACKAGE" rev-parse HEAD)"
  python3 - "$dest/INSTALLATION.json" "$expected" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['source_commit']==sys.argv[2]
PY
  printf dirty >>"$PACKAGE/SKILL.md"
  run python3 "$PACKAGE/scripts/install-skill.py" --host zcode --dest "$CASE/refused/autopilot"
  [ "$status" -eq 1 ]
  [ ! -e "$CASE/refused" ]
}
