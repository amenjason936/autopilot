# Self-test control — rc2-linux-rc2-skip-only

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/failure_signature.py
- patch sha256: 429d6000f530edb1810cc715a6aa59bcc8e3bb774b2a62e92c5baaec53bf1e65
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ skip\-only\ and\ zero\-test\ TAP\ detectors.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/failure_signature.py
+++ b/scripts/failure_signature.py
@@ -12,7 +12,7 @@
         cases = re.findall(r'^(?:not )?ok(?:[ \t]+[^\n]*)?$', text, re.M)
         active = [row for row in cases if not re.search(r'#\s*skip\b', row, re.I)]
         tap = bool(plans or cases or re.search(r'^TAP version [0-9]+$', text, re.M))
-        return 2 if tap and (not active or any(int(p) == 0 for p in plans)) else 0
+        return 0
     mode, expression = sys.argv[1:3]
     pattern = re.compile(expression, re.M)
     if not expression or pattern.search(''):

```
## Baseline
```
1..1
ok 1 skip-only and zero-test TAP detectors are inconclusive rather than survived

```
## Mutant
```
1..1
not ok 1 skip-only and zero-test TAP detectors are inconclusive rather than survived
# (in test file tests/rc2.bats, line 177)
#   `[ "$status" -eq 2 ]' failed
# Last output:
# [baseline (unpatched)] exit 0
# [mutant (patched)] exit 0
# SURVIVED
# evidence: /tmp/bats-run-nzcVh0/test/1/case/evidence/skip.md (tested commit 41ada3d32e65a09e261e451a5cd99b3b14347b0d)

```
