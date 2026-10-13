# Self-test control — rc2-linux-rc2-source-readonly

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/runner.sh
- patch sha256: 557575bed66da82512def375387bfc86c9bdc85114a579ef7ed464384a63135b
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ source\ write\ and\ restore\ is\ prevented.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -176,7 +176,7 @@
         done < <(printf '%s' "$POLICY" | jq -r '.read_paths[]')
       fi
       SANDBOX_ARGS+=(--dev /dev --proc /proc --ro-bind "$GIT_COMMON" "$GIT_COMMON"
-        --ro-bind "$TREE" "$TREE" --bind "$RUN_HOME" "$RUN_HOME" --bind "$RUN_TMP" "$RUN_TMP"
+        --bind "$TREE" "$TREE" --bind "$RUN_HOME" "$RUN_HOME" --bind "$RUN_TMP" "$RUN_TMP"
         --bind "$RUN_OUTPUT" "$RUN_OUTPUT")
       while IFS= read -r path; do
         SANDBOX_ARGS+=(--bind "$TREE/$path" "$TREE/$path")

```
## Baseline
```
1..1
ok 1 source write and restore is prevented in env-clean and strict modes

```
## Mutant
```
1..1
not ok 1 source write and restore is prevented in env-clean and strict modes
# (in test file tests/rc2.bats, line 142)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# FAILED: sandbox preflight (red line)
# evidence: /tmp/bats-run-gDvaJu/test/1/case/evidence/plain.md (tested commit 7128e9434c8dc48c8227a29e0c85fcd6e7d96170)

```
