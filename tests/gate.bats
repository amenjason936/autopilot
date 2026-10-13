#!/usr/bin/env bats
load test_helper

@test "gate runs at pinned commit inside a separate worktree" {
  original="$(git -C "$REPO" rev-parse HEAD)"
  original_dir="$(cd "$REPO" && pwd -P)"
  run gate bound "test \"\$PWD\" != '$original_dir' && test \"\$(git rev-parse HEAD)\" = '$original' && test \"\$(cat value)\" = safe"
  [ "$status" -eq 0 ]
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID"
  [ "$status" -eq 0 ]
}

@test "gate refuses dirty code and does not create evidence" {
  printf dirty >>"$REPO/value"
  run gate dirty true
  [ "$status" -eq 65 ]
  [ ! -e "$EVID/dirty.md" ]
}

@test "gate failure still executes remaining commands" {
  run gate red 'exit 3' 'printf last-command'
  [ "$status" -eq 1 ]
  grep -q last-command "$EVID/red.md"
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID" red.md
  [ "$status" -eq 0 ]
}

@test "gate mutation affects only the disposable tree and fails" {
  run gate changed 'printf changed > value'
  [ "$status" -eq 1 ]
  [ "$(cat "$REPO/value")" = safe ]
}

@test "gate rejects concurrent source HEAD movement" {
  run gate moved "git -C '$REPO' -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit --allow-empty -qm concurrent"
  [ "$status" -eq 1 ]
}

@test "clean environment drops ambient variables and provides a fresh HOME" {
  export AMBIENT_PRIVATE=do-not-inherit
  export ALLOWED_FLAG=present
  export GATE_ENV=ALLOWED_FLAG
  run gate env 'test -z "${AMBIENT_PRIVATE+x}" && test "$ALLOWED_FLAG" = present && test -d "$HOME" && test ! -f "$HOME/.netrc"'
  [ "$status" -eq 0 ]
  ! grep -q '=present' "$EVID/env.md"
}

@test "secret and injection environment names are refused" {
  for name in API_KEY access_token SECRET_VALUE PASSWORD BASH_ENV LD_PRELOAD NODE_OPTIONS; do
    export GATE_ENV="$name"
    run gate denied true
    [ "$status" -eq 64 ]
  done
}

@test "dry-run prints setup commands and policy without running or writing" {
  export GATE_SETUP="touch '$CASE/executed'"
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$CASE/absent/preview.md" preview "touch '$CASE/executed'"
  [ "$status" -eq 0 ]
  [[ "$output" == *DRY* && "$output" == *env-clean* && "$output" == *GATE_SETUP* ]]
  [ ! -e "$CASE/executed" ]
  [ ! -e "$CASE/absent" ]
}

@test "partial resume archives old content and never overwrites completed evidence" {
  export GATE_RERUN_POLICY=safe
  printf 'interrupted payload\n' >"$EVID/resume.md.partial"
  run gate resume true
  [ "$status" -eq 0 ]
  run bash -c 'cat "$1"/resume.md.partial.*' _ "$EVID"
  [ "$output" = 'interrupted payload' ]
  run gate resume true
  [ "$status" -eq 73 ]
}

@test "directory lock rejects concurrent run before executing commands" {
  mkdir "$EVID/.autopilot.lock"
  run gate locked "touch '$CASE/executed'"
  [ "$status" -eq 73 ]
  [ ! -e "$CASE/executed" ]
}

@test "timeout is recorded and its descendants stop" {
  export GATE_TIMEOUT=1
  run gate timeout "(sleep 3; touch '$CASE/orphan') & wait"
  [ "$status" -eq 1 ]
  grep -q 'timeout=1' "$EVID/timeout.md"
  sleep 3
  [ ! -e "$CASE/orphan" ]
}

