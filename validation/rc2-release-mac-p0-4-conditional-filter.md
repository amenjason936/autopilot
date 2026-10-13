# Self-test control — rc2-release-mac-p0-4-conditional-filter

- tested commit: d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/lib.sh
- patch sha256: 2aca9611855f9f8bdc1fba1848ffa00bba5d4cc653887257aaf38048cb44b7b2
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ worktree\-conditional\ filters\ cannot\ execute.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/lib.sh
+++ b/scripts/lib.sh
@@ -200,7 +200,7 @@

 safe_worktree_add() {
   disable_git_callbacks "$1"
-  git -C "$1" worktree add --quiet --no-checkout --detach "$2" "$3" || return
+  git -C "$1" worktree add --quiet --detach "$2" "$3" || return
   # includeIf gitdir/worktree config can introduce filters only in the new tree.
   # Discover those BEFORE materializing any tracked file.
   disable_git_callbacks "$2"

```
## Baseline
```
1..1
ok 1 worktree-conditional filters cannot execute before sandboxing

```
## Mutant
```
1..1
not ok 1 worktree-conditional filters cannot execute before sandboxing
# (in test file tests/gate.bats, line 181)
#   `[ ! -e "$CASE/conditional-marker" ]' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/bats-run-dQE06w/test/1/case/evidence/conditional.md (tested commit cb21c15356f4f5742c7f2d5ae80557a2b6fee7f1)

```
