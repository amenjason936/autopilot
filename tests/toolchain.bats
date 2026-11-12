#!/usr/bin/env bats
load test_helper
# A strict profile reads only the policy's roots: an interpreter installed
# elsewhere aborts inside the gate, long after takeoff. host-doctor says so first.

stub_node() {
  mkdir -p "$CASE/tools" "$REPO/docs"
  printf '#!/bin/sh\nexit 0\n' >"$CASE/tools/node"; chmod +x "$CASE/tools/node"
  TOOLS="$(cd "$CASE/tools" && pwd -P)"
}

@test "host-doctor names a toolchain outside a restrictive policy's read paths" {
  stub_node
  printf '{"version":1,"deny_network":true}' >"$REPO/docs/autopilot-policy.json"; commit_fixture
  PATH="$TOOLS:$PATH" run bash "$SKILL/scripts/host-doctor.sh" "$REPO"
  [[ "$output" == *"toolchain: node resolves to $TOOLS/node, outside the policy's read paths"* ]] || false
  [[ "$output" == *'read_paths'* ]]
}

@test "host-doctor accepts a toolchain the policy lists and stays quiet for an unrestricted policy" {
  stub_node
  printf '{"version":1,"deny_network":true,"read_paths":["%s"]}' "$TOOLS" >"$REPO/docs/autopilot-policy.json"; commit_fixture
  PATH="$TOOLS:$PATH" run bash "$SKILL/scripts/host-doctor.sh" "$REPO"
  [[ "$output" != *'toolchain: node'* ]] || false
  printf '{"version":1}' >"$REPO/docs/autopilot-policy.json"; commit_fixture
  PATH="$TOOLS:$PATH" run bash "$SKILL/scripts/host-doctor.sh" "$REPO"
  [[ "$output" != *'toolchain:'* ]]
}
