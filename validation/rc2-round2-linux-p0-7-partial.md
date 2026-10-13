# Self-test control — rc2-linux-p0-7-partial

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent forward-test reviewer; author concretized patch
- target: scripts/runner.sh
- patch sha256: 49088d467c685030a6e4ceaa89cf50a42b5d6fcb20865b23b61e441ac5182c8f
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ partial\ resume\ archives.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/runner.sh
+++ b/scripts/runner.sh
@@ -124,7 +124,7 @@
   [ ! -e "$PARTIAL" ] || [ -f "$PARTIAL" ] || die 73 'partial must be a regular file'
   if [ -e "$PARTIAL" ]; then
     [ "${GATE_RERUN_POLICY:-}" = safe ] || die 76 'resume parked: interrupted commands need a verified safe rerun policy or receipt review'
-    mv "$PARTIAL" "$PARTIAL.$(date -u +%Y%m%dT%H%M%SZ).$$" || die 70 'cannot archive partial'
+    : >"$PARTIAL" || die 70 'cannot archive partial'
   fi
   WORK="$(make_temp_dir run)" || exit 70
   WORK="$(resolve_path "$WORK")" || exit 70

```
## Baseline
```
1..1
ok 1 partial resume archives old content and never overwrites completed evidence

```
## Mutant
```
1..1
not ok 1 partial resume archives old content and never overwrites completed evidence
# (in test file tests/gate.bats, line 70)
#   `[ "$output" = 'interrupted payload' ]' failed
# Last output:
# cat: '/tmp/bats-run-ZKohyq/test/1/case/evidence/resume.md.partial.*': No such file or directory

```
