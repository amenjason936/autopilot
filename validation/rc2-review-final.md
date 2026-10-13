# rc.2 independent final targeted recheck

Final candidate HEAD: **`d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0`**.
Production implementation reviewed and executed: `67195db2788a647a666ca1f74c0d82798ddcf87b`.
I verified `git diff --exit-code 67195db..d9ca7ce -- scripts` succeeds; the changes after the production fix affect only `tests/rc2.bats` and `tests/gate.bats` (12 insertions, 2 deletions). Thus all production helper bytes in my immutable execution archive are identical to the final candidate.
Initial reviewed code HEAD: `60fb48d3ad15ef256ec71bcb54954050fe113ff8`.
Original comparison base: `23ebeedcd41ebcc2682a077549e598e64c9093ce`.
Date: 2026-10-13. Reviewer: same-family agent, fresh-context independent initial review followed by a bounded repair recheck; **not an external four-party review**.

The initial report remains unchanged at `/private/tmp/rc2-reliability-review.md`. This report supersedes its open-finding status and numerical assessment for the final code. I made no candidate code edits. To exclude concurrent evidence updates, all targeted executions used an immutable `git archive` of the production implementation SHA at `/private/tmp/rc2-reliability-frozen-67195db`. Only validation records were changing in the live candidate checkout.

## Result

**Both independently reported TAP defects are fixed. The independently replayed runner-profile overwrite defect is also fixed on the actual macOS backend. No open defect was found within this bounded recheck.** The complete cross-platform results below were executed by the coordinator and independently read by me; they remain separate from my own targeted executions and do not establish an unrestricted security guarantee.

| Item | Initial behavior | Final behavior and evidence | Disposition |
|---|---|---|---|
| R1: valid unnumbered TAP rejected | Successful command became FAILED | `TAP version 13`, plan `1..1`, and `ok - actual test` now pass; plain `ok` also passes the focused regression | Fixed |
| R2: plan-free skip-only TAP accepted | Gate passed; all-skipped mutant became SURVIVED | Numbered and unnumbered plan-free skip-only streams fail the gate; skip-only baseline becomes INCONCLUSIVE/exit 2; active plan-free TAP remains valid | Fixed |
| S1: env-clean command could replace future Seatbelt profile | Profile replaced, subsequent source write/restore succeeded, gate passed | Profile overwrite reports Operation not permitted; subsequent source writes also denied; same exploit returns FAILED/exit 1 | Fixed in tested macOS path; Linux mount change inspected, not personally executed |

