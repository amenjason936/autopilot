# rc.2 independent reliability review — initial freeze

Reviewed code HEAD: `60fb48d3ad15ef256ec71bcb54954050fe113ff8`.
Comparison base: `23ebeedcd41ebcc2682a077549e598e64c9093ce`.
Date: 2026-10-13. Reviewer: fresh-context, same-family delegated reliability reviewer; this is not an external four-party evaluation.

I read REVIEW-CRITERIA.md and raw current scripts, tests, README, SKILL.md, REFERENCE.md and CI configuration. I did not read prior scored REVIEW.md or historical validation-review reports before freezing this assessment. Historical VALIDATION.md was deliberately excluded; the coordinator's ongoing Linux/full-suite results are not represented as my own executions. No candidate code was edited by this reviewer.

## Confirmed defects

### R1 — P2: valid unnumbered TAP output is rejected as no active tests

Location: `scripts/failure_signature.py:12-14`; propagated by `scripts/runner.sh:286-289`.

The activity detector only recognizes `ok` / `not ok` when followed by a numeric test ID. TAP permits an omitted test number, including `ok - actual test` and plain `ok`; see the [official TAP specification](https://testanything.org/tap-specification.html), test-line section and Creative liberties example. A successful test command emitting `TAP version 13\n1..1\nok - actual test\n` therefore returns activity status 2, and the real machine runner exits 1 with FAILED even though the command exits 0. The equivalent numbered stream passes. This is a false negative introduced by applying the new parser to every gate/setup/mutant phase.

Reproduction: generated fixture results at `/private/tmp/rc2-independent-tap-t_n9sx0s/frozen-results.json`; evidence in its `frozen-evidence/unnumbered.md` and `frozen-evidence/numbered.md`. Direct helper reproduction also returned numbered=0, unnumbered=2. Repair: recognize valid unnumbered test lines while preserving skip detection; regression-test positive unnumbered, negative unnumbered skip, and baseline/mutant behavior.

### R2 — P2: plan-free skip-only TAP is accepted as active execution

Location: `scripts/failure_signature.py:11-14`, specifically the `plans and ...` condition.

A recognized TAP stream containing only `TAP version 13\nok 1 - missing platform # SKIP unavailable\n` returns activity status 0 because it has no plan. The real gate publishes passed, and the real mutant runner reports SURVIVED (exit 1), despite neither baseline nor mutant running an active test. The official specification linked above allows an optional plan. This leaves a hole in the intended skip-only detector guard; it is not a claim that the existing Bats invocation omits its plan.

Reproduction: the same retained fixture, `frozen-evidence/no-plan-skip.md` (gate exit 0) and `frozen-evidence/skip-mutant.md` (SURVIVED). Repair: detect TAP activity using recognized test lines/version as well as plans, and keep non-TAP commands usable. Test no-plan active and skip-only cases.

## Verified behavior

Independently ran this subset outside the outer sandbox, using real macOS sandbox-exec:

```
bats --filter 'failed git status|failed output filters|grep I/O|source write and restore|new declared output|applied mutant snapshot|mutant cannot rewrite|skip-only|readonly source' tests/rc2.bats
```

All 9 selected tests passed. This independently demonstrates failure propagation for Git status, tail and grep errors; source write/restore denial in env-clean and strict modes; writable new output directories and source-directory refusal; saved mutant bytes checked against extra edits/reversal; applied mutant source immutability; the covered numbered TAP skip-only/zero-test cases; and hardlink write denial. Existing tests therefore support the intended repairs but do not cover R1/R2.

Static inspection additionally found explicit pipeline error checks, failure-signature classification, evidence/MANIFEST checks, directory locking, separate baseline/mutant worktrees, conservative documentation-only lite eligibility and portability-aware Bash/temp-file helpers. The Linux CI matrix installs bubblewrap and checks live namespaces rather than silently skipping unavailable isolation.

## Unsupported claims / acceptance gaps

- This reviewer did not independently execute Linux/bwrap, the full 66-test suite, all 32 regression mutations or an actual cloud review. Those results must be attached from their current fixed-HEAD runs; they cannot be inferred from my 9-test subset.
- The TAP activity check is a deliberately small detector, not a complete TAP harness. Even after R1/R2, generic guarantees about arbitrary test frameworks or completeness of test execution would need broader contracts/tests.
- The documented process-group limitation for descendants that deliberately escape a macOS session remains real; the documentation correctly requires an external supervisor for that stronger guarantee. It is not silently counted as a passing containment test.
- The manuscript-style run/review/park and landing conditions include reviewer decisions; the scripts do not themselves establish scientific truth, model independence or authority. Hashes demonstrate byte identity, not an authenticated execution attestation. Documentation states these limits appropriately.

## Optional improvements

- Keep a small table-driven activity-parser suite covering supported TAP shapes, instead of only numbered synthetic examples embedded in a full mutant test.
- Broaden process-lifecycle tests with an explicit parent-signal case if this is not already independently demonstrated; normal-exit/timeout cases do not exercise every signal path.
- Preserve an out-of-tree-build example for common tooling, since read-only source intentionally rejects source-local caches and dependency installation.

## Six equally weighted scores

These are scoped engineering judgments for the initial fixed code, not target-driven acceptance and not an external-party score.

| Dimension | Score / 10 | Reason |
|---|---:|---|
| Positioning/value | 9.0 | Clear bounded automation purpose, explicit authority and useful inspectable evidence. |
| Architecture | 8.7 | Shared runner and separated policy/state/evidence helpers; cross-backend and host trust boundaries remain substantial complexity. |
| Documentation/usability | 8.7 | Concrete policy, exits, recovery and trust limits; source-read-only migration imposes real setup burden. |
| Code quality | 8.5 | Defensive error handling improved; R1/R2 show overly narrow ad hoc parsing. |
| Security | 8.5 | Positive real source/strict checks in this scope; broader adversarial containment belongs to the separate security review. |
| Testing/maintenance | 8.4 | Good regression and mutation infrastructure; two independently reproduced activity-boundary gaps remain. |

Equal-weight mean: **8.63/10**. R1/R2 should be resolved and targeted tests repeated before claiming this reliability slice fully accepted. Missing external scoring is an acceptance gap, not a fabricated runtime defect.

Provenance note: candidate repairs began concurrently during the first full-run repro. All four full-run cases were therefore repeated from an immutable `git archive` of 60fb48d at `/private/tmp/rc2-reliability-frozen-60fb48d`; `frozen-results.json` and `frozen-evidence/` are the authoritative initial findings. The live-checkout first repro is retained but is not fixed-HEAD proof.

The same 9-test subset was subsequently rerun from `/private/tmp/rc2-reliability-frozen-60fb48d` after the archive was created: **9/9 passed**. Thus both findings and the selected positive regression results are independently confirmed against immutable original code.
