# Upgrade validation record — 0.2.0-rc.1

- status: landed (local engineering scope complete; external acceptance parked)
- current: local candidate ready; C6 awaits external reviewers
- date: 2026-10-13 (Asia/Taipei)
- base: ce2499990917362d2c9674f59bad2b21f46d1d9b
- tested commit: 67289c7d8dcf7fa114b44e843aa795eb147c291e
- scope: user-authorized local upgrade according to the optimization plan, including its Codex supplementary review
- contract: docs/autopilot.md; local engineering scope, not future external authorization
- mode: full local validation; external numerical acceptance parked
- evidence: validation/ and its SHA-256 MANIFEST, committed with this record

## Acceptance criteria

Original criteria are preserved; the evidence/status columns are updated.

| ID | Frozen criterion | Status and evidence |
|---|---|---|
| C1 | Fixed-commit runners, isolated command environment, enforced policy probes | proven locally: gate-landing-verified.md; verified-p0-1-worktree.md, verified-c1-env-inheritance.md, verified-c1-probe-enforcement.md and sandbox/callback controls |
| C2 | Full-hash manifests, redaction, locks and preserved interrupted evidence | proven locally: manifest/redaction/lock/partial controls, verified-supplement-evidence-write.md, verified-supplement-record-scope.md and verified-author-output-symlink.md |
| C3 | Diff-limited mutation suggestions, deterministic lite mode, independent review rules | proven for scripts and rule artifacts: verified-c3-diff-only.md, verified-c3-lite-boundary.md, verified-supplement-lite-risk.md and review identity/policy controls; model behavior limitation below |
| C4 | Portable package, concise skill, complete example, license/version/CI | proven as local artifacts and relocated execution: verified-c4-portability.md, gate-landing-verified.md; CI configuration inspected, hosted execution unverified |
| C5 | Local Bats/ShellCheck, fixed training ground, executable P0 negative controls | proven locally: 54 tests, 24 current KILLED controls, verified-controls.json, training-verified.bundle; failure-signature control checks the negative-control classifier |
| C6 | External four-party safety >=8.5 and average >=9 | parked: no external four-party scores have been supplied |

## Results and provenance

- `make check`: 54/54 Bats tests, zero ShellCheck diagnostics, Bash/Python syntax passed.
- Final machine gate: `gate-landing-verified.md`, running both `make check` and the
  complete fixed training ground from code commit `67289c7d8dcf7fa114b44e843aa795eb147c291e`.
- 24 executable controls: every baseline is green, every mutant matches its frozen
  failure signature and returns KILLED. `verified-controls.json` lists source,
  selection provenance and evidence. The embedded patches and commands allow replay.
- Skill Creator validation passed. SKILL.md is 8,366 bytes versus 14,370 at baseline
  (58.2%). Details live in REFERENCE.md; manual invocation policy is preserved.
- Runtime: macOS, Bash 3.2.57, Python 3.14.4, Bats 1.14.0, ShellCheck 0.11.0, jq 1.7.1.
- Real OS checks ran outside Codex's outer sandbox, which prohibits nested
  sandbox-exec. The skill's own OS sandbox remained enabled. Synthetic allowed
  reads, forbidden reads/writes and denied external-address UDP socket creation
  were exercised; the UDP connect probe transmits no payload.
- The training fixture catches the seeded boundary bug, demonstrates SURVIVED
  with a weak guard detector, then KILLED with a strengthened signed assertion,
  enforces file/network red lines, passes its final check and verifies seven files.
  Its full Git history, contract, record and evidence are in training-verified.bundle.

All `verified-*` controls and `gate-landing-verified.md` test the current code SHA.
Older `p0-*`, `final-*`, other gate records and older bundles are retained as
historical evidence only. They are not substituted for current results. The frozen
contract, run-record snapshots, scripts and tests are inspectable at their commits.

## Independent mutation targets

| Criterion | Selected by | Condition challenged | Current evidence |
|---|---|---|---|
| C1 | forward reviewer + acceptance auditor | pinned cwd; inherited ambient env; unconditional probe success; sandbox upgrade/Git callbacks | verified-p0-1-worktree.md; verified-c1-env-inheritance.md; verified-c1-probe-enforcement.md; verified-p0-4-*.md |
| C2 | forward/supplemental reviewer | hash comparison; masking; lock/archive; swallowed write errors; source excluded as records | verified-p0-2-manifest.md; verified-p0-3-*.md; verified-p0-7-*.md; verified-supplement-evidence-write.md; verified-supplement-record-scope.md |
| C3 | acceptance auditor + supplemental reviewer | untouched-line mutations; 51-line admission; runtime/security lite admission; stale review reuse/forbidden dispatch | verified-c3-*.md; verified-supplement-lite-risk.md; verified-supplement-review-*.md |
| C4 | acceptance auditor | hardcoded legacy fixture root despite relocated package and valid decoy | verified-c4-portability.md |
| C5 | supplemental reviewer; original forward reviewer | arbitrary nonzero exit being called KILLED; runtime safety detectors challenged by the P0 suite | verified-supplement-failure-signature.md; verified-controls.json |

`verified-p0-6-output-data.md` is an **author-added shell data-handling control**,
not the independent reviewer's proposed LLM injection experiment.
`verified-author-output-symlink.md` is an additional author-discovered writer-path
control. Neither is misattributed as an independent model-level result.

## Review finding ledger

The final independent audit at `f0bdc03b5f4a8cc0a1144ae0c2029d82a93fd631` found
no remaining local acceptance blocker and carried R5-R14. It verified 72 evidence
files and independently reran nine focused tests (9/9 passed). Its one minor
fix-attribution correction is applied below. The final report is preserved as
`acceptance-review-final.md`; the later landing record changes no tested source.
Every fix below has its named passing regression and current control where relevant.

