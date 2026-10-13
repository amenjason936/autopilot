# Mutant — verified-p0-4-conditional-filter

- tested commit: 67289c7d8dcf7fa114b44e843aa795eb147c291e
- HEAD: 67289c7d8dcf7fa114b44e843aa795eb147c291e
- workdir: /private/tmp/autopilot-upgrade-20261013
- sandbox: env-clean
- started: 2026-10-13T04:44:16Z
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
- failure signature: ^not ok [0-9]+ worktree\-conditional\ filters\ cannot\ execute.*$; expected exit: 1
- mutated files: scripts/lib.sh
- patch sha256: 2aca9611855f9f8bdc1fba1848ffa00bba5d4cc653887257aaf38048cb44b7b2

```diff
--- a/scripts/lib.sh
+++ b/scripts/lib.sh
@@ -200,7 +200,7 @@

 safe_worktree_add() {
   disable_git_callbacks "$1"
-  git -C "$1" worktree add --quiet --no-checkout --detach "$2" "$3" || return
+  git -C "$1" worktree add --quiet --detach "$2" "$3" || return
   # includeIf gitdir/worktree config can introduce filters only in the new tree.
   # Discover those BEFORE materializing any tracked file.
   disable_git_callbacks "$2"

```
## baseline (unpatched)

```sh
bats --print-output-on-failure --filter 'worktree-conditional filters cannot execute' tests/gate.bats
```

exit 0; timeout=0

```
1..1
ok 1 worktree-conditional filters cannot execute before sandboxing

```
## mutant (patched)

```sh
bats --print-output-on-failure --filter 'worktree-conditional filters cannot execute' tests/gate.bats
```

exit 1; timeout=0

```
1..1
not ok 1 worktree-conditional filters cannot execute before sandboxing
# (in test file tests/gate.bats, line 180)
#   `[ ! -e "$CASE/conditional-marker" ]' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/autopilot-run.x9GwFM/mutant-tmp/bats-run-b5Guth/test/1/case/evidence/conditional.md (tested commit d9e2bf1434bc967c4f040c4f2ef86fd92bee9018)

```
- finished: 2026-10-13T04:44:18Z
- result: KILLED
