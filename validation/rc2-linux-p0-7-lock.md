# Self-test control — rc2-linux-p0-7-lock

- tested commit: d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/runner.sh
- patch sha256: 46d85d7457510c8de8f6d5d98aa731033000f85c0606637b769acbabf315c632
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ directory\ lock\ rejects.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -113,7 +113,7 @@

 runner_lock() {
   mkdir -p "$EVIDENCE_DIR" || die 70 'cannot create evidence directory'
-  mkdir "$EVIDENCE_DIR/.autopilot.lock" 2>/dev/null || die 73 'evidence directory locked; inspect owner before recovering a stale lock'
+  mkdir "$EVIDENCE_DIR/.autopilot.lock" 2>/dev/null || true
   LOCKED=1
   trap runner_cleanup EXIT
   printf 'pid=%s\nlabel=%s\nstarted=%s\n' "$$" "$LABEL" "$(date -u +%FT%TZ)" >"$EVIDENCE_DIR/.autopilot.lock/owner" || die 70 'cannot record lock ownership'

```
## Baseline
```
1..1
ok 1 directory lock rejects concurrent run before executing commands

```
## Mutant
```
1..1
not ok 1 directory lock rejects concurrent run before executing commands
# (in test file tests/gate.bats, line 79)
#   `[ "$status" -eq 73 ]' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /tmp/bats-run-rRbjkz/test/1/case/evidence/locked.md (tested commit 0ad21037a7d4652636c3fc322c26d6d41814e2d6)

```
