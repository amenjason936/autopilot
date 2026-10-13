# Mutant — verified-p0-7-partial

- tested commit: 67289c7d8dcf7fa114b44e843aa795eb147c291e
- HEAD: 67289c7d8dcf7fa114b44e843aa795eb147c291e
- workdir: /private/tmp/autopilot-upgrade-20261013
- sandbox: env-clean
- started: 2026-10-13T04:44:25Z
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
- failure signature: ^not ok [0-9]+ partial\ resume\ archives.*$; expected exit: 1
- mutated files: scripts/runner.sh
- patch sha256: c3f5ab7580a2a355c57d04269ec73a320a178b41bc09db4f153d8e96221803e5

```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -131,7 +131,7 @@
   [ ! -e "$PARTIAL" ] || [ -f "$PARTIAL" ] || die 73 'partial must be a regular file'
   if [ -e "$PARTIAL" ]; then
     [ "${GATE_RERUN_POLICY:-}" = safe ] || die 76 'resume parked: interrupted commands need a verified safe rerun policy or receipt review'
-    mv "$PARTIAL" "$PARTIAL.$(date -u +%Y%m%dT%H%M%SZ).$$" || die 70 'cannot archive partial'
+    : >"$PARTIAL" || die 70 'cannot archive partial'
   fi
   WORK="$(make_temp_dir run)" || exit 70
   WORK="$(resolve_path "$WORK")" || exit 70

```
## baseline (unpatched)

```sh
bats --print-output-on-failure --filter 'partial resume archives' tests/gate.bats
```

exit 0; timeout=0

```
1..1
ok 1 partial resume archives old content and never overwrites completed evidence

```
## mutant (patched)

```sh
bats --print-output-on-failure --filter 'partial resume archives' tests/gate.bats
```

exit 1; timeout=0

```
1..1
not ok 1 partial resume archives old content and never overwrites completed evidence
# (in test file tests/gate.bats, line 70)
#   `[ "$output" = 'interrupted payload' ]' failed
# Last output:
# cat: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/autopilot-run.QK9DJi/mutant-tmp/bats-run-zMIBdE/test/1/case/evidence/resume.md.partial.*: No such file or directory

```
- finished: 2026-10-13T04:44:27Z
- result: KILLED