R1/R2 code locations: `scripts/failure_signature.py:11-15`, with regression coverage at `tests/rc2.bats:197-211`. Test numbers are optional under the [official TAP specification](https://testanything.org/tap-specification.html); the new matching accepts them with or without numbers and detects TAP from plans, test lines or a version header.

S1 code locations: `scripts/policy.py:98-107` and `scripts/runner.sh:163-171`; regression at `tests/rc2.bats:189-193`. The protection now includes the runner scratch root, helper directory and evidence directory, retaining explicit writable HOME/TMP/output exceptions. Linux env-clean adds read-only bind mounts for the same roots, followed by writable output mounts. Strict-mode behavior remains based on default-deny filesystem access.

The initial security reviewer could not deliver its full written report. I inspected its retained synthetic reproduction at `/private/tmp/rc2-security-repro.EGi51R` and then **independently reproduced old success and new denial** using fresh generated fixtures and immutable old/new code archives. Thus the final security finding disposition does not rely solely on a coordinator's summary. The original exploit prints a misleading RUNNER_PROFILE_REPLACED marker even after write denial because its shell command uses `; echo`; I inspected the actual permission error and subsequent command, not that marker alone.

## Independent execution evidence

Retained direct reproduction: `/private/tmp/rc2-final-recheck-qr3o880q/results.json` and its `evidence/` directory. `verify-evidence.sh` successfully verified all **7** retained records. Their headers contain runner/helper hashes; the tested repository SHA is the generated fixture SHA, while the immutable runner archive is identified above.

Direct cases:

- Original 60fb48d profile-overwrite exploit: exit 0, transient source write succeeded, published passed.
- Final 67195db same exploit: exit 1, profile and source write denial, published FAILED.
- Final planned unnumbered active TAP: exit 0.
- Final plan-free unnumbered active TAP: exit 0.
- Final plan-free numbered skip-only TAP: gate exit 1.
- Final plan-free unnumbered skip-only TAP: gate exit 1.
- Final skip-only mutant baseline: exit 2, INCONCLUSIVE.

Also ran the following against the immutable final archive outside the outer sandbox, using real macOS sandbox-exec:

```
bats --filter 'commands cannot rewrite|valid unnumbered|skip-only TAP without|source write and restore|new declared output' tests/rc2.bats
```

**5/5 passed.** These tests additionally cover scratch policy/snapshot, helper and evidence write denial, post-repair evidence verification, strict/env-clean source protection, writable output directories, source-directory rejection and patched-phase skip-only classification. The original fixed-HEAD reliability subset had independently passed 9/9, as documented in the preserved initial report.

## Self-test harness scope

I inspected the new `tests/run-p0-mutants.py` approach. It now runs Bats directly in separate baseline and patched worktrees, invokes the actual OS backend from those fixtures, matches the expected Bats failure signature, and requires an active green baseline. Its generated report explicitly states at lines 131-134 that this is a host-level synthetic self-test, has no nested outer runner, and is not production adversarial containment or a live model-injection test. This is an accurate scope statement. Its results must be labeled regression controls, not proof of an unmodifiable outer security boundary around arbitrary hostile patches.

## Material limits and unsupported claims

- I did not personally execute the final full macOS/Linux suite or the full control matrix. I inspected the coordinator-produced raw logs and JSON: both hosts report 69 successful tests and zero failures; both have exactly 33/33 KILLED controls, all bound to final HEAD `d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0`. This distinction in execution attribution is retained.
- The TAP helper remains an activity guard, not a complete TAP conformance/plan-count/failure parser, nor a detector for all test frameworks. Reviewed commands and meaningful assertions remain necessary.
- env-clean deliberately permits other host/network access; these fixes protect execution/evidence inputs, not all user resources. Deliberately session-escaping macOS descendants still require the documented external supervisor for a stronger lifetime guarantee.
- Hash manifests establish byte identity at a chosen review head, not authenticated execution or reviewer/model independence. No live prompt-injection evaluation or external four-party consensus was performed here.
- No new optional enhancement is being promoted to a blocker. Remaining limitations should retain their documented scope rather than be turned into blanket guarantees.

## Final six-dimensional assessment

Equal weighting; scores reflect the final candidate and the evidence reviewed, with no required target score. Lack of an external score is an acceptance gap, not itself a runtime defect.

| Dimension | Score / 10 | Basis |
|---|---:|---|
| Positioning/value | 9.0 | Bounded automation has clear authority, evidence and run/review/park outcomes. |
| Architecture | 8.8 | Shared execution and evidence helpers now protect their own control inputs; OS-specific sandbox complexity remains substantial. |
| Documentation/usability | 8.7 | Concrete policy, recovery, host-level control scope and trust limitations; read-only builds require deliberate setup/output configuration. |
| Code quality | 8.8 | Both reproduced parser defects and the control-file protection issue are repaired with focused regressions. |
| Security | 8.8 | Independent old/new exploit replay proves the macOS repair; reviewed real Linux/bwrap evidence adds backend coverage; env-clean/process limits and broader attacks still constrain stronger claims. |
| Testing/maintenance | 9.0 | Independently exercised boundary repairs plus inspected final 69-test and 33-control results on each backend; discovered detector gaps were corrected and rerun. |

Equal-weight mean: **8.85/10**. The targeted fixes are accepted in this review. The material limitations above remain explicit; this report does not assert overall four-party acceptance or a mean score of 9.

The final tests-only refinement isolates two redundant protections: TOP-only Git status injection avoids a second TREE status check masking the mutation, and a valid live MANIFEST with no pinned inventory isolates the committed-inventory check. I inspected both changes. The earlier two SURVIVED controls were therefore test sensitivity findings, not independently established product defects; the final 33/33 KILLED reruns now close those controls.

The last tests-only commit also compares the fixture repository using `pwd -P` in the worktree-binding test. This prevents macOS `/var` versus `/private/var` aliases from making an incorrect original-checkout cwd appear different. I inspected the change and verified again that production scripts are byte-identical to the independently executed 67195db implementation.

## Final cross-platform evidence read before freeze

Final candidate `d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0`:

| Check | macOS | Linux | Attribution |
|---|---|---|---|
| Full make check | 69 successful test lines, 0 failures; coordinator reports lint/syntax success | 69 successful test lines, 0 failures; coordinator reports lint/syntax success | Coordinator executions; raw logs independently read here |
| Regression controls | 33/33 KILLED, each JSON entry bound to final HEAD | 33/33 KILLED, each JSON entry bound to final HEAD | Coordinator executions; JSON independently counted and heads checked here |
| Training | Coordinator reports TRAINING PASSED and 7 records verified | TRAINING PASSED and 7 records verified visible in inspected log | macOS completion reported by coordinator; Linux raw training log read here |

Inspected paths:

- `/private/tmp/rc2-final4-check-mac.log`
- `/private/tmp/autopilot-rc2-release-mac-controls-20261013/results.json`
- `/private/tmp/autopilot-rc2-linux-final-proof/make-check.log`
- `/private/tmp/autopilot-rc2-linux-final-proof/controls/results.json`
- `/private/tmp/autopilot-rc2-linux-final-proof/tested-head.txt`
- `/private/tmp/autopilot-rc2-linux-final-proof/runtime.txt`
- `/private/tmp/autopilot-rc2-linux-final-proof/training.log`

Linux runtime evidence identifies Linux aarch64, Bash 5.2.21, Python 3.12.3, Bats 1.10.0, ShellCheck 0.9.0 and bubblewrap 0.9.0. These are real Linux backend results, not a macOS imitation. No additional product-code change occurred after my independent production recheck. Final report frozen after these evidence reads; no further audit scope is implied.
