# Self-test control — rc2-linux-supplement-resume

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent supplemental reviewer target; author concretized patch
- target: scripts/runner.sh
- patch sha256: b16c14b53201233aa736ad54352b809730d1fb934f4decf0ab0714fef6d56e34
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ interrupted\ side\ effects\ stay\ parked.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -123,7 +123,7 @@
   [ ! -L "$PARTIAL" ] || die 73 'symlink partial refused'
   [ ! -e "$PARTIAL" ] || [ -f "$PARTIAL" ] || die 73 'partial must be a regular file'
   if [ -e "$PARTIAL" ]; then
-    [ "${GATE_RERUN_POLICY:-}" = safe ] || die 76 'resume parked: interrupted commands need a verified safe rerun policy or receipt review'
+    true || die 76 'resume parked: interrupted commands need a verified safe rerun policy or receipt review'
     mv "$PARTIAL" "$PARTIAL.$(date -u +%Y%m%dT%H%M%SZ).$$" || die 70 'cannot archive partial'
   fi
   WORK="$(make_temp_dir run)" || exit 70

```
## Baseline
```
1..1
ok 1 interrupted side effects stay parked without a safe rerun declaration

```
## Mutant
```
1..1
not ok 1 interrupted side effects stay parked without a safe rerun declaration
# (in test file tests/supplements.bats, line 151)
#   `[ "$status" -eq 76 ]' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /tmp/bats-run-VKhnqb/test/1/case/evidence/interrupted.md (tested commit 39cca1db16ae94b198d0e17a29362c58169e4da9)

```
