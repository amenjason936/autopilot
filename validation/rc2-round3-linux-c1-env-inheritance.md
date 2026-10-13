# Self-test control — rc2-linux-c1-env-inheritance

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent acceptance auditor target; author concretized patch
- target: scripts/runner.sh
- patch sha256: e89aac68238a4ddcd8f1f7124c0793043d69d616ddc4307df736b0d9f8135925
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ clean\ environment\ drops\ ambient.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -146,7 +146,7 @@
   printf 'immutable\n' >"$TREE/.autopilot-source-probe" || die 70 'cannot prepare source probe'
   python3 "$SCRIPT_DIR/source_state.py" prepare "$TREE" "$WORK/policy.json" "$SOURCE_STATE" || die 64 'write_dirs must be new output directories outside tracked source'
   python3 "$SCRIPT_DIR/source_state.py" freeze "$TREE" "$WORK/policy.json" "$SOURCE_STATE" || die 70 'cannot freeze source inputs'
-  RUN_ENV=(env -i "PATH=$PATH" "HOME=$RUN_HOME" "TMPDIR=$RUN_TMP" LC_ALL=C
+  RUN_ENV=(env "PATH=$PATH" "HOME=$RUN_HOME" "TMPDIR=$RUN_TMP" LC_ALL=C
     GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_OPTIONAL_LOCKS=0 "AUTOPILOT_OUTPUT=$RUN_OUTPUT")
   for name in ${ENV_NAMES[@]+"${ENV_NAMES[@]}"}; do
     [ "${!name+x}" != x ] || RUN_ENV+=("$name=${!name}")

```
## Baseline
```
1..1
ok 1 clean environment drops ambient variables and provides a fresh HOME

```
## Mutant
```
1..1
not ok 1 clean environment drops ambient variables and provides a fresh HOME
# (in test file tests/gate.bats, line 43)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# [gate] exit 1
# FAILED
# evidence: /tmp/bats-run-GdLTbG/test/1/case/evidence/env.md (tested commit c50bbf811b1ff735daa2c0c73893088b1f3b1315)

```
