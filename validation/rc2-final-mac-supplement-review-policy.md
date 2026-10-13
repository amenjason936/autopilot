# Self-test control — rc2-final-mac-supplement-review-policy

- tested commit: 67195db2788a647a666ca1f74c0d82798ddcf87b
- platform: darwin
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent supplemental reviewer target; author concretized patch
- target: scripts/review_identity.py
- patch sha256: a6a52e9fb4f1e6708d74072104d754507dac4667d6f8de4189e576f6f190d1b7
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ restrictive\ policy\ parks\ cloud\ dispatch.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/review_identity.py
+++ b/scripts/review_identity.py
@@ -75,7 +75,7 @@
     elif mode == 'dispatch' and len(sys.argv) == 5:
         repo, head, skill = sys.argv[2:]
         policy = selected_policy(repo, head)['effective']
-        if policy['sandbox'] != 'env-clean' or policy['deny_network'] or policy['deny_paths']:
+        if False:
             return 77
     else:
         return 64

```
## Baseline
```
1..1
ok 1 restrictive policy parks cloud dispatch before invoking the reviewer

```
## Mutant
```
1..1
not ok 1 restrictive policy parks cloud dispatch before invoking the reviewer
# (in test file tests/supplements.bats, line 129)
#   `[ "$status" -eq 77 ]' failed
# Last output:
# codex wrote no findings; log: /private/var/folders/kp/q6xvh38n39x8tw10d5hx_fcr0000gn/T/bats-run-hhlyso/test/1/case/findings.log

```
