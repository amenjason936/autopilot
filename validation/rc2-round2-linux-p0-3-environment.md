# Self-test control — rc2-linux-p0-3-environment

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/policy.py
- patch sha256: e1349bf6ecc0ec8e0511756ba4ecb69032080a1100e562c17b853709a463ae9f
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ secret\ and\ injection\ environment.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/policy.py
+++ b/scripts/policy.py
@@ -46,7 +46,7 @@
     names = list(dict.fromkeys(names + os.environ.get('GATE_ENV', '').split()))
     for name in names:
         upper = name.upper()
-        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name) or re.search(r'KEY|TOKEN|SECRET|PASSWORD', upper):
+        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name) or False:
             raise ValueError('secret or invalid environment variable name refused')
         if upper in RESERVED or upper.startswith(('LD_', 'DYLD_', 'GIT_', 'BASH_FUNC_')):
             raise ValueError('runtime injection environment variable refused')

```
## Baseline
```
1..1
ok 1 secret and injection environment names are refused

```
## Mutant
```
1..1
not ok 1 secret and injection environment names are refused
# (in test file tests/gate.bats, line 51)
#   `[ "$status" -eq 64 ]' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /tmp/bats-run-qhg4HA/test/1/case/evidence/denied.md (tested commit f10673ce4c41d89cfe008b3cb8c23497864741af)

```
