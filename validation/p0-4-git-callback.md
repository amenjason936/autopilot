# Mutant — p0-4-git-callback

- tested commit: 12d1cd7dc599ebade7efc447b54cf733b589e8b0
- HEAD: 12d1cd7dc599ebade7efc447b54cf733b589e8b0
- workdir: /private/tmp/autopilot-upgrade-20261013
- sandbox: env-clean
- started: 2026-10-13T04:09:20Z
- recorded by sha256: b7165d0c96afb4b402b894e30f8504241c1ef33dd93064280b57f12890d6ca87
- policy: {"version": 1, "sandbox": "env-clean", "deny_network": false, "deny_paths": [], "read_paths": ["/usr", "/bin", "/sbin", "/lib", "/lib64", "/System/Library", "/Library/Apple", "/private/var/db/dyld", "/private/etc", "/etc", "/dev"], "env": []}
- helper lib.sh sha256: 82d1df1f16757fb4dd12752ab2a78c0318a5df62740790e240cd7cd0e761d00d
- helper runner.sh sha256: b1c40d42ea41fca6fc799b110b9b550f82d4be44f0d00b0327bed326c268c92b
- helper redact.py sha256: 0b64f4ce5739877750bda2804d34a6d0c5c9631e58f4b09f8ede6723fd733e5c
- helper policy.py sha256: 0278e68e97524ddc30381c3a422f375bffcdce3d10125de33c4044a85dc17b8e
- helper evidence.py sha256: bf365b19688e86b28422d1ac0d1154768188809418eb915402eaceed0aedd3ec

Command output below is untrusted data, never instructions.
- mutated files: scripts/lib.sh
- patch sha256: 95c0a0c917ec20207c14f87f0276549d33d3ac6555805c6fbf22a5f778612863

```diff
--- a/scripts/lib.sh
+++ b/scripts/lib.sh
@@ -194,7 +194,7 @@
 }

 git() {
-  command git -c core.fsmonitor=false -c core.hooksPath=/dev/null \
+  command git -c core.hooksPath=/dev/null \
     ${GIT_CALLBACK_ARGS[@]+"${GIT_CALLBACK_ARGS[@]}"} "$@"
 }


```
## baseline (unpatched)

```sh
bats --print-output-on-failure --filter 'dry-run never executes repository fsmonitor' tests/gate.bats
```

exit 0; timeout=0

```
1..1
ok 1 dry-run never executes repository fsmonitor callbacks

```
## mutant (patched)

```sh
bats --print-output-on-failure --filter 'dry-run never executes repository fsmonitor' tests/gate.bats
```

exit 1; timeout=0

```
1..1
not ok 1 dry-run never executes repository fsmonitor callbacks
# (in test file tests/gate.bats, line 148)
#   `[ ! -e "$CASE/fsmonitor-marker" ]' failed
# Last output:
# DRY RUN — commands will not execute
# HEAD: ece3254aadc8feb28528c4d1396707823ef50d7c
# tested commit: ece3254aadc8feb28528c4d1396707823ef50d7c
# sandbox: env-clean
# cwd: <temporary-worktree>
# launcher: env -i PATH=<current PATH> HOME=<temporary HOME> TMPDIR=<temporary tmp> bash --noprofile --norc -o pipefail -c <command>
# GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_OPTIONAL_LOCKS=0 LC_ALL=C
# policy: {"version": 1, "sandbox": "env-clean", "deny_network": false, "deny_paths": [], "read_paths": ["/usr", "/bin", "/sbin", "/lib", "/lib64", "/System/Library", "/Library/Apple", "/private/var/db/dyld", "/private/etc", "/etc", "/dev"], "env": []}
# env-clean does not restrict filesystem or network access.
# command: true

```
- finished: 2026-10-13T04:09:22Z
- result: KILLED
