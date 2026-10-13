# Self-test control — rc2-linux-c4-portability

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent acceptance auditor target; author concretized patch
- target: scripts/training-ground.sh
- patch sha256: 9356bba66690176d6ed2c857394e2b0eaf77e0d6bcc4f45a9c3f09a977bd9300
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ relocated\ training\ uses\ package\ fixtures.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/training-ground.sh
+++ b/scripts/training-ground.sh
@@ -5,7 +5,7 @@
 # Exit: 0 all expected outcomes; 1 mismatch; 64 usage; 73 destination exists.
 set -euo pipefail
 SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
-SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
+SKILL_DIR="$HOME/.claude/skills/autopilot"
 # shellcheck source=lib.sh
 . "$SCRIPT_DIR/lib.sh"
 require git python3

```
## Baseline
```
1..1
ok 1 relocated training uses package fixtures despite valid legacy decoys

```
## Mutant
```
1..1
not ok 1 relocated training uses package fixtures despite valid legacy decoys
# (in test file tests/supplements.bats, line 145)
#   `[ "$status" -eq 0 ]' failed
# Last output:
# Traceback (most recent call last):
#   File "<stdin>", line 3, in <module>
# AssertionError: ASSERT_PACKAGE_FIXTURE

```
