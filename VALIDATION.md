# Upgrade validation record — 0.2.0-rc.2

- status: local engineering scope complete; external acceptance parked
- date: 2026-10-13 (Asia/Taipei)
- base: v0.2.0-rc.1 / 23ebeedcd41ebcc2682a077549e598e64c9093ce
- tested commit: d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0
- production implementation: 67195db2788a647a666ca1f74c0d82798ddcf87b
- scope: user-authorized rc.1 findings repair, regression tests, rc.2 candidate and fresh independent review
- evidence: validation/ and its SHA-256 MANIFEST; historical artifacts remain preserved
- authorization: docs/autopilot.md; no global installation, remote push or external cloud review

## Implementation plan completion

1. Requirements and existing patterns: complete; rc.1 findings and original criteria preserved.
2. Repairs and regression tests: complete; F1–F7/G1 plus three newly confirmed review findings repaired.
3. Platform checks and negative controls: complete; final macOS and Ubuntu results below.
4. Fresh independent review and bounded repair/recheck: complete; no open targeted defect, score below 9.
5. Evidence and local candidate delivery: complete in the accompanying record commit and local rc.2 tag.

## Acceptance criteria

Original criterion wording is preserved. Earlier rc.1 claims are historical and superseded by this record.

| ID | Frozen criterion | Status and current evidence |
|---|---|---|
| C1 | Fixed-commit runners, isolated command environment, enforced policy probes | proven in scoped fixtures on both platforms; rc2-*-make-check.log, current worktree/env/probe/source-readonly/control-root controls |
| C2 | Full-hash manifests, redaction, locks and preserved interrupted evidence | proven in fixtures; current manifest/redaction/lock/partial/write-failure/record-inventory controls and final manifest verification |
| C3 | Diff-limited mutation suggestions, deterministic lite mode, independent review rules | script behavior proven; current diff/lite/review-policy/review-identity controls, independent reports; model behavior remains unverified |
| C4 | Portable package, concise skill, complete example, license/version/CI | real macOS and Ubuntu execution, relocated package test, both training bundles; hosted CI remains unverified |
| C5 | Local Bats/ShellCheck, fixed training ground, executable P0 negative controls | 69/69 tests per platform, 33/33 KILLED controls per platform, both complete training runs |
| C6 | External four-party safety >=8.5 and average >=9 | parked; no external four-party scores supplied; scoped fresh-agent six-dimensional mean is 8.85/10, not 9 |

## Current execution evidence

- `rc2-mac-make-check.log`, `rc2-linux-make-check.log`: 69/69 Bats, ShellCheck and Bash/Python syntax pass. The macOS suite ran on the exact tree committed as d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0; Linux cloned its immutable Git bundle.
- `rc2-mac-controls.json` and `rc2-linux-controls.json`: 33 targets each, baseline green and signed target failure for every KILLED result. Current Markdown controls use prefixes `rc2-release-mac-` / `rc2-linux-` at d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0. Patches are embedded; retained worktrees make local diagnosis inspectable.
- `rc2-mac-training.log`, `rc2-linux-training.log`, and their `.bundle` files: seeded logic failure caught; weak detector SURVIVED; strengthened detector KILLED; file/network red lines blocked; final checks passed; seven evidence artifacts verified per training run.
- `rc2-runtime.json`: host/container versions, image identity, execution configuration and limits. Linux used local Ubuntu 24.04, non-root runner and actual bubblewrap namespaces. Docker outer seccomp/AppArmor/system-path masking were relaxed to permit nested user namespaces/proc mounts; no privileged mode, Docker socket or credential mounts. This verifies bwrap behavior in that local VM, not hosted Actions or every Linux kernel.
- Skill Creator quick validation passed. SKILL.md remains 8,440 bytes versus original 14,370 (58.7%); manual invocation is preserved; implicit invocation is disabled through allow_implicit_invocation:false.

## Repair ledger