@test "manifest detects tampering, missing entries, duplicates, and path traversal" {
  gate integrity true
  printf tampered >>"$EVID/integrity.md"
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID"
  [ "$status" -eq 1 ]
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID" absent.md
  [ "$status" -eq 1 ]
  cat "$EVID/MANIFEST" >>"$EVID/duplicate"
  cat "$EVID/duplicate" >>"$EVID/MANIFEST"
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID"
  [ "$status" -eq 1 ]
  printf '%064d  ../escape\n' 0 >"$EVID/MANIFEST"
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID"
  [ "$status" -eq 1 ]
}

@test "gate CLI validates usage paths labels and numeric settings" {
  run bash "$SKILL/scripts/run-gate.sh"
  [ "$status" -eq 64 ]
  run bash "$SKILL/scripts/run-gate.sh" "$CASE/missing" "$EVID/a.md" a true
  [ "$status" -eq 66 ]
  run gate '../bad' true
  [ "$status" -eq 64 ]
  export GATE_TIMEOUT=bad
  run gate timeout true
  [ "$status" -eq 64 ]
}

@test "untrusted output is recorded without executing embedded commands" {
  payload="touch '$CASE/injected'"
  run gate injection "printf '%s\n' \"$payload\""
  [ "$status" -eq 0 ]
  [ ! -e "$CASE/injected" ]
  grep -q injected "$EVID/injection.md"
}

@test "normal command exit also kills background children ignoring TERM" {
  run gate stragglers "(trap '' TERM; sleep 2; touch '$CASE/orphan') & sleep 0.2"
  [ "$status" -eq 0 ]
  sleep 2
  [ ! -e "$CASE/orphan" ]
}

@test "worktree creation never executes repository smudge filters" {
  printf 'value filter=hostprobe\n' >"$REPO/.gitattributes"
  commit_fixture
  git -C "$REPO" config filter.hostprobe.smudge "printf breach > '$CASE/smudge-marker'; cat"
  run gate filter 'test "$(cat value)" = safe'
  [ "$status" -eq 0 ]
  [ ! -e "$CASE/smudge-marker" ]
}

@test "dry-run never executes repository fsmonitor callbacks" {
  printf '#!/bin/bash\nprintf breach > "%s"\nprintf "token\\000"\n' "$CASE/fsmonitor-marker" >"$CASE/fsmonitor"
  chmod +x "$CASE/fsmonitor"
  git -C "$REPO" config core.fsmonitor "$CASE/fsmonitor"
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$EVID/dry.md" dry true
  [ "$status" -eq 0 ]
  [ ! -e "$CASE/fsmonitor-marker" ]
}

@test "verifier refuses evidence reached through a symlink directory" {
  gate actual true
  ln -s "$EVID" "$CASE/link"
  run bash "$SKILL/scripts/verify-evidence.sh" "$CASE/link" actual.md
  [ "$status" -eq 1 ]
}

@test "initial status and cleanup never execute clean filters" {
  printf 'value filter=hostprobe\n' >"$REPO/.gitattributes"
  commit_fixture
  git -C "$REPO" config filter.hostprobe.clean "printf breach > '$CASE/clean-marker'; cat"
  printf 'safe\n' >"$REPO/value"
  run gate cleanfilter 'test "$(cat value)" = safe'
  [ "$status" -eq 0 ]
  [ ! -e "$CASE/clean-marker" ]
}

@test "worktree-conditional filters cannot execute before sandboxing" {
  printf 'value filter=conditional\n' >"$REPO/.gitattributes"
  commit_fixture
  cat >"$CASE/conditional.config" <<EOF
[filter "conditional"]
    smudge = "printf breach > '$CASE/conditional-marker'; cat"
    clean = cat
EOF
  git -C "$REPO" config 'includeIf.gitdir:**/worktrees/**.path' "$CASE/conditional.config"
  run gate conditional 'test "$(cat value)" = safe'
  [ "$status" -eq 0 ]
  [ ! -e "$CASE/conditional-marker" ]
}
