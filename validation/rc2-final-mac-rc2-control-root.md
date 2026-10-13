# Self-test control — rc2-final-mac-rc2-control-root

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/policy.py
- patch sha256: e2b50fe664dd93c5c5d112ef0dd801abb16eb55b2a0845418ba7e9fe8fd8a775
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ commands\ cannot\ rewrite\ runner\ controls.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/policy.py
+++ b/scripts/policy.py
@@ -102,7 +102,7 @@
         # Environment-only mode still pins execution inputs. It retains host
         # access outside the protected source/Git roots; it is not full isolation.
         lines = ['(version 1)', '(allow default)']
-        for root in (tree, source, gitdir, work, helpers, evidence):
+        for root in (tree, source, gitdir):
             exceptions = ''.join(f' (require-not (subpath {quote(p)}))' for p in writable if p.startswith(root + '/'))
             lines.append(f'(deny file-write* (require-all (subpath {quote(root)}){exceptions}))')
         return '\n'.join(lines) + '\n'

```
## Baseline
```
1..1
ok 1 commands cannot rewrite runner controls helpers or evidence

```
## Mutant
```
1..1
not ok 1 commands cannot rewrite runner controls helpers or evidence
# (in test file tests/rc2.bats, line 191)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# [gate] exit 1
# [gate] exit 65
# [gate] exit 65
# [gate] exit 65
# FAILED
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/bats-run-IkRPRJ/test/1/case/evidence/controls.md (tested commit 42bd2d58a2a15825d9464a46f9ba413326ec8b44)

```
