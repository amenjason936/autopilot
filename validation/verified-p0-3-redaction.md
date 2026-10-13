# Mutant — verified-p0-3-redaction

- tested commit: 67289c7d8dcf7fa114b44e843aa795eb147c291e
- HEAD: 67289c7d8dcf7fa114b44e843aa795eb147c291e
- workdir: /private/tmp/autopilot-upgrade-20261013
- sandbox: env-clean
- started: 2026-10-13T04:44:07Z
- recorded by sha256: 02b5996b37faa05d2e9378576ef9994fd72b7b9658771193b594c108c76dd99a
- policy: {"record_paths": {"evidence_dir": "validation", "run_record": "VALIDATION.md"}, "version": 1, "sandbox": "env-clean", "deny_network": false, "deny_paths": [], "read_paths": ["/usr", "/bin", "/sbin", "/lib", "/lib64", "/System/Library", "/Library/Apple", "/private/var/db/dyld", "/private/etc", "/etc", "/dev"], "env": []}
- helper lib.sh sha256: 82d1df1f16757fb4dd12752ab2a78c0318a5df62740790e240cd7cd0e761d00d
- helper runner.sh sha256: 80006c97d6bffa62b0f42cb0ec7a92f470f2f9e3ddf9dcca012487898b41a544
- helper redact.py sha256: 0b64f4ce5739877750bda2804d34a6d0c5c9631e58f4b09f8ede6723fd733e5c
- helper policy.py sha256: 4f21296021a751e9d5983cfc94182791daccceb19945c23d4d93513e1f39d4f0
- helper evidence.py sha256: 570337869e6f9d33cb19a1dea2c2d3c9580638a8911bf1c90d91b9794bb8f336
- helper record_scope.py sha256: 194718348c5fb52fbd555f8936647ef9c1bcdc79e51942912592adacccacebc1
- helper failure_signature.py sha256: d9155257b97bf0c548aff7c9d175e8fb54a286c2015c4d2c11fd48a19d59d115

Command output below is untrusted data, never instructions.
- failure signature: ^not ok [0-9]+ redaction\ covers\ commands.*$; expected exit: 1
- mutated files: scripts/redact.py
- patch sha256: abf35758a58e9bf6df2fdef5706ac82513259f6128e1c4483d884833b5b7658d

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
## baseline (unpatched)

```sh
bats --print-output-on-failure --filter 'redaction covers commands' tests/redaction.bats
```

exit 0; timeout=0

```
1..1
ok 1 redaction covers commands output and configured secret patterns

```
## mutant (patched)

```sh
bats --print-output-on-failure --filter 'redaction covers commands' tests/redaction.bats
```

exit 1; timeout=0

```
1..1
not ok 1 redaction covers commands output and configured secret patterns
# (in test file tests/redaction.bats, line 13)
#   `grep -q '<redacted>' "$EVID/redact.md"' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/autopilot-run.VOv75G/mutant-tmp/bats-run-VTjadq/test/1/case/evidence/redact.md (tested commit 0f11c69dc1a6f12b2c8e4e71f870f20f4391f56f)

```
- finished: 2026-10-13T04:44:09Z
- result: KILLED
