# Self-test control — rc2-linux-rc2-record-inventory

- tested commit: d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/record_scope.py
- patch sha256: 99bbe1b547665b210e57165b68198fb3aa9c1a85d14edf43ef633f0a774d11fc
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ record\ inventory\ rejects\ HTML\ and\ JSON.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/record_scope.py
+++ b/scripts/record_scope.py
@@ -52,7 +52,7 @@
                 return 64
             tracked[str(file)] = metadata.split()[2].decode()
         inventory = manifest(git('cat-file', 'blob', tracked['MANIFEST'])) if 'MANIFEST' in tracked else {}
-        if set(tracked) - {'MANIFEST'} != set(inventory):
+        if False:
             return 64
         for name, expected in inventory.items():
             if hashlib.sha256(git('cat-file', 'blob', tracked[name])).hexdigest() != expected:

```
## Baseline
```
1..1
ok 1 record inventory rejects HTML and JSON source but admits registered reports

```
## Mutant
```
1..1
not ok 1 record inventory rejects HTML and JSON source but admits registered reports
# (in test file tests/rc2.bats, line 117)
#   `[ "$status" -eq 64 ]' failed
# Last output:
# DRY RUN — commands will not execute
# HEAD: 7a86a02d4c2747ddd112bc02fd1df6353b83ecbb
# tested commit: 7a86a02d4c2747ddd112bc02fd1df6353b83ecbb
# sandbox: env-clean
# cwd: <temporary-worktree>
# launcher: env -i PATH=<current PATH> HOME=<temporary HOME> TMPDIR=<temporary tmp> bash --noprofile --norc -o pipefail -c <command>
# GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_OPTIONAL_LOCKS=0 LC_ALL=C
# policy: {"record_paths":{"evidence_dir":"web"},"write_dirs":[],"version":1,"sandbox":"env-clean","deny_network":false,"deny_paths":[],"read_paths":["/usr","/usr/bin","/bin","/usr/sbin","/sbin","/usr/lib","/lib","/lib64","/System/Library","/Library/Apple","/private/var/db/dyld","/private/etc","/etc","/dev"],"env":[]}
# env-clean does not restrict filesystem or network access.
# command: true

```
