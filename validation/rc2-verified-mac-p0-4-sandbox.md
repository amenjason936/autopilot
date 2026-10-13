# Self-test control — rc2-verified-mac-p0-4-sandbox

- tested commit: 6c541949053f639064eb187849c746501183b79a
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/policy.py
- patch sha256: 271ea1d4ba97aae5ce6bcb7659cde2679f3c543cffb5aa427ac6854709896348
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ contract\ policy\ forces.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/policy.py
+++ b/scripts/policy.py
@@ -55,7 +55,7 @@
         sandbox = supplied['sandbox']
     if sandbox not in ('env-clean', 'sandbox-exec', 'bwrap'):
         raise ValueError('unknown sandbox')
-    if (network or denied) and sandbox == 'env-clean':
+    if False:
         sandbox = 'sandbox-exec' if platform.system() == 'Darwin' else 'bwrap'
     records = supplied.get('record_paths', {})
     if not isinstance(records, dict) or set(records) - {'evidence_dir', 'run_record'}:

```
## Baseline
```
1..1
ok 1 contract policy forces a strong sandbox even when env-clean requested

```
## Mutant
```
1..1
not ok 1 contract policy forces a strong sandbox even when env-clean requested
# (in test file tests/policy.bats, line 12)
#   `if [ "$(uname -s)" = Darwin ]; then [[ "$output" == *'sandbox: sandbox-exec'* ]]; else [[ "$output" == *'sandbox: bwrap'* ]]; fi' failed
# Last output:
# DRY RUN — commands will not execute
# HEAD: ca32da7112022999711d611008eea32cc1c13aa8
# tested commit: ca32da7112022999711d611008eea32cc1c13aa8
# sandbox: env-clean
# cwd: <temporary-worktree>
# launcher: env -i PATH=<current PATH> HOME=<temporary HOME> TMPDIR=<temporary tmp> bash --noprofile --norc -o pipefail -c <command>
# GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_OPTIONAL_LOCKS=0 LC_ALL=C
# policy: {"record_paths":{},"write_dirs":[],"version":1,"sandbox":"env-clean","deny_network":true,"deny_paths":[],"read_paths":["/usr","/bin","/sbin","/lib","/lib64","/System/Library","/Library/Apple","/private/var/db/dyld","/private/etc","/etc","/dev"],"env":[]}
# env-clean does not restrict filesystem or network access.
# command: true

```
