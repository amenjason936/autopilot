# v0.2.0-rc.2 repair and independent re-evaluation

Base: v0.2.0-rc.1 / 23ebeedcd41ebcc2682a077549e598e64c9093ce.
Source requirements: optimization-plan.md and rc1-independent-review-20261013/REVIEW.md.
Authorized scope: implement F1–F7/G1, regressions, local rc.2 release candidate and independent re-score. No global installation or remote publication.

1. Freeze requirements and inspect existing behavior — complete.
2. Repair policy identity, execution/source boundaries, evidence and admission — complete. Initial 66 tests passed on macOS and real Ubuntu/bubblewrap; independent review added runner-control integrity and TAP cases (69 tests).
3. Run regression/negative controls and platform validation; freeze candidate — execution status and tested SHA tracked in VALIDATION.md, stage 3.
4. Fresh independent review, resolve confirmed findings and re-score — findings and final status tracked in VALIDATION.md, stage 4.
5. Archive evidence, tag v0.2.0-rc.2 and deliver to original repo — completion tracked in VALIDATION.md, stage 5.

The record-only VALIDATION.md is the live stage tracker so updating completion
status does not change the frozen implementation under evaluation.

Do not invent a 9/10 rating or four-party approval. Real platform/model results must be distinguished from simulations and unavailable environments. Preserve original user files and rc.1 tag.