| Finding | Change | Regression / current control |
|---|---|---|
| F1 alternate policy ignored by reviewer | shared pinned policy selection and effective-policy/input identity | alternate policy dispatch/identity; policy-selection and review-policy controls |
| F2 Git errors mistaken for clean state | explicit failure propagation for source and worktree status | source-only Git I/O fault; git-errors control |
| F3 mutant source drift accepted | expected actual byte/mode/link snapshot after patch; verify every command | extra edit and patch reversal cases; source-snapshot control |
| F4 tail/grep errors swallowed | propagate I/O failures, retain valid grep no-match | failed-filter and grep-I/O cases; filter-errors control |
| F5 unsafe lite eligibility | only nonexecutable .md/.rst docs, risky names/modes rejected | requirements/build/executable/mode-only cases; lite-data/lite-risk controls |
| F6 Linux sandbox test skipped | portable fake backend and real Linux execution; skip-only activity guard | fake sandbox and 69 Linux tests; skip-only control |
| F7 extension-only record exclusions | pinned artifact inventory and full hashes, separately checked live inventory | HTML/JSON rejection, registered HTML acceptance, live-manifest cannot authorize pinned source; record-inventory control |
| G1 transient source rewrite | every execution mode protects source/Git; dedicated new output directories | write/restore, hardlink, valid output directory tests; source-readonly control |
| rc.2 security finding | protect runner scratch controls, helper scripts and evidence from command writes | independently replayed old/new behavior; control-root control |
| rc.2 TAP R1 | accept valid unnumbered/bare TAP test lines | unnumbered positive and skipped negative cases |
| rc.2 TAP R2 | identify plan-free skip-only TAP as inconclusive | gate and mutant no-plan skip-only cases |

F1–F7/G1 were implemented in 60fb48d; follow-up controls, helper/evidence protection and TAP fixes in 67195db. d9ca7cea3abe5ad260b296c8e2ac78c563f6e5f0 includes test-only refinements to isolate redundant checks and compare canonical physical paths; production scripts remain unchanged. A Linux strict-root writability issue discovered during real platform validation was also repaired before 60fb48d.

## Independent review and scoring

`rc2-review-initial.md` froze a fresh-context review of 60fb48d before consulting historical scores. Its two confirmed TAP defects were repaired. A separate fresh security reviewer reported the runner-control-file defect; that agent did not complete a written report. Its finding was independently replayed and checked by the final reviewer.

`rc2-review-final.md` records the bounded second review of immutable 67195db: five targeted Bats cases plus direct old/new repair experiments, seven verified records. `rc2-review-results.json` and prefixed direct evidence preserve the checks. Final test-only changes and main-host full-platform results are separately attributed; they are not represented as the reviewer's own executions.

Final six-dimensional equal-weight score: 8.85/10. This is a same-family fresh-context engineering assessment, not four external parties or live cross-model acceptance. No target score was requested from the reviewers. All confirmed targeted defects are resolved; remaining scope limitations are not silently promoted to runtime failures or treated as demonstrated guarantees.

## Failed attempts and provenance

- `rc2-mac-p0-1-worktree.md`: old nested self-test harness was INCONCLUSIVE on macOS because nested sandbox-exec is unsupported.
- `rc2-initial-linux-worktree.md`: the old Linux cwd target SURVIVED because bwrap's own --chdir remained effective. The revised target attacks that actual setting.
- `rc2-final-mac-*` at 67195db and `rc2-round2-linux-*.md`: 31/33 controls killed; Git and inventory targets survived because redundant guards still rejected the fixture. Final tests isolate source status from worktree status and pinned inventory from live inventory. These failures remain historical, not counted as passing current controls.
- `rc2-verified-mac-*` at 6c54194: 32/33 controls killed. The worktree target survived because /var and /private/var aliases made a wrong working directory appear different; the final test compares physical canonical paths. The corresponding Linux round was 33/33. Both remain historical.
- The self-test controller executes Bats in separate fixed-commit worktrees on the host. Each fixture invokes the real OS backend. It has no nested immutable outer sandbox and is not evidence that arbitrary hostile patches are contained. Synthetic fixtures contain no production secrets.
- Historical rc.1 records/reports/bundles and original finding ledger remain in Git and validation/. Their previous scores and guarantees do not override this rc.2 assessment.

## Remaining limits

External four-party C6 acceptance, live model prompt-injection testing, hosted Actions, authenticated execution attestation and independent production use remain unverified. env-clean protects selected execution/control/evidence roots but permits other host/network access. The TAP helper is an activity guard, not a complete test harness. macOS process groups do not contain intentionally session-escaping descendants; stronger lifecycle guarantees require an outer supervisor. Power-loss/SIGKILL durability and disk-full fault coverage are not claimed complete. Read-only builds require explicit writable output/cache directories. Hashes bind bytes to a selected Git commit; they do not prove execution truth or reviewer independence.

## Verification

1. `bash scripts/verify-evidence.sh validation` at the record/tag commit.
2. Inspect current make-check logs, both 33-entry results JSON files, embedded patches and baseline/failure signatures.
3. `git bundle verify validation/rc2-mac-training.bundle` and the Linux equivalent.
4. Read the independent final report and unresolved external acceptance before promoting the candidate.
