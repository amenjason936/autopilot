# Priorities for a more usable, measurable Autopilot

The execution and evidence machinery is already useful. The next improvements
should reduce the work needed to use it and measure when that work pays off.
These are proposed acceptance targets, not results or a promised rating.

| Priority | Change | Acceptance | Cost / dependency |
|---|---|---|---|
| P0 | Keep the macOS loopback exception restricted to loopback | Live controls allow a local connection but refuse an external UDP connect without sending packets. Fix the overly broad local-address rule found during this PR's validation. | Small; this PR |
| P0 | One local entry point for proposed project setup, host diagnosis and setup status | A first-time user can generate the three configuration drafts with one command, see which files still need review/commit, and find the next command. Preview and status execute no project code; existing files are preserved. | Small; this PR |
| P1 | Run cost and intervention report | A local report includes elapsed time, gate/mutant attempts, reused versus rerun mutants, reviewer calls and reported token usage. Missing data is `unknown`, never zero. Provider prices are explicit dated inputs; secrets and source text are excluded. | Medium; needs a versioned event format and restart-safe event IDs |
| P1 | Budget preflight and bounded review inputs | Preview the snapshot size and approved call budget before upload. Stop before another call would exceed a locally enforceable limit; distinguish token estimates from billed usage. Preserve failed-call receipts and count sent requests. | Medium; build on the cost report and current snapshot cap |
| P2 | A published cross-project comparison | Freeze at least six tasks spanning Python, JavaScript/TypeScript and a mixed stack. Compare the same model/task/budget with and without Autopilot, with multiple repetitions. Publish task outcomes, seeded-defect recall, false findings, time, tokens and interventions, including failures and uncertainty. | Larger; requires a separately approved model budget |
| P2 | First-run usability trials | At least five people unfamiliar with the project attempt the documented setup. Record time to first verified gate, confusing steps and intervention count. Target median setup below ten minutes **after prerequisites are provisioned**; report provisioning separately. | Medium; requires actual participants |
| P3 | Reproducible releases and compatibility | Publish a versioned release with payload checksums, supported host/runtime versions and a tested upgrade/rollback example. Test the documented minimum Python version and both OS backends; pin release CI dependencies. | Medium; follows stable onboarding and measurements |
| P3 | Consolidate only demonstrated maintenance hotspots | Use defects and duplicated rules to select small refactors. Preserve CLI compatibility and compare behavior with the existing regression and mutation suites. | Incremental; avoid a wholesale rewrite |

## P0 boundaries

Initialization prepares **proposed** configuration. It does not approve a
contract, commit a project, select lite mode, install dependencies, run tests,
dispatch reviewers, or publish anything. It uses offline strict policy selection
with `fallback: park`; host limitations remain visible through the existing
doctor and runner probes.

Setup status distinguishes working-tree drafts from committed configuration.
Committed configuration is not evidence that the human approved it or that a
gate/audit passed. Existing custom policies and record paths must remain usable.

Keep the advanced helpers available. The entry point should reuse their policy
rules rather than creating a second runner or silently changing a contract.

## Evidence needed before claiming improvement

The current CI proves regression behavior on its fixtures. The field report in
[issue #9](https://github.com/amenjason936/autopilot/issues/9) shows useful defect
detection in a real project; it is not a controlled success-rate estimate.
[PR #6](https://github.com/amenjason936/autopilot/pull/6) documents substantial
reductions in reruns and review input size; those measurements are case-specific.

Report the new comparisons separately from historical cases. Do not substitute
another model's numeric rating for observed task quality, cost or usability.
