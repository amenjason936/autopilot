# Autopilot upgrade implementation plan

Source: `../optimization-plan.md`; baseline `ce24999`. Scope is this skill repository.
No global installation, remote publication, production credentials, or database changes.

## Stages

1. **Safety and evidence — complete.** Pin both runners to disposable worktrees;
   add fail-closed redaction, environment allowlists, sandbox policy and probes,
   dry runs, directory locks, partial preservation, and SHA-256 manifests.
2. **Independent checks — complete.** Diff-limited mutation suggestions and a
   deterministic lite eligibility check; update both review briefs.
3. **Packaging and documentation — complete.** Short entrypoint, reference,
   contract/record templates, portable installation, complete example, MIT license,
   version and changelog.
4. **Validation tooling and audit fixes — implemented.** Bats, ShellCheck, Linux/macOS CI, fixed
   training ground, P0 regression mutations, independent forward testing, and a
   candid acceptance report. Sync tested changes into the requested repository.

## Acceptance and limits

- Test observable behavior, including failure and interrupted paths, rather than
  claiming safety from documentation or a successful exit alone.
- A committed manifest detects alteration relative to the reviewed commit; it is
  not an authenticated signature against a writer able to replace that commit.
- `env-clean` is environment hygiene only. A contract's path/network restrictions
  require a supported OS sandbox and successful positive/negative probes.
- Four external reviewers' scores and remote CI results must remain unverified
  until those reviewers/CI actually run. Do not invent the plan's 9/10 rating.
- Temporary test repositories can have fixture commits; final code commits/tags
  require the prescribed checks to pass. Existing user files are not deleted.

## Results

53 Bats tests and ShellCheck pass on macOS. Supplementary review added failure
signatures, fail-closed evidence writes, request identity, safe recovery, committed
record-path admission and risk-based lite restrictions. Final controls, acceptance
audit and repository delivery are tracked in VALIDATION.md. The committed validation record contains
the self-run machine gate, training-ground archive, P0 negative controls and
independent-review fixes. Linux execution and external four-party scores require
the configured CI/external reviewers; those are not counted as passed.
