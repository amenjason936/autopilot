# Self-test control — rc2-linux-p0-6-output-data

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: author-added script data control; model-level target unverified
- target: scripts/runner.sh
- patch sha256: eb7c168dedd7194ea3f0ba8f597bf668c83443029b536bdeb5d5d1b54e53cbdb
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ untrusted\ output\ is\ recorded.*$
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
+      /bin/bash "$WORK/clean-output"; tail -n "$keep" "$WORK/clean-output" || exit 70
       if [ -n "${GATE_KEEP_REGEX:-}" ]; then
         grep -anE -- "$GATE_KEEP_REGEX" "$WORK/clean-output" >"$WORK/matches"
         match_status=$?

```
## Baseline
```
1..1
ok 1 untrusted output is recorded without executing embedded commands

```
## Mutant
```
1..1
not ok 1 untrusted output is recorded without executing embedded commands
# (in test file tests/gate.bats, line 123)
#   `[ ! -e "$CASE/injected" ]' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /tmp/bats-run-aRMfJK/test/1/case/evidence/injection.md (tested commit 34f5aa14f08915572356616c22a68243e88ce388)

```
