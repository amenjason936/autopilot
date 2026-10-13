# Self-test control — rc2-linux-c3-diff-only

- tested commit: d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent acceptance auditor target; author concretized patch
- target: scripts/suggest_mutants.py
- patch sha256: 946307a113606308d563111365f0e7cbeecc2a907d9f918ec03f312600a5a4ca
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ mutant\ suggestions\ touch\ only\ added\ diff\ lines.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/suggest_mutants.py
+++ b/scripts/suggest_mutants.py
@@ -79,7 +79,7 @@
                     current += 1
                 elif current is not None and line.startswith(' '):
                     current += 1
-            for number in sorted(touched):
+            for number in range(1, len(lines) + 1):
                 for kind, replacement in variants(lines[number - 1], file.endswith('.py')):
                     mutant = lines.copy()
                     mutant[number - 1] = replacement

```
## Baseline
```
1..1
ok 1 mutant suggestions touch only added diff lines and produce applicable patches

```
## Mutant
```
1..1
not ok 1 mutant suggestions touch only added diff lines and produce applicable patches
# (in test file tests/methods.bats, line 44)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# Traceback (most recent call last):
#   File "<string>", line 1, in <module>
# AssertionError

```
