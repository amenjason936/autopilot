# Self-test control — rc2-verified-mac-p0-1-worktree

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/runner.sh
- patch sha256: a75787aa4ca21d57508d8de14a8dd28eed53fdff570606bd2fcdea81b16f0bb3
- baseline exit: 0
- mutant exit: 0
- expected failure signature: ^not ok [0-9]+ gate\ runs\ at\ pinned\ commit.*$
- result: SURVIVED

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
ok 1 gate runs at pinned commit inside a separate worktree

```
