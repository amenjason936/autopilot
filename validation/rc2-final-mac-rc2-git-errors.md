# Self-test control — rc2-final-mac-rc2-git-errors

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/runner.sh
- patch sha256: ef4f6f158e298bd140ad682097476a044a522f7d3550e672c6d979843399d354
- baseline exit: 0
- mutant exit: 0
- expected failure signature: ^not ok [0-9]+ failed\ git\ status\ with\ empty\ output.*$
- result: SURVIVED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -327,7 +327,7 @@
 runner_unchanged() {
   [ "$(git -C "$TOP" rev-parse HEAD)" = "$COMMIT" ] || return 1
   local state
-  state="$(cd "$TOP" && git_code status --porcelain)" || return 1
+  state="$(cd "$TOP" && git_code status --porcelain)"
   [ -z "$state" ] || return 1
   [ "$(git -C "$TREE" rev-parse HEAD)" = "$COMMIT" ] || return 1
 }

```
## Baseline
```
1..1
ok 1 failed git status with empty output cannot prove clean source

```
## Mutant
```
1..1
ok 1 failed git status with empty output cannot prove clean source

```
