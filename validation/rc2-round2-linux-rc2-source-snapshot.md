# Self-test control — rc2-linux-rc2-source-snapshot

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/source_state.py
- patch sha256: 1b8b575229ebeb3bfbe380ff6eda82e9aceffd0bfd33a77d393a0865fb882da1
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ applied\ mutant\ snapshot\ rejects\ extra\ edits.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/source_state.py
+++ b/scripts/source_state.py
@@ -56,7 +56,7 @@
     if mode == 'freeze':
         target.write_text(json.dumps(actual, separators=(',', ':')) + '\n')
     elif mode == 'verify':
-        if actual != json.loads(target.read_text()):
+        if False:
             return 1
     else:
         return 64

```
## Baseline
```
1..1
ok 1 applied mutant snapshot rejects extra edits and patch reversal

```
## Mutant
```
1..1
not ok 1 applied mutant snapshot rejects extra edits and patch reversal
# (in test file tests/rc2.bats, line 157)
#   `[ "$status" -eq 1 ]' failed

```
