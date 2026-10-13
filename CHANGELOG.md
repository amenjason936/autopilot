# Changelog

## Unreleased — cross-run helper trust and a cloud model reviewer

- Gates compare the helper inventory with a trusted reference before running:
  the takeoff pin `AUTOPILOT_HELPER_PIN`, a clean Git checkout of the skill, or
  `INSTALLATION.json`. A helper changed by an aborted gate no longer becomes the
  next gate's baseline; the refusal names the changed files (#3). `--dry-run`
  prints the digest to pin, and evidence records the reference used.
- The `resume parked` message for a leftover `.partial` names the label and says
  to use a new label or a verified safe rerun policy.
- `api-review.py`: snapshot-only adversary review by a cloud model from another
  family (default DeepSeek `deepseek-flash`) through an OpenAI-compatible API.
  The prompt is redacted before upload, supplied files are listed with hashes,
  replies are validated and sealed, and upload needs `REVIEW_API_UPLOAD=approved`.

## Unreleased — findings from the sandboxed token-watcher end-to-end run

- Ask the adversary for mutant targets before the first recorded mutant wave,
  and explore with scratch evidence outside the repository, so a detector fix no
  longer forces every recorded mutant to rerun.
- `suggest-mutants.sh` masks string/template literals and line comments instead
  of skipping any line with a quote, and adds JavaScript/TypeScript (and C)
  guard, boolean, strict-equality and empty-return candidates.
- `evidence.py register DIR SOURCE [NAME]` registers review findings, requests,
  receipts and other files in one step: lock, redact, write, MANIFEST, unlock.
- Helpers that import siblings no longer write `scripts/__pycache__`, which a
  concurrent gate read as tampering (#2).
- Redaction leaves switch values (`TOKENMETER_NO_KEYCHAIN=1`, `KEY_ROTATION=off`)
  alone; `verify-evidence.sh` explains a path given instead of a file name.
- Evidence says `timed out: no|yes (after Ns)` instead of `timeout=0|1`.
- The auditor reruns `rerun: safe` gates into evidence outside the repository;
  `minor-open` is allowed at landing with a reason; `landed` closes a run whose
  landing steps are parked; the missing-CLI fallback reviewer may inspect the
  pinned snapshot read-only; `current:` and the resume table share one vocabulary;
  `validate-findings.sh` documents its seven-argument form.

## Unreleased — fallback integrity and sandbox-aware tests

- Detect persistent changes to every helper and frozen execution control before
  and after each command; keep the checker and expected hashes in parent memory,
  and stop without invoking damaged helpers or publishing passing evidence.
- Keep the documented endpoint-only limit: fallback detects persistent tampering
  but cannot prevent host writes, transient restoration, or racing processes.
- Run destructive helper tests only against disposable copies. Explicitly skip
  eight isolation-dependent tests if no backend can launch; strict CI requires
  the backend and refuses skipped isolation coverage.
- Run the entire default-Linux suite instead of a compatibility subset, also with
  forced-unavailable backends. Add integrity regressions and four targeted negative
  controls for helper/control validation and the trusted checker path.

## Unreleased — maintainer compatibility fixes

- **Breaking migration:** existing contracts require a committed JSON policy;
  gates use fresh worktrees without untracked dependencies. See REFERENCE.md for
  writable dependency outputs, offline setup and existing-contract migration.
- Let unrestricted env-clean run without a usable OS backend, with explicit
  non-enforcement evidence. Strict restrictions still refuse with exit 77.
- Run initial preflight/patch checks before creating durable partial evidence;
  failed checks can retry their label without asserting safe side-effect replay.
- Preserve manual-only canonical Claude frontmatter; remove that key only from
  Codex installations. Restrict packages to runtime files and stage outside skills.
- Bind explicit or legacy stage scope correctly; document snapshot-only fallback
  review, Docs paths, invocation/resume entrypoints and landing record order.
- Separate default Ubuntu compatibility CI from enforced-backend validation and
  publish run results as CI artifacts.

## Unreleased — multi-host installation

- Add a full-package installer for Codex, Claude Code, ZCode shared user skills
  and ccmr (`~/.claude-gateway/skills`), with explicit replacement, retained old
  copies/symlink targets, per-host manual-invocation metadata and SHA-256 receipts.
- Install from committed Git bytes; refuse dirty tracked source and omit untracked
  files and Git metadata. Host account, routing and launcher settings stay intact.

## 0.2.0-rc.2 — 2026-10-13

- Share selected policy identity across gates, review dispatch and resume (F1).
- Under an enforced OS backend, protect runner policy/snapshot/helper/evidence
  files against command writes (independent rc.2 review). Fallback endpoint integrity
  was added in the unreleased maintainer fix above.
- Accept valid unnumbered TAP; refuse skip-only TAP even without a plan.
- Run self-test controls without unsupported nested macOS sandboxing, and mutate
  the actual Linux bwrap cwd control.
- Refuse failed Git reads, unexpected mutant source changes, and failed output
  filters instead of emitting successful evidence (F2–F4).
- Protect source/Git with an OS boundary in every mode, including env-clean;
  explicit fresh output directories replace writable source checkouts (G1).
- Require registered artifact inventories for evidence exclusions; restrict lite
  to non-executable Markdown/reStructuredText (F5/F7).
- Replace the macOS-only probe mutant detector with portable fake backends and
  reject skip-only/empty TAP detectors (F6).
- Real Linux validation exposed synthetic ancestor directories remaining writable;
  strict bubblewrap roots are now remounted read-only, with explicit output mounts.
- Add targeted rc.1 counterexample regressions, positive controls, a local Linux
  validation image, and compatible ShellCheck guards across host versions.

Historical scores and local platform coverage belong to the archived run record;
current CI artifacts contain reproducible test evidence, not four-party approval.

## 0.2.0-rc.1 — 2026-10-13

- Pin gates and baseline/mutant checks to separate disposable worktrees; refuse
  dirty code and invalidate concurrent HEAD/source changes.
- Add a frozen JSON execution policy, sanitized environment, enforced OS sandbox
  escalation and controlled filesystem/network probes; add command previews.
- Redact command output, patches, previews and review logs before disclosure;
  reject sensitive/injection environment names and fail closed on bad redaction.
- Hash evidence with full SHA-256, serialize writers with a directory lock, preserve
  interrupted partials, and reject existing review outputs instead of deleting them.
- Generate diff-limited mutation candidates; introduce deterministic lite eligibility,
  a compact skill entrypoint, portable paths, and explicit evidence trust rules.
- Add Bats/ShellCheck CI, a fixed training ground, and a complete example. Licensing is being discussed separately with the maintainer.

Validation found that pinned review code previously used a live run-record snapshot:
reviews now read the record at the pinned head. Mutant timeouts, signals and missing
commands are INCONCLUSIVE, and baseline/setup source mutations are rejected.

Independent forward testing also exposed host Git filter/fsmonitor callbacks,
symlinked evidence directories and escaped-separator redaction. Each received a
regression check and a targeted fix.

Supplemental review hardened evidence-write failure handling and completeness
checks, frozen mutant failure signatures, approved dedicated record exclusions,
restricted review dispatch, request/receipt identity, safe interrupted-command
recovery and risk-based lite admission. Evidence writers reject symlink redirects before resolving paths. Tiny runtime/security changes use full mode.

The four-party numerical re-rating and remote CI are external acceptance steps;
this changelog does not imply they have passed.

## Prototype — through ce24999

Corrections from the token-watcher trials: record-path separation, portable temp
files, timeout handling, and baseline checks for mutation runs. No release tag was
present at the start of this upgrade.
