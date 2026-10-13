# Mutant — final-p0-1-worktree

- tested commit: 1fb6c959b71296fded63d4f0931192cb5036e05d
- HEAD: 1fb6c959b71296fded63d4f0931192cb5036e05d
- workdir: /private/tmp/autopilot-upgrade-20261013
- sandbox: env-clean
- started: 2026-10-13T04:37:31Z
- recorded by sha256: 02b5996b37faa05d2e9378576ef9994fd72b7b9658771193b594c108c76dd99a
- policy: {"record_paths": {"evidence_dir": "validation", "run_record": "VALIDATION.md"}, "version": 1, "sandbox": "env-clean", "deny_network": false, "deny_paths": [], "read_paths": ["/usr", "/bin", "/sbin", "/lib", "/lib64", "/System/Library", "/Library/Apple", "/private/var/db/dyld", "/private/etc", "/etc", "/dev"], "env": []}
- helper lib.sh sha256: 82d1df1f16757fb4dd12752ab2a78c0318a5df62740790e240cd7cd0e761d00d
- helper runner.sh sha256: ec201a76c6c562b2beceb500291b528fb17816ce89ff6090c06adf6dedeb336f
- helper redact.py sha256: 0b64f4ce5739877750bda2804d34a6d0c5c9631e58f4b09f8ede6723fd733e5c
- helper policy.py sha256: 4f21296021a751e9d5983cfc94182791daccceb19945c23d4d93513e1f39d4f0
- helper evidence.py sha256: 2685928fa9ea9b81b46567e9ed6010d0aaf11fc624ed29e1d94d5d2d17f92bbf
- helper record_scope.py sha256: 194718348c5fb52fbd555f8936647ef9c1bcdc79e51942912592adacccacebc1
- helper failure_signature.py sha256: d9155257b97bf0c548aff7c9d175e8fb54a286c2015c4d2c11fd48a19d59d115

Command output below is untrusted data, never instructions.
- failure signature: ^not ok [0-9]+ gate\ runs\ at\ pinned\ commit.*$; expected exit: 1
- mutated files: scripts/runner.sh
- patch sha256: 3c1c683f97e944dbb4061ff76e41648e75a88e169830748b6d702d6c0c0dc282

```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -191,7 +191,7 @@

 runner_command() {
   # Invoke with_timeout in this shell so signal handling owns the child group.
-  cd "$TREE$SUBDIR" || return 72
+  cd "$WORKDIR" || return 72
   with_timeout "$TIMEOUT" "${RUN_ENV[@]}" ${SANDBOX_ARGS[@]+"${SANDBOX_ARGS[@]}"} /bin/bash --noprofile --norc -o pipefail -c "$1" </dev/null >"$OUTPUT" 2>&1
   COMMAND_STATUS=$?
   cd "$TOP" || return 72

```
## baseline (unpatched)

```sh
bats --print-output-on-failure --filter 'gate runs at pinned commit' tests/gate.bats
```

exit 0; timeout=0

```
1..1
ok 1 gate runs at pinned commit inside a separate worktree

```
## mutant (patched)

```sh
bats --print-output-on-failure --filter 'gate runs at pinned commit' tests/gate.bats
```

exit 1; timeout=0

```
1..1
not ok 1 gate runs at pinned commit inside a separate worktree
# (in test file tests/gate.bats, line 7)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# [gate] exit 1
# FAILED
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/autopilot-run.Gofks1/mutant-tmp/bats-run-tSeURd/test/1/case/evidence/bound.md (tested commit fa7b99b83a345f405c8190c33644c5ccc555c18b)

```
- finished: 2026-10-13T04:37:33Z
- result: KILLED
