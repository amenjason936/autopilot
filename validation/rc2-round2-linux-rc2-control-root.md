# Self-test control — rc2-linux-rc2-control-root

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/runner.sh
- patch sha256: 31dc7c36e35a9639e3310ea18a2bbe0255f7980654f1c38db01eb7b0baf50c23
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ commands\ cannot\ rewrite\ runner\ controls.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -167,7 +167,7 @@
       require bwrap
       SANDBOX_ARGS=(bwrap --die-with-parent --new-session --unshare-pid --unshare-user --unshare-ipc --unshare-uts --cap-drop ALL)
       if [ "$SANDBOX" = env-clean ]; then
-        SANDBOX_ARGS+=(--bind / / --ro-bind "$TOP" "$TOP" --ro-bind "$WORK" "$WORK"
+        SANDBOX_ARGS+=(--bind / / --ro-bind "$TOP" "$TOP" --bind "$WORK" "$WORK"
           --ro-bind "$SCRIPT_DIR" "$SCRIPT_DIR" --ro-bind "$EVIDENCE_DIR" "$EVIDENCE_DIR")
       else
         SANDBOX_ARGS+=(--unshare-net)

```
## Baseline
```
1..1
ok 1 commands cannot rewrite runner controls helpers or evidence

```
## Mutant
```
1..1
not ok 1 commands cannot rewrite runner controls helpers or evidence
# (in test file tests/rc2.bats, line 191)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# [gate] exit 1
# [gate] exit 0
# [gate] exit 0
# [gate] exit 0
# FAILED
# evidence: /tmp/bats-run-kELpVc/test/1/case/evidence/controls.md (tested commit 3825fe738dd64eb6f2d4eefa71cf4ff4dcfba834)

```
