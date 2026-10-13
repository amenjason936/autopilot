#!/usr/bin/env bats
load test_helper

unavailable_backend() {
  mkdir -p "$CASE/bin"
  for backend in bwrap sandbox-exec; do
    printf '#!/bin/sh\necho BACKEND_UNAVAILABLE >&2\nexit 1\n' >"$CASE/bin/$backend"
    chmod +x "$CASE/bin/$backend"
  done
  export PATH="$CASE/bin:$PATH"
}

@test "env-clean runs with an unavailable backend and discloses its weaker boundary" {
  unavailable_backend
  run gate portable 'test "$(cat value)" = safe; printf artifact > "$AUTOPILOT_OUTPUT/result"'
  [ "$status" -eq 0 ]
  grep -q 'source protection: NOT OS-ENFORCED' "$EVID/portable.md"
  ! grep -q 'source guard: PASS' "$EVID/portable.md"
  run gate changed 'printf changed >value'
  [ "$status" -eq 1 ]
  [ "$(cat "$REPO/value")" = safe ]
}

@test "failed strict preflight leaves no partial and retries without exit 76" {
  unavailable_backend
  mkdir "$REPO/docs"
  printf '{"version":1,"deny_network":true}' >"$REPO/docs/autopilot-policy.json"
  commit_fixture
  for attempt in 1 2; do
    run gate retry "touch '$CASE/executed'"
    [ "$status" -eq 77 ]
    [ ! -e "$CASE/executed" ]
    [ ! -e "$EVID/retry.md.partial" ]
    [ ! -e "$EVID/retry.md" ]
  done
  patch_value
  for attempt in 1 2; do
    run mutant retrymutant "touch '$CASE/executed'"
    [ "$status" -eq 77 ]
    [ ! -e "$EVID/retrymutant.md.partial" ]
  done
}

@test "invalid mutant patch before execution does not park a later retry" {
  unavailable_backend
  printf 'not a patch' >"$CASE/change.patch"
  run mutant invalid true
  [ "$status" -eq 65 ]
  [ ! -e "$EVID/invalid.md.partial" ]
  patch_value
  export MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$'
  run mutant invalid 'test "$(cat value)" = safe || { echo ASSERT_VALUE_SAFE; exit 1; }'
  [ "$status" -eq 0 ]
}

@test "stage review identity honors legacy focus and explicit scope and rejects conflicts" {
  printf record >"$REPO/record.md"
  commit_fixture
  run bash "$SKILL/scripts/codex-review.sh" --prompt-only "$REPO" HEAD "$REPO/record.md" "$CASE/legacy.json" stage 2
  [ "$status" -eq 0 ]
  [ "$(jq -r .inputs.scope "$CASE/legacy.json.request.json")" = 'stage 2' ]
  run bash "$SKILL/scripts/codex-review.sh" --scope 'stage 3' --prompt-only "$REPO" HEAD "$REPO/record.md" "$CASE/explicit.json" reliability
  [ "$status" -eq 0 ]
  [ "$(jq -r .inputs.scope "$CASE/explicit.json.request.json")" = 'stage 3' ]
  run bash "$SKILL/scripts/codex-review.sh" --scope landing --prompt-only "$REPO" HEAD "$REPO/record.md" "$CASE/conflict.json" stage 2
  [ "$status" -eq 64 ]
  [ ! -e "$CASE/conflict.json.request.json" ]
}

@test "canonical clone remains manual-only for Claude Code" {
  grep -q '^disable-model-invocation: true$' "$SKILL/SKILL.md"
  grep -q 'allow_implicit_invocation: false' "$SKILL/agents/openai.yaml"
}

@test "default host configuration runs env-clean without administrative changes" {
  run gate stock 'test "$(cat value)" = safe'
  [ "$status" -eq 0 ]
  grep -E 'source guard: PASS|source protection: NOT OS-ENFORCED' "$EVID/stock.md"
}

@test "missing sandbox executable permits env-clean but refuses strict policy" {
  mkdir "$CASE/minimal-bin"
  for tool in git perl python3 jq bash env dirname basename mkdir mktemp cat rm rmdir date uname sha256sum shasum awk tail chmod mv; do
    location="$(command -v "$tool" || true)"
    [ -z "$location" ] || ln -s "$location" "$CASE/minimal-bin/$tool"
  done
  run env PATH="$CASE/minimal-bin" /bin/bash "$SKILL/scripts/run-gate.sh" "$REPO" "$EVID/missing.md" missing true
  [ "$status" -eq 0 ]
  grep -q 'source protection: NOT OS-ENFORCED' "$EVID/missing.md"
  mkdir "$REPO/docs"
  printf '{"version":1,"deny_network":true}' >"$REPO/docs/autopilot-policy.json"
  commit_fixture
  run env PATH="$CASE/minimal-bin" /bin/bash "$SKILL/scripts/run-gate.sh" "$REPO" "$EVID/strictmissing.md" strictmissing true
  [ "$status" -eq 77 ]
  [ ! -e "$EVID/strictmissing.md.partial" ]
}