| ID | Reviewer / round | Finding | Status | Fix commit and detector |
|---|---|---|---|---|
| R1 | independent forward test | host Git callbacks escaped the command boundary | blocking-fixed | 12d1cd7; smudge/fsmonitor/clean canary tests; current verified-p0-4-git-callback.md |
| R2 | independent forward test | evidence directory symlink could verify unpinned bytes | blocking-fixed | 12d1cd7; `verifier refuses evidence reached through a symlink directory` |
| R3 | independent forward test | escaped adjacent assignments bypassed masking | blocking-fixed | 12d1cd7; `escaped line separators do not hide a second credential marker` |
| R4 | independent forward recheck | includeIf activated filters only in linked worktrees | blocking-fixed | 12d1cd7 implementation; 6971c45 adds the control; conditional-filter regression and independent-recheck.json; current verified-p0-4-conditional-filter.md |
| R5 | acceptance audit 1 | C1/C3/C4 lacked substantive clause/independent-target controls | blocking-fixed | 1fb6c95; env/probe/diff/exact50-51/relocated-package tests and current controls |
| R6 | acceptance audit 1 | finding statuses and fix/test ledger missing | minor-fixed | f0bdc03; explicit finding rows and the independent target table |
| R7 | supplemental reviewer | incomplete evidence could be published after write failure | blocking-fixed | 1fb6c95; `evidence write failure cannot publish an incomplete success`; verified-supplement-evidence-write.md |
| R8 | supplemental reviewer | non-target mutant failures could count as KILLED | blocking-fixed | 1fb6c95; `failure signature rejects unrelated errors and wrong exits`; verified-supplement-failure-signature.md |
| R9 | supplemental reviewer | restricted cloud review had no equivalent policy boundary | blocking-fixed | 1fb6c95; cloud dispatch parks before invocation; verified-supplement-review-policy.md |
| R10 | supplemental reviewer | caller record paths could hide source; freshness too narrow | blocking-fixed | 1fb6c95; source exclusion regressions, verified-supplement-record-scope.md; conservative freshness rule in both references |
| R11 | supplemental reviewer | tiny security/runtime changes could use lite | blocking-fixed | 1fb6c95; one-line auth/skill tests; verified-supplement-lite-risk.md |
| R12 | supplemental reviewer | review reuse lacked input/job identity | blocking-fixed | 1fb6c95; stale head/scope/altered-output regression; verified-supplement-review-identity.md |
| R13 | supplemental reviewer | retries/publication lacked explicit admission rules | blocking-fixed | 1fb6c95; interrupted side-effect test and verified-supplement-resume.md; publication prerequisites in SKILL/REFERENCE/contract template |
| R14 | author final path check | committed output symlink redirected writer outside repo | blocking-fixed | 67289c7; committed output-link regression; verified-author-output-symlink.md |

| R15 | final acceptance audit | R4 attributed the implementation to its later control commit | minor-fixed | final landing record corrects R4 to 12d1cd7; independent audit verified Git history; tested source unchanged |

The original finding artifacts are independent-review.md, independent-recheck.json,
acceptance-review-r1.md and supplemental-review.md. The acceptance auditor's old
worker rerun hit outer-sandbox restrictions; that is not represented as a passing
strict OS run. Current passing OS evidence comes from the final main-host gate.

## Parked and not verified

- **C6:** request the four actual reviewers' re-ratings against this candidate and
  archive their reports before claiming safety >=8.5 / average >=9. No score is invented.
- **Model prompt injection:** scripts prove logs are data, and the instructions
  state the trust boundary. Live reviewer injection tests and cross-model behavior
  remain unverified. Static wording and shell controls cannot substitute for them.
- **Linux / hosted CI:** the Ubuntu/macOS workflow is configured; Linux/bubblewrap
  and remote Actions have not run here. Local Docker was unavailable. Trigger the
  configured workflow only when repository publication is authorized.
- **Isolation limits:** the outer self-validation runner uses env-clean as the
  contract states; it does not confine the host. Synthetic tests exercise the inner
  OS sandbox. Security controls here are narrowly authored fixture mutations, not
  an adversarial containment certification. Writes inside a disposable checkout
  remain allowed; post-checks alone cannot detect every transient write-and-restore.
- **Process/durability limits:** process-group cleanup does not establish containment
  of descendants deliberately escaping the group/session. SIGKILL/power-loss and
  disk-full fault injection are not claimed proven by ordinary writes/TERM tests.
  Production guarantees need appropriate outer job supervision and platform tests.
- **Trust:** a manifest binds bytes to a selected Git commit; it is not an
  authenticated signature or proof that a reviewer obeyed its instructions.
- **Publication:** local code/record commits and a candidate tag are preparation.
  Global skill installation, remote push/release and unrestricted cloud review are
  outside this completed local scope; outstanding external acceptance is explicit.

## Acceptance walk

1. Verify `bash scripts/verify-evidence.sh validation` at the reviewed record commit.
2. Read gate-landing-verified.md: both commands exit 0, all 54 tests pass, and the
   fixture prints TRAINING PASSED after seven verified results.
3. Read verified-controls.json and its 24 named files; inspect frozen signatures,
   green baselines and the target failures rather than accepting exit codes alone.
4. Verify `git bundle verify validation/training-verified.bundle`; replay the complete
   example in a new temporary directory as described by examples/README.md.
5. Inspect review findings, their ledger dispositions and the explicit unverified
   items before promoting the candidate to an externally accepted release.
