# Self-test control — rc2-final-mac-rc2-source-readonly

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/policy.py
- patch sha256: 09388813b8ae94a3334dd9a8af1d635ac3d55171035a732eab08ce0fe3fc176e
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ source\ write\ and\ restore\ is\ prevented.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/policy.py
+++ b/scripts/policy.py
@@ -104,7 +104,7 @@
         lines = ['(version 1)', '(allow default)']
         for root in (tree, source, gitdir, work, helpers, evidence):
             exceptions = ''.join(f' (require-not (subpath {quote(p)}))' for p in writable if p.startswith(root + '/'))
-            lines.append(f'(deny file-write* (require-all (subpath {quote(root)}){exceptions}))')
+            pass
         return '\n'.join(lines) + '\n'
     lines = ['(version 1)', '(deny default)', '(allow process*)',
              '(allow signal (target self))', '(allow sysctl-read)', '(allow mach-lookup)',

```
## Baseline
```
1..1
ok 1 source write and restore is prevented in env-clean and strict modes

```
## Mutant
```
1..1
not ok 1 source write and restore is prevented in env-clean and strict modes
# (in test file tests/rc2.bats, line 133)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# FAILED: sandbox preflight (red line)
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/bats-run-G5JgiW/test/1/case/evidence/plain.md (tested commit 7da23dc8fd266a8ddfe28399c81a21fb4c49fd70)

```
