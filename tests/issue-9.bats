#!/usr/bin/env bats
load test_helper
# Regressions for the field report in issue #9.

@test "the helper digest does not depend on the path the skill is reached by" {
  ln -s "$SKILL" "$CASE/linked-skill"
  a="$(python3 -I -S "$SKILL/scripts/integrity.py" "$SKILL/scripts")"
  b="$(python3 -I -S "$SKILL/scripts/integrity.py" "$CASE/linked-skill/scripts")"
  [ "$a" = "$b" ]
}

@test "sandbox-exec profiles let processes signal their own children and admit loopback only when asked" {
  run bash -c "printf '{\"version\":1,\"deny_network\":true}' | python3 -c 'import json,sys; sys.path.insert(0, \"$SKILL/scripts\"); sys.dont_write_bytecode=True; import policy; p=policy.normalize(json.load(sys.stdin)); p[\"sandbox\"]=\"sandbox-exec\"; print(policy.profile(p, \"/t\", \"/h\", \"/tmp/x\", \"/g\", \"/s\", \"/o\", \"/w\", \"/k\", \"/e\"))'"
  [[ "$output" == *'(allow signal (target same-sandbox))'* ]]
  [[ "$output" != *'localhost'* ]]
  run bash -c "printf '{\"version\":1,\"deny_network\":true,\"allow_loopback\":true}' | python3 -c 'import json,sys; sys.path.insert(0, \"$SKILL/scripts\"); sys.dont_write_bytecode=True; import policy; p=policy.normalize(json.load(sys.stdin)); p[\"sandbox\"]=\"sandbox-exec\"; print(policy.profile(p, \"/t\", \"/h\", \"/tmp/x\", \"/g\", \"/s\", \"/o\", \"/w\", \"/k\", \"/e\"))'"
  [[ "$output" == *'(allow network* (remote ip "localhost:*"))'* ]]
  [[ "$output" != *'(allow network*)'* ]]
}

@test "a strict gate can use 127.0.0.1 inside its own network namespace" {
  require_os_sandbox
  [ "$(uname -s)" != Darwin ] || skip 'macOS needs allow_loopback; covered by the profile test'
  mkdir -p "$REPO/docs"; printf '{"version":1,"deny_network":true}' >"$REPO/docs/autopilot-policy.json"; commit_fixture
  run gate loop "python3 -c 'import socket; s=socket.socket(); s.bind((\"127.0.0.1\", 0)); s.listen(); c=socket.create_connection(s.getsockname()); print(\"LOOPBACK_OK\")'"
  [ "$status" -eq 0 ]
  grep -q LOOPBACK_OK "$EVID/loop.md"
}

@test "share_dirs links an ignored checkout directory read-only into the gate's worktree" {
  mkdir -p "$REPO/docs" "$REPO/deps"
  printf 'deps\n' >>"$REPO/.gitignore"
  printf 'from-checkout\n' >"$REPO/deps/lib.txt"
  printf '{"version":1,"share_dirs":["deps"]}' >"$REPO/docs/autopilot-policy.json"
  commit_fixture
  run gate shared 'cat deps/lib.txt' 'if printf x >deps/new 2>/dev/null; then echo WROTE; exit 1; fi'
  [ "$status" -eq 0 ] || { cat "$EVID/shared.md"; false; }
  grep -q 'from-checkout' "$EVID/shared.md"
  grep -q '^- shared read-only from the checkout (not installed from a lockfile): deps$' "$EVID/shared.md"
  [ ! -e "$REPO/deps/new" ]
  printf '{"version":1,"share_dirs":["value"]}' >"$REPO/docs/autopilot-policy.json"; commit_fixture
  run gate tracked true
  [ "$status" -eq 64 ]
  [[ "$output" == *'share_dirs entry is tracked source: value'* ]]
}

@test "codex dispatch under a network-only ban needs explicit approval; deny_paths still parks" {
  mkdir -p "$REPO/docs" "$CASE/bin"
  printf '#!/bin/sh\ntouch "%s"; exit 9\n' "$CASE/cloud-called" >"$CASE/bin/codex"; chmod +x "$CASE/bin/codex"
  export PATH="$CASE/bin:$PATH"
  printf 'record\n' >"$REPO/record.md"
  printf '{"version":1,"deny_network":true}' >"$REPO/docs/autopilot-policy.json"; commit_fixture
  run bash "$SKILL/scripts/codex-review.sh" "$REPO" HEAD "$REPO/record.md" "$CASE/f1.json"
  [ "$status" -eq 77 ]
  [[ "$output" == *'CODEX_REVIEW_DISPATCH=approved'* ]]
  [ ! -e "$CASE/cloud-called" ]
  CODEX_REVIEW_DISPATCH=approved run bash "$SKILL/scripts/codex-review.sh" "$REPO" HEAD "$REPO/record.md" "$CASE/f2.json"
  [ -e "$CASE/cloud-called" ]
  rm "$CASE/cloud-called"
  printf '{"version":1,"deny_paths":["/nonexistent-secret"]}' >"$REPO/docs/autopilot-policy.json"; commit_fixture
  CODEX_REVIEW_DISPATCH=approved run bash "$SKILL/scripts/codex-review.sh" "$REPO" HEAD "$REPO/record.md" "$CASE/f3.json"
  [ "$status" -eq 77 ]
  [ ! -e "$CASE/cloud-called" ]
}

@test "prompt-only asks for the JSON as the final message and the validator names the seal step" {
  printf 'record\n' >"$REPO/record.md"; commit_fixture
  run bash "$SKILL/scripts/codex-review.sh" --prompt-only "$REPO" HEAD "$REPO/record.md" "$CASE/f.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'return the JSON document as your final message'* ]]
  printf '{"verdict":"approve","summary":"s","findings":[],"limits":"l"}' >"$CASE/f.json"
  base="$(git -C "$REPO" rev-parse HEAD)"
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/f.json" "$CASE/f.json.request.json" "$REPO" "$base" "$base" record.md landing
  [ "$status" -eq 70 ]
  [[ "$output" == *'review_identity.py seal'* ]]
}
