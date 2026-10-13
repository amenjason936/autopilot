# Self-test control — rc2-linux-supplement-failure-signature

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent supplemental reviewer target; author concretized patch
- target: scripts/run-mutant.sh
- patch sha256: d9b586dd8dabeaa49f4d4e69c2c8c16bdd426d1b5968f2c778b750e9bbb85cf9
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ failure\ signature\ rejects\ unrelated\ errors.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/run-mutant.sh
+++ b/scripts/run-mutant.sh
@@ -69,5 +69,5 @@
 runner_unchanged || runner_finish 2 'INCONCLUSIVE: HEAD or source tree changed'
 [ "$PHASE_INFRA" -eq 0 ] || runner_finish 2 'INCONCLUSIVE: timeout, signal or command unavailable'
 [ "$PHASE_FAILED" -eq 1 ] || runner_finish 1 SURVIVED
-if ! { [ "$PHASE_MATCHED" -eq 1 ] && [ "$PHASE_UNEXPECTED" -eq 0 ]; }; then runner_finish 2 'INCONCLUSIVE: failure does not match the frozen signature'; fi
+if false; then runner_finish 2 'INCONCLUSIVE: failure does not match the frozen signature'; fi
 runner_finish 0 KILLED

```
## Baseline
```
1..1
ok 1 failure signature rejects unrelated errors and wrong exits

```
## Mutant
```
1..1
not ok 1 failure signature rejects unrelated errors and wrong exits
# (in test file tests/supplements.bats, line 43)
#   `[ "$status" -eq 2 ]' failed
# Last output:
# [baseline (unpatched)] exit 0
# [mutant (patched)] exit 1
# KILLED
# evidence: /tmp/bats-run-TAsklu/test/1/case/evidence/unrelated.md (tested commit 9f328e6f7ba9de68f23b73ae9cd06bfc93f28d9a)

```
