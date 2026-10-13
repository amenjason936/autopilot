# Self-test control — rc2-verified-mac-p0-4-git-callback

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/lib.sh
- patch sha256: 95c0a0c917ec20207c14f87f0276549d33d3ac6555805c6fbf22a5f778612863
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ dry\-run\ never\ executes\ repository\ fsmonitor.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
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
## Baseline
```
1..1
ok 1 dry-run never executes repository fsmonitor callbacks

```
## Mutant
```
1..1
not ok 1 dry-run never executes repository fsmonitor callbacks
# (in test file tests/gate.bats, line 149)
#   `[ ! -e "$CASE/fsmonitor-marker" ]' failed
# Last output:
# DRY RUN — commands will not execute
# HEAD: 1673dd0fbb353faeef8982950f5c4b3a530e27a3
# tested commit: 1673dd0fbb353faeef8982950f5c4b3a530e27a3
# sandbox: env-clean
# cwd: <temporary-worktree>
# launcher: env -i PATH=<current PATH> HOME=<temporary HOME> TMPDIR=<temporary tmp> bash --noprofile --norc -o pipefail -c <command>
# GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_OPTIONAL_LOCKS=0 LC_ALL=C
# policy: {"record_paths":{},"write_dirs":[],"version":1,"sandbox":"env-clean","deny_network":false,"deny_paths":[],"read_paths":["/usr","/bin","/sbin","/lib","/lib64","/System/Library","/Library/Apple","/private/var/db/dyld","/private/etc","/etc","/dev"],"env":[]}
# env-clean does not restrict filesystem or network access.
# command: true

```
