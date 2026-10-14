# Changelog

## Unreleased — independent review round (issue #8), trust fixes

- Command output can no longer forge evidence conclusions: tools read a
  result only from the runner-written footer, and backtick runs in commands,
  output and patches are broken so they cannot close a fence.
- Redaction fails closed: a redactor error refuses publication (exit 70) with a
  diagnostic that is withheld rather than printed raw; an invalid
  `REDACT_REGEX` is rejected up front (exit 64). Non-UTF-8 output is withheld
  as before, and no longer breaks signature matching.
- Lite small-change needs the human's opt-in in the committed policy
  (`"lite": [...]`), refuses changed code lines that touch access control or
  secrets, and no longer refuses edits to an already executable script.
- `CODEX_REVIEW_EFFORT` and `CODEX_REVIEW_MODEL` are validated before they are
  spliced into TOML.
- `mutant-status.py` keeps a result current across a test change only when the
  change appends inert lines; an added `exit 0`, `skip`, `|| true` and the like
  mean a rerun.

## Unreleased — lite small-change and host adaptation

- `--lite` gains `risk: small-change` for a small code fix: at most 4 files,
  40 changed lines outside tests, 150 in all, no dependency/build/CI/security
  files, no deleted source. It keeps the machine gate and one KILLED mutant per
  criterion (author-selected allowed), drops the targets request and stage
  review, and keeps the landing audit. Record paths no longer count toward lite
  limits. Refusals name the rule.
- `host-doctor.sh` probes the host and the committed policy and recommends
  strict, install (with `--fix` to apply the host changes when authorized),
  env-clean, degraded or park.
- From the ccmr drill (lite small-change, 17.5 minutes, 6 mutants):
  mutant signatures match the text with ANSI escapes stripped, as the evidence
  shows it (vitest colours output without a terminal); policy `generated_paths`
  keeps committed build output out of lite limits and mutant candidates; gate
  evidence records the check-lite line; sensitive names match whole path words;
  host-doctor tells a missing policy from a missing contract; scratch paths
  default `TMPDIR` to `/tmp`; `mutant-status.py` prints the whole result word.
- Policy `"fallback": "env-clean"` (default `park`): a restrictive policy on a
  host without a usable backend runs with its red lines disclosed as NOT
  OS-enforced and network reduced to dead proxy variables, instead of parking.

## Unreleased — findings from the fourth and fifth end-to-end runs

The token-watcher (Node) and CardiacTrim (Python) runs both landed, with 72 and
102 recorded mutants, most of them reruns. These changes target that cost and the
review snapshot size.

- `mutant-status.py` says which recorded mutants still stand after later commits:
  changes limited to docs paths, record paths or added test lines keep a KILLED
  result current, so only the affected mutants are rerun.
- `suggest-mutants.sh` skips test files (`--include-tests` to opt in), Python
  docstring lines, `return None` → `return` and `x[0]` → `x[-1]`, and explains
  exit 73. On CardiacTrim's change: 501 candidates → 130.
- `api-review.py` sends evidence once: record paths are excluded from the code
  diff, only the evidence the record cites is sent (plus MANIFEST and the
  verification of every file), mutant evidence is condensed to header, patch and
  result, and large changed files go as wide diff context. Landing snapshots of
  the two runs: 851k → 320k and 1.59M → 453k characters.
  It sizes the snapshot before writing anything, sets `max_tokens`
  (`REVIEW_API_MAX_TOKENS`, default 131072), names a reply cut off at the
  output limit, explains the `env-clean` → OS sandbox upgrade to the reviewer,
  writes every output 0600, and names its log `.log.txt`.
- Gates always treat the policy's record paths as records, so a scratch gate no
  longer refuses on the run's uncommitted evidence or reports the record commit
  as the tested commit.
- `evidence.py register` refuses a name `.gitignore` would skip; a committed
  MANIFEST that lists an uncommitted file gets a specific refusal naming it;
  `verify-evidence.sh` checks that every MANIFEST entry exists even when files
  are named. Every record-path refusal now says why.
- Gate evidence labels the `GATE_KEEP_REGEX` matches.
- Docs: commit `current:` before background reviews and with every stage
  commit, and reconcile it on resume; per-run scratch paths; what counts against
  a review budget; operational review failures are not finding rows; a Python
  migration example (venv in `read_paths`, `-B`, `-p no:cacheprovider`).

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
