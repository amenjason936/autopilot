# Self-test control — rc2-linux-p0-1-worktree

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/runner.sh
- patch sha256: 1e7049ce715bd1262a1f67066beda0362f78540f87f61f8887ce471906aa907d
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ gate\ runs\ at\ pinned\ commit.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -193,7 +193,7 @@
       # Synthetic ancestor directories must not be writable in strict mode.
       # Remount only the new root: explicit output/HOME/TMP mounts stay writable.
       [ "$SANDBOX" = env-clean ] || SANDBOX_ARGS+=(--remount-ro /)
-      SANDBOX_ARGS+=(--chdir "$TREE$SUBDIR")
+      SANDBOX_ARGS+=(--chdir "$WORKDIR")
       ;;
   esac
 }

```
## Baseline
```
1..1
ok 1 gate runs at pinned commit inside a separate worktree

```
## Mutant
```
1..1
not ok 1 gate runs at pinned commit inside a separate worktree
# (in test file tests/gate.bats, line 7)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# [gate] exit 1
# FAILED
# evidence: /tmp/bats-run-LplTYY/test/1/case/evidence/bound.md (tested commit 321f253a34878c04300464a3425beaeeb9988357)

```
