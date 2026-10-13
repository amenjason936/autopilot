# Self-test control — rc2-linux-c1-probe-enforcement

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent acceptance auditor target; author concretized patch
- target: scripts/runner.sh
- patch sha256: 6cf0378871f824871112d8b7a56df49e24f5fd058bc605520f6021daaabfabfa
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ fake\ sandbox\ allowing\ access\ fails.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -216,6 +216,7 @@
 }

 runner_probe() {
+  return 0
   # The source guard runs even in env-clean mode; no chmod-only fallback.
   local source_q output_q
   printf -v source_q '%q' "$TREE/.autopilot-source-probe"

```
## Baseline
```
1..1
ok 1 fake sandbox allowing access fails preflight before command

```
## Mutant
```
1..1
not ok 1 fake sandbox allowing access fails preflight before command
# (in test file tests/policy.bats, line 40)
#   `[ "$status" -eq 77 ]' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /tmp/bats-run-U2Vfks/test/1/case/evidence/fake.md (tested commit 57d42167d047d4ca60b4daf525d4f9fb6509fe31)

```
