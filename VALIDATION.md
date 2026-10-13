# Upgrade validation record — 0.2.0-rc.1

- status: flying (local gates complete; final independent acceptance audit pending)
- current: landing acceptance audit
- date: 2026-10-13 (Asia/Taipei)
- base: ce2499990917362d2c9674f59bad2b21f46d1d9b
- tested commit: 80d85fc35ed6d7400981e9f67c64eed5be2a9c3a
- scope: user-authorized upgrade of this repository according to the supplied plan
- contract: docs/autopilot.md; this records local engineering scope, not future external authorization
- mode: full local validation; external numerical acceptance remains parked
- evidence: validation/ and its SHA-256 MANIFEST, committed together with this record

## Acceptance criteria

| ID | Frozen criterion | Status and evidence |
|---|---|---|
| C1 | Fixed-commit runners, isolated command environment, enforced policy probes | proven locally — gate-landing-final.md; P0 worktree, sandbox and callback controls |
| C2 | Full-hash manifests, redaction, locks and preserved interrupted evidence | proven locally — manifest/redaction/environment/lock/partial P0 records and Bats regressions |
| C3 | Diff-limited mutation suggestions, deterministic lite mode, independent review rules | proven for scripts and documented workflow — 42-test gate, both briefs, independent review; model behavior limitation below |
| C4 | Portable package, concise skill, complete example, license/version/CI | proven as local artifacts — README, REFERENCE, examples, VERSION, MIT license, workflow; remote CI not run |
| C5 | Local Bats/ShellCheck, fixed training ground, executable P0 negative controls | proven locally — 42 Bats tests, zero ShellCheck diagnostics, 11 KILLED controls, training-final.bundle |
| C6 | External four-party safety >=8.5 and average >=9 | parked — those reviewers have not supplied scores |

The baseline self gate tested `12d1cd7`; the final gate tests `80d85fc35ed6d7400981e9f67c64eed5be2a9c3a`.
The 10 original runtime mutations remain current: their mutated source files,
executed detector tests and policy have not changed. The conditional-filter mutant
was added at `6971c45`. Later changes fixed patch formatting, CI coverage and
attribution metadata; the final gate reran the entire suite and training ground.

## Results and provenance

- Runtime: macOS, Bash 3.2.57, Python 3.14.4, Bats 1.14.0, ShellCheck 0.11.0, jq 1.7.1.
- `make check`: 42/42 Bats tests, ShellCheck and Bash/Python syntax passed.
- Skill Creator frontmatter/name validation passed. SKILL.md is 7,426 bytes versus
  14,370 at baseline (51.7%); procedural detail moved into REFERENCE.md.
- Real macOS sandbox tests passed only after running outside Codex's outer sandbox,
  which forbids nested sandbox-exec. The skill's own sandbox remained enabled;
  filesystem and network denial were actually exercised with synthetic canaries.
- The fixed training ground caught its seeded boundary bug, showed SURVIVED for a
  weak guard detector, KILLED after strengthening it, denied file/network access,
  passed its final check and verified seven fixture evidence files. Complete fixture
  history, contract, records and evidence are preserved in training-final.bundle.
- 11 executable negative controls are KILLED. See p0-results.json for every source
  SHA and record. Ten follow independently specified runtime targets; the
  output-data control was added by the author and has the narrower scope below.

## Independent review and fixes

A fresh forward-testing context found three concrete problems: host Git callbacks,
evidence-directory symlinks and escaped-adjacent-credential masking. All were
reproduced and repaired with regressions. The second pass exposed filters activated
only in linked worktrees by includeIf. Checkout now uses --no-checkout, inspects the
linked tree's effective config, then materializes with callbacks disabled. A final
independent recheck confirmed neither smudge nor clean canaries fired.

Evidence: independent-review.md and independent-recheck.json. That reviewer's own
outer sandbox prevented its strict OS run; the passing real OS checks above are
from the main validation run, not an invented reviewer result. The later no-final-
newline patch fix received a regression but no separate adversarial design pass.

## Limits and parked work

- **P0-6 distinction:** p0-6-output-data.md proves the runner does not execute log
  text as shell code. It does **not** prove an LLM reviewer resists prompt injection.
  SKILL.md and both briefs state the trust rule; a live model-level negative control
  and cross-model behavioral evaluation remain unverified.
- Linux/bubblewrap execution and hosted GitHub Actions remain unverified locally.
  The local Docker daemon is not running. Ubuntu/macOS CI is configured, including
  strict sandbox tests and P0 regressions, but has not been remotely triggered.
- Four-party re-rating is not replaced by the local independent reviewer. No 9/10
  score, safety score >=8.5, or fully accepted release is claimed.
- SIGKILL/power-loss durability is not established by TERM/normal-exit tests. A
  stale lock/orphan result must be inspected and recovered deliberately; hashes
  fail closed for incomplete evidence. A manifest is not an authenticated signature.

## Acceptance walk

1. Run `bash scripts/verify-evidence.sh validation` from the checked-out review
   commit; all listed hashes must match. Explicitly name any extra cited file.
2. Read gate-landing-final.md: both commands exit 0, all 42 tests pass, and the
   fixture prints TRAINING PASSED after seven verified results.
3. Read the sandbox and conditional-filter negative controls, then p0-results.json.
   Each control has a green baseline and KILLED result, with the P0-6 caveat above.
4. Run `git bundle verify validation/training-final.bundle` to check the complete
   synthetic fixture archive; replay examples/README.md into a new temp directory.
5. Review the parked items before treating this candidate as a fully accepted
   release. Repository publication and global skill installation are separate actions.
