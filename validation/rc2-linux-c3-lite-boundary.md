# Self-test control — rc2-linux-c3-lite-boundary

- tested commit: d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent acceptance auditor target; author concretized patch
- target: scripts/lite.py
- patch sha256: aed26f0dfb0266c55dc4f7c00d1f6ec402da86d07c91c365049838fc09309685
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ lite\ exact\ boundary\ permits\ 50.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/lite.py
+++ b/scripts/lite.py
@@ -40,7 +40,7 @@
             return 1
     except (subprocess.CalledProcessError, ValueError):
         return 65
-    eligible = changed <= 50 and data == {'stages': 1, 'network': False, 'publish': False, 'risk': 'documentation-only'}
+    eligible = changed <= 51 and data == {'stages': 1, 'network': False, 'publish': False, 'risk': 'documentation-only'}
     print(f'lite {"eligible" if eligible else "refused"}: {changed} changed lines; landing audit remains mandatory')
     return 0 if eligible else 1


```
## Baseline
```
1..1
ok 1 lite exact boundary permits 50 doc lines and refuses 51

```
## Mutant
```
1..1
not ok 1 lite exact boundary permits 50 doc lines and refuses 51
# (in test file tests/supplements.bats, line 82)
#   `[ "$status" -eq 1 ]' failed
# Last output:
# lite eligible: 51 changed lines; landing audit remains mandatory

```
