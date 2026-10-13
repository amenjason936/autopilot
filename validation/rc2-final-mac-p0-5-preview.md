# Self-test control — rc2-final-mac-p0-5-preview

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/run-gate.sh
- patch sha256: 61e2ad10d68c6641364622ae698b6168977552527a0dd9212858cfd48c707e2c
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ dry\-run\ prints\ setup\ commands.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/run-gate.sh
+++ b/scripts/run-gate.sh
@@ -14,7 +14,7 @@
 [ $# -ge 4 ] || die 64 'usage: run-gate.sh [--dry-run] [--lite] <workdir> <evidence-file> <label> <command>...'
 runner_init "$1" "$2" "$3"
 shift 3
-if [ "$DRY_RUN" -eq 1 ]; then runner_preview "$@"; exit 0; fi
+if [ "$DRY_RUN" -eq 9 ]; then runner_preview "$@"; exit 0; fi
 runner_lock
 runner_header 'Machine gate'
 runner_tree tree

```
## Baseline
```
1..1
ok 1 dry-run prints setup commands and policy without running or writing

```
## Mutant
```
1..1
not ok 1 dry-run prints setup commands and policy without running or writing
# (in test file tests/gate.bats, line 60)
#   `[ ! -e "$CASE/executed" ]' failed
# Last output:
# [setup] exit 0
# [gate] exit 0
# passed
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/bats-run-8mmoPR/test/1/case/absent/preview.md (tested commit 932d942f2f9dddf5758306dfed96fd3465d5ef55)

```
