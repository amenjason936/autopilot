# Self-test control — rc2-linux-p0-2-manifest

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/evidence.py
- patch sha256: d8367e23bcefdf220c399fe77107b9fb2ea05b65bbe1661b5110fed1465e0485
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ manifest\ detects\ tampering.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/evidence.py
+++ b/scripts/evidence.py
@@ -79,7 +79,7 @@
             raise ValueError('missing or empty manifest')
         wanted = sys.argv[3:] or list(known)
         for name in wanted:
-            if name not in known or digest(directory / name) != known[name]:
+            if name not in known:
                 raise ValueError('missing evidence or SHA-256 mismatch')
         print(f'verified: {len(wanted)} evidence file(s)')
     return 0

```
## Baseline
```
1..1
ok 1 manifest detects tampering, missing entries, duplicates, and path traversal

```
## Mutant
```
1..1
not ok 1 manifest detects tampering, missing entries, duplicates, and path traversal
# (in test file tests/gate.bats, line 95)
#   `[ "$status" -eq 1 ]' failed
# [gate] exit 0
# passed
# evidence: /tmp/bats-run-im5OBo/test/1/case/evidence/integrity.md (tested commit 735e5d70096ea0944ddcd0f2f068dcf0d9409a29)
# Last output:
# verified: 1 evidence file(s)

```
