# Self-test control — rc2-final-mac-rc2-filter-errors

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/runner.sh
- patch sha256: b79b850c3a907344c88cfbd6ef09ed7e57c244251060fa36a137fb2af6a6f9be
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ failed\ output\ filters\ cannot\ publish.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -307,7 +307,7 @@
       # Redact the WHOLE output before selecting lines: multi-line secrets and
       # undecodable prefixes must not escape because they fell outside the tail.
       clean_output <"$OUTPUT" >"$WORK/clean-output" || exit 70
-      tail -n "$keep" "$WORK/clean-output" || exit 70
+      tail -n "$keep" "$WORK/clean-output"
       if [ -n "${GATE_KEEP_REGEX:-}" ]; then
         grep -anE -- "$GATE_KEEP_REGEX" "$WORK/clean-output" >"$WORK/matches"
         match_status=$?

```
## Baseline
```
1..1
ok 1 failed output filters cannot publish a successful gate

```
## Mutant
```
1..1
not ok 1 failed output filters cannot publish a successful gate
# (in test file tests/rc2.bats, line 59)
#   `[ "$status" -eq 70 ]' failed
# Last output:
# SYNTHETIC_TAIL_IO_ERROR
# [gate] exit 0
# passed
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/bats-run-8AjeJ0/test/1/case/evidence/filter.md (tested commit 64629ffeafb3baa4d7868b83843884d58cf76efa)

```
