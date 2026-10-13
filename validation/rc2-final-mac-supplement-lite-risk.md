# Self-test control — rc2-final-mac-supplement-lite-risk

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent supplemental reviewer target; author concretized patch
- target: scripts/lite.py
- patch sha256: a0d9bde5a88b00e8570438a60e01681a3ecfc2c074f898bc127038959badf55f
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ lite\ refuses\ one\-line\ runtime\ and\ safety\ instruction\ edits.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/lite.py
+++ b/scripts/lite.py
@@ -25,7 +25,7 @@
             # Conservative, deterministic eligibility. Runtime edits need full
             # review even when a one-line change looks harmless to its author.
             path = name.decode('utf-8').lower()
-            if (not path.endswith(('.md', '.rst')) or
+            if False and (not path.endswith(('.md', '.rst')) or
                     any(part in path for part in ('skill.md', 'agents.md', 'brief', 'policy', 'contract',
                                                   'auth', 'security', 'migration', 'lockfile', '.github/'))):
                 print('lite refused: executable or safety-sensitive change')

```
## Baseline
```
1..1
ok 1 lite refuses one-line runtime and safety instruction edits

```
## Mutant
```
1..1
not ok 1 lite refuses one-line runtime and safety instruction edits
# (in test file tests/supplements.bats, line 91)
#   `[ "$status" -eq 1 ]' failed
# Last output:
# lite eligible: 1 changed lines; landing audit remains mandatory

```
