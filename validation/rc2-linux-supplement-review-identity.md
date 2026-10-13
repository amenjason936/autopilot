# Self-test control — rc2-linux-supplement-review-identity

- tested commit: d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0
- platform: linux
- harness sha256: af1ca5ed4efaa93c82230daa8b48c6b740f83b759556c8f9d713b24fb8f2f8e7
- selection: independent supplemental reviewer target; author concretized patch
- target: scripts/review_identity.py
- patch sha256: b64127c641f45d535c4b4e11f7ed9dd87e6321a6272bdb0303402dc112624a28
- baseline exit: 0
- mutant exit: 1
- expected failure signature: ^not ok [0-9]+ review\ identity\ rejects\ stale\ head\ scope.*$
- result: KILLED

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
--- a/scripts/review_identity.py
+++ b/scripts/review_identity.py
@@ -68,7 +68,7 @@
         job = json.loads(raw)
         context = inputs(repo, base, head, record, scope, skill)
         receipt = json.loads(regular(findings+'.receipt.json'))
-        if (job['version'] != 1 or job['inputs'] != context or job['input_sha256'] != digest(encoded(context))
+        if False and (job['version'] != 1 or job['inputs'] != context or job['input_sha256'] != digest(encoded(context))
                 or receipt != dict(version=1, job_id=job['job_id'], request_sha256=digest(raw),
                                    findings_sha256=digest(regular(findings)))):
             return 70

```
## Baseline
```
1..1
ok 1 review identity rejects stale head scope and altered findings

```
## Mutant
```
1..1
not ok 1 review identity rejects stale head scope and altered findings
# (in test file tests/supplements.bats, line 111)
#   `[ "$status" -eq 70 ]' failed
# Last output:
# valid: /tmp/bats-run-m9Yhff/test/1/case/findings.json

```
