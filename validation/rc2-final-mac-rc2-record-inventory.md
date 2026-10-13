# Self-test control — rc2-final-mac-rc2-record-inventory

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/record_scope.py
- patch sha256: 99bbe1b547665b210e57165b68198fb3aa9c1a85d14edf43ef633f0a774d11fc
- baseline exit: 0
- mutant exit: 0
- expected failure signature: ^not ok [0-9]+ record\ inventory\ rejects\ HTML\ and\ JSON.*$
- result: SURVIVED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/record_scope.py
+++ b/scripts/record_scope.py
@@ -52,7 +52,7 @@
                 return 64
             tracked[str(file)] = metadata.split()[2].decode()
         inventory = manifest(git('cat-file', 'blob', tracked['MANIFEST'])) if 'MANIFEST' in tracked else {}
-        if set(tracked) - {'MANIFEST'} != set(inventory):
+        if False:
             return 64
         for name, expected in inventory.items():
             if hashlib.sha256(git('cat-file', 'blob', tracked[name])).hexdigest() != expected:

```
## Baseline
```
1..1
ok 1 record inventory rejects HTML and JSON source but admits registered reports

```
## Mutant
```
1..1
ok 1 record inventory rejects HTML and JSON source but admits registered reports

```
