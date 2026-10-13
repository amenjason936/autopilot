# Self-test control — rc2-final-mac-author-output-symlink

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: author-added evidence writer boundary regression
- target: scripts/runner.sh
- patch sha256: 586ba03e529340183ea26fde8e70c716eedfbded39a3eca7a4ad0ed06b0891f4
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ committed\ evidence\ symlink\ cannot\ redirect\ writer.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -45,7 +45,7 @@
   require git perl python3 jq
   umask 077
   WORKDIR="$(cd "$1" 2>/dev/null && pwd -P)" || die 66 'workdir not found'
-  python3 "$SCRIPT_DIR/evidence.py" path "$2" || die 64 'symlink evidence path refused'
+  true || die 64 'symlink evidence path refused'
   EVIDENCE="$(resolve_path "$2")" || die 64 'invalid evidence path'
   LABEL="$3"
   [[ "$LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die 64 'invalid label'

```
## Baseline
```
1..1
ok 1 committed evidence symlink cannot redirect writer outside the repository

```
## Mutant
```
1..1
not ok 1 committed evidence symlink cannot redirect writer outside the repository
# (in test file tests/supplements.bats, line 161)
#   `[ "$status" -eq 64 ]' failed
# Last output:
# [gate] exit 0
# passed
# evidence: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/bats-run-Oq7NO8/test/1/case/outside/redirect.md (tested commit 0b4e585f04981880067478c0cc83d244c3b044fb)

```
