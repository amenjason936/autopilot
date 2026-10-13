# v0.2.0-rc.2 repair and independent re-evaluation

Historical implementation and validation records are retained on the
[archive branch](https://github.com/luwill/autopilot/tree/archive/rc2-full-evidence-20261013). References below to VALIDATION.md and validation/ describe that archived run, not files shipped in the current tree.

Base: v0.2.0-rc.1 / 23ebeedcd41ebcc2682a077549e598e64c9093ce.
Source requirements: optimization-plan.md and rc1-independent-review-20261013/REVIEW.md.
Authorized scope: implement F1–F7/G1, regressions, local rc.2 release candidate and independent re-score. No global installation or remote publication.

1. Freeze requirements and inspect existing behavior — complete.
2. Repair policy identity, execution/source boundaries, evidence and admission — complete. Initial 66 tests passed on macOS and real Ubuntu/bubblewrap; independent review added runner-control integrity and TAP cases (69 tests).
3. Run regression/negative controls and platform validation; freeze candidate — execution status and tested SHA tracked in VALIDATION.md, stage 3.
4. Fresh independent review, resolve confirmed findings and re-score — findings and final status tracked in VALIDATION.md, stage 4.
5. Archive evidence, tag v0.2.0-rc.2 and deliver to original repo — completion tracked in VALIDATION.md, stage 5.

The archived record-only VALIDATION.md was the stage tracker so updating completion
status does not change the frozen implementation under evaluation.

Do not invent a 9/10 rating or four-party approval. Real platform/model results must be distinguished from simulations and unavailable environments. Preserve original user files and rc.1 tag.

## Multi-host installation and upstream delivery

1. Inspect active host paths, current copies and upstream permissions — complete.
2. Add full-package installer, explicit ccmr target and rollback receipts — complete.
3. Validate installer and replace all four authorized global installations — five focused installer tests pass; full-suite and installation receipts track completion.
4. Publish a fork branch and pull request to the upstream repository — use the existing upstream README concepts with current portable paths; publish after verified installation.

This follow-up is explicitly authorized by the user, including global replacement
and GitHub publication. Backups preserve previous folders and symlink targets;
no unrelated settings, credentials, skills or host launchers are changed.

## Maintainer review response (2026-10-13)

1. Reproduce author feedback and preserve submitted evidence — complete; original tree retained on archive/rc2-full-evidence-20261013.
2. Restore portable env-clean, manual invocation, safe preflight retry and explicit review scopes — complete.
3. Document dependency migration and snapshot-only review; narrow installation payload — complete. The user approved removal of the 300 historical evidence/license files; their bytes were verified against the archive commit and a separate local backup before removal.
4. Regress on macOS, default/restricted Linux and strict backend — local checks pass (82 cases including the new compatibility coverage; 13 portable Linux cases; strict Linux training). Current run evidence is outside the payload. Exact runtime revision c36f18a passed all three CI jobs, including 82 tests and 33 negative controls per strict platform.
5. Update PR with per-finding dispositions, breaking changes and directly linked CI results — complete for c36f18a; publish this approved packaging cleanup after local checks, then verify its new CI run. Results are retained in the PR description and CI artifacts.

## Maintainer review round 2 (2026-10-13)

Scope: repair fallback integrity and sandbox-aware tests; update the existing PR.
The user explicitly excludes synchronizing the four global skill installations.

1. Reproduce persistent helper/control tampering in disposable copies — complete; four initial regressions failed on the submitted implementation, including a false passed gate and KILLED mutant.
2. Freeze trusted integrity state and check before reusing helpers; isolate destructive tests — complete; focused integrity and compatibility checks pass.
3. Make complete tests sandbox-aware, with strict CI disallowing skipped isolation checks — complete; default Linux executes all 92 cases with 84 passing and eight explicit isolation skips.
4. Run default Linux, strict Linux/macOS, and meaningful regression mutations — full-suite checks pass (strict Linux 92/92, macOS 91/91 plus the final symlink regression); fixed-commit 37-control validation follows before publication.
5. Publish the verified revision and update PR evidence; leave global installations unchanged — pending.
