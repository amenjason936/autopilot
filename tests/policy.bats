#!/usr/bin/env bats
load test_helper

@test "contract policy forces a strong sandbox even when env-clean requested" {
  mkdir "$REPO/docs"
  printf 'contract\n' >"$REPO/docs/autopilot.md"
  printf '{"version":1,"deny_network":true,"deny_paths":[]}' >"$REPO/docs/autopilot-policy.json"
  commit_fixture
  export GATE_SANDBOX=env-clean
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$EVID/preview.md" preview true
  [ "$status" -eq 0 ]
  if [ "$(uname -s)" = Darwin ]; then [[ "$output" == *'sandbox: sandbox-exec'* ]]; else [[ "$output" == *'sandbox: bwrap'* ]]; fi
}

@test "contract missing policy and malformed policy fail closed" {
  mkdir "$REPO/docs"
  printf 'no policy\n' >"$REPO/docs/autopilot.md"
  commit_fixture
  run gate missing true
  [ "$status" -eq 64 ]
  printf '{"deny_network":"false"}' >"$REPO/docs/autopilot-policy.json"
  commit_fixture
  run gate bad true
  [ "$status" -eq 64 ]
}

@test "fake sandbox allowing access fails preflight before command" {
  mkdir "$CASE/bin"
  # Both adapters are deliberately permissive; neither may pass the probes.
  for backend in sandbox-exec bwrap; do
    cat >"$CASE/bin/$backend" <<'STUB'
#!/bin/bash
while [ "$#" -gt 0 ] && [ "$1" != /bin/bash ]; do shift; done
exec "$@"
STUB
    chmod +x "$CASE/bin/$backend"
  done
  export PATH="$CASE/bin:$PATH"
  run gate fake "touch '$CASE/executed'"
  [ "$status" -eq 77 ]
  [ ! -e "$CASE/executed" ]
}

@test "real OS sandbox blocks forbidden path and network with passing positive control" {
  require_os_sandbox
  mkdir "$REPO/docs"
  printf '{"version":1,"deny_network":true}' >"$REPO/docs/autopilot-policy.json"
  commit_fixture
  run gate strict 'test "$(cat value)" = safe'
  # Once the backend can launch, a failed boundary is a test failure.
  [ "$status" -eq 0 ]
  grep -q 'sandbox probes: PASS' "$EVID/strict.md"
}

@test "explicit deny path overrides an allowed runtime directory" {
  require_os_sandbox
  mkdir -p "$CASE/allowed/restricted" "$REPO/docs"
  printf control >"$CASE/allowed/control"
  printf synthetic >"$CASE/allowed/restricted/canary"
  python3 - "$REPO/docs/autopilot-policy.json" "$CASE/allowed" <<'PY'
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({'version':1,'deny_paths':[sys.argv[2]+'/restricted'],'read_paths':[sys.argv[2]]}))
PY
  commit_fixture
  run gate deny "test \"\$(cat '$CASE/allowed/control')\" = control && ! cat '$CASE/allowed/restricted/canary' && ! touch '$CASE/allowed/restricted/created'"
  [ "$status" -eq 0 ]
  [ ! -e "$CASE/allowed/restricted/created" ]
}
