# Self-test control — rc2-verified-mac-p0-3-redaction

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/redact.py
- patch sha256: abf35758a58e9bf6df2fdef5706ac82513259f6128e1c4483d884833b5b7658d
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ redaction\ covers\ commands.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/redact.py
+++ b/scripts/redact.py
@@ -33,7 +33,7 @@
     chunks = re.split(r'(\\[nrt])', text)
     for index in range(0, len(chunks), 2):
         for pattern in compiled:
-            chunks[index] = pattern.sub('<redacted>', chunks[index])
+            chunks[index] = pattern.sub(lambda match: match.group(0), chunks[index])
     text = ''.join(chunks)
     return '\n'.join(line.rstrip() for line in text.splitlines()) + '\n'


```
## Baseline
```
1..1
ok 1 redaction covers commands output and configured secret patterns

```
## Mutant
```
1..1
not ok 1 redaction covers commands output and configured secret patterns
# (in test file tests/redaction.bats, line 13)
#   `grep -q '<redacted>' "$EVID/redact.md"' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/bats-run-U9Npzu/test/1/case/evidence/redact.md (tested commit d4b9a8d7dc994638a406e523961128feb6db3b9c)

```
