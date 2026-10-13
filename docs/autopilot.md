# Autopilot skill upgrade validation contract

Historical scope: the completed local validation below is preserved on the
[archive branch](https://github.com/luwill/autopilot/tree/archive/rc2-full-evidence-20261013). Its VALIDATION.md and validation/ artifacts have been removed from the current PR tree with user approval. This retained contract and companion policy do not authorize a new run.

Scope: the user's 2026-10-13 request to upgrade this repository according to the
optimization plan. This file records that authorized local engineering scope; it
is not standing authorization for future runs or external actions.

## Workspace and authorization

Work in an isolated local clone from rc.1 `23ebeed`, then fast-forward the requested
clean repository to the verified commits. Preserve user changes if it has advanced.
Local commits and a release-candidate tag are preparation; no remote publication.
Generated test repositories, synthetic credential strings and temporary process
cleanup are part of validation. No real credential or database access is required.

## Machine gate

| command | proves | rerun |
|---|---|---|
| `make check` | ShellCheck, Bash/Python syntax, Bats integration invariants | safe |

`GATE_TIMEOUT=600` per command. Package self-validation runs directly on the host
or local Linux container: macOS forbids nested sandbox-exec. Each Bats fixture
exercises the real OS backend with generated canaries; missing/failed support is
a failure, never a skipped success. Negative controls run selected baseline and
mutated fixtures in separate fixed-commit worktrees. This is synthetic package
validation, not an adversarial outer containment certification. The product
env-clean mode protects execution inputs and runner controls but retains other
host/network access.

## Evidence and review

Record: `VALIDATION.md`. Evidence directory: `validation/`. Commit them together
with `validation/MANIFEST`. Mutation patches stay outside the repository; evidence
embeds the patches. Independent forward testing specifies P0 targets, tests the
skill and verifies fixes, with no cloud reviewer calls. Shell data-handling tests
are not a model prompt-injection resistance measurement.

Local stages: runner boundaries; method and documentation; tests/negative controls;
review, report and repository delivery. Full mode, not lite. Retry at most three
fix attempts for one failure before changing approach. Any external four-party
re-rating, unavailable platform validation or human judgment remains explicitly
unverified. No numerical acceptance score may be invented.
