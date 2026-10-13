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
  unset AUTOPILOT_RECORD AUTOPILOT_BASE AUTOPILOT_RUN_CONFIG
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
