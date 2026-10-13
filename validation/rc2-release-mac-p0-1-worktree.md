# Self-test control — rc2-release-mac-p0-1-worktree

- tested commit: d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/runner.sh
- patch sha256: a75787aa4ca21d57508d8de14a8dd28eed53fdff570606bd2fcdea81b16f0bb3
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
@@ -208,7 +208,7 @@

 runner_command() {
   # Invoke with_timeout in this shell so signal handling owns the child group.
-  cd "$TREE$SUBDIR" || return 72
+  cd "$WORKDIR" || return 72
   with_timeout "$TIMEOUT" "${RUN_ENV[@]}" ${SANDBOX_ARGS[@]+"${SANDBOX_ARGS[@]}"} /bin/bash --noprofile --norc -o pipefail -c "$1" </dev/null >"$OUTPUT" 2>&1
   COMMAND_STATUS=$?
   cd "$TOP" || return 72

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
# (in test file tests/gate.bats, line 8)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# [gate] exit 1
# FAILED
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/bats-run-9WfceL/test/1/case/evidence/bound.md (tested commit afc5577e1da1fa6866c79dce38db5d6e5804cab3)

```
