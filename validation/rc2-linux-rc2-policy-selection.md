# Self-test control — rc2-linux-rc2-policy-selection

- tested commit: d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: rc.1 independent finding; author-concretized regression target
- target: scripts/policy.py
- patch sha256: ad086a90fd6a9321eb6a4480f07b65f1930fb1a6d51e93e6f39a6886a6f53848
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ alternate\ policy\ controls\ review\ dispatch.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/policy.py
+++ b/scripts/policy.py
@@ -77,7 +77,7 @@

 def selected_policy(repo, head):
     """One selection rule for gates, reviewer dispatch and resume identity."""
-    path = os.environ.get('GATE_POLICY', 'docs/autopilot-policy.json')
+    path = 'docs/autopilot-policy.json'
     if (not re.fullmatch(r'[A-Za-z0-9_./-]+', path) or path.startswith('/')
             or any(part in ('', '.', '..') for part in path.split('/'))):
         raise ValueError('policy path must be repository relative')

```
## Baseline
```
1..1
ok 1 alternate policy controls review dispatch and frozen request identity

```
## Mutant
```
1..1
not ok 1 alternate policy controls review dispatch and frozen request identity
# (in test file tests/rc2.bats, line 14)
#   `[ "$status" -eq 77 ]' failed
# Last output:
# codex exited 42; log: /tmp/bats-run-SGnB78/test/1/case/blocked.log

```
