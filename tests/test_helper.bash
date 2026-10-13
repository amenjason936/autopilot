setup() {
  SKILL="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  export SKILL
  CASE="$BATS_TEST_TMPDIR/case"
  mkdir -p "$CASE/repo" "$CASE/evidence"
  REPO="$CASE/repo"
  EVID="$CASE/evidence"
  export REPO EVID
  git -C "$REPO" init -q
  git -C "$REPO" config user.name 'Autopilot Fixture'
  git -C "$REPO" config user.email 'fixture@example.invalid'
  git -C "$REPO" config commit.gpgsign false
  printf 'safe\n' >"$REPO/value"
  printf '__pycache__/\n' >"$REPO/.gitignore"
  git -C "$REPO" add .
  git -C "$REPO" commit -qm fixture
  unset GATE_ENV GATE_POLICY GATE_SANDBOX GATE_SETUP MUTANT_SETUP REDACT_REGEX
  unset AUTOPILOT_RECORD AUTOPILOT_BASE AUTOPILOT_RUN_CONFIG MUTANT_FAILURE_REGEX MUTANT_FAILURE_EXIT GATE_RERUN_POLICY
  pin_helpers
}

# Tests pin the helpers as a run does at takeoff, so a work-in-progress
# checkout of the skill can still run them. Trust-reference tests unset it.
pin_helpers() {
  AUTOPILOT_HELPER_PIN="$(python3 -I -S "$SKILL/scripts/integrity.py" "$SKILL/scripts")"
  export AUTOPILOT_HELPER_PIN
}

gate() { bash "$SKILL/scripts/run-gate.sh" "$REPO" "$EVID/$1.md" "$1" "${@:2}"; }
mutant() { bash "$SKILL/scripts/run-mutant.sh" "$REPO" "$EVID/$1.md" "$1" "$CASE/change.patch" "${@:2}"; }
patch_value() {
  cat >"$CASE/change.patch" <<'PATCH'
diff --git a/value b/value
--- a/value
+++ b/value
@@ -1 +1 @@
-safe
+broken
PATCH
}
commit_fixture() { git -C "$REPO" add .; git -C "$REPO" commit -qm fixture; }

# Destructive runner tests always attack a disposable helper copy.
isolate_runner() {
  mkdir -p "$CASE/skill-copy"
  cp -R "$SKILL/scripts" "$CASE/skill-copy/"
  SKILL="$CASE/skill-copy"
  export SKILL
  pin_helpers
}

unavailable_backend() {
  mkdir -p "$CASE/bin"
  for backend in bwrap sandbox-exec; do
    printf '#!/bin/sh\necho BACKEND_UNAVAILABLE >&2\nexit 1\n' >"$CASE/bin/$backend"
    chmod +x "$CASE/bin/$backend"
  done
  export PATH="$CASE/bin:$PATH"
}

# Capability detection is independent of the runner under test. Only a backend
# that cannot launch is unavailable; a permissive/broken boundary still fails tests.
require_os_sandbox() {
  local available=0
  if [ "$(uname -s)" = Darwin ]; then
    if command -v sandbox-exec >/dev/null 2>&1 && sandbox-exec -p '(version 1)(allow default)' /usr/bin/true >/dev/null 2>&1; then available=1; fi
  else
    if command -v bwrap >/dev/null 2>&1 && bwrap --die-with-parent --unshare-user --unshare-pid --ro-bind / / --proc /proc --dev /dev /bin/true >/dev/null 2>&1; then available=1; fi
  fi
  [ "$available" -eq 0 ] || return 0
  if [ "${AUTOPILOT_REQUIRE_SANDBOX:-0}" = 1 ]; then
    printf '%s\n' 'OS sandbox backend cannot launch, but this run requires real isolation tests' >&2
    return 1
  fi
  skip 'OS sandbox backend cannot launch; isolation not verified'
}
