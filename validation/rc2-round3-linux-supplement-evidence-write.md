# Self-test control — rc2-linux-supplement-evidence-write

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent supplemental reviewer target; author concretized patch
- target: scripts/lib.sh
- patch sha256: b32805bc131eb97aa5f9ec0fd3e4a41e3847e90aa350418900d9cb1d9fa00f79
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ evidence\ write\ failure\ cannot\ publish.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/lib.sh
+++ b/scripts/lib.sh
@@ -5,6 +5,7 @@
 # Portable across GNU/Linux and macOS (bash 3.2, BSD userland).

 die() {
+  case "${2:-}" in "cannot write command evidence"|"cannot write evidence footer"|"incomplete evidence cannot be published") return 0 ;; esac
   local status="$1"
   shift
   printf "%s\n" "$*" | clean_output >&2

```
## Baseline
```
1..1
ok 1 evidence write failure cannot publish an incomplete success

```
## Mutant
```
1..1
not ok 1 evidence write failure cannot publish an incomplete success
# (in test file tests/supplements.bats, line 21)
#   `[ "$status" -eq 70 ]' failed
# Last output:
# /home/runner/proof/controls/rc2-linux-supplement-evidence-write/scripts/runner.sh: line 318: /tmp/bats-run-qkLZs4/test/1/case/evidence/unwritable.md.partial: Permission denied
# [gate] exit 0
# /home/runner/proof/controls/rc2-linux-supplement-evidence-write/scripts/runner.sh: line 343: /tmp/bats-run-qkLZs4/test/1/case/evidence/unwritable.md.partial: Permission denied
# evidence integrity check failed
# passed
# evidence: /tmp/bats-run-qkLZs4/test/1/case/evidence/unwritable.md (tested commit d19d179c93d69d74cc74c826cffb39e505eb0db1)

```
