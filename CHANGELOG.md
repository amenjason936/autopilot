# Changelog

## 0.2.0-rc.2 — 2026-10-13

- Share selected policy identity across gates, review dispatch and resume (F1).
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

Scores and actual platform coverage are recorded in VALIDATION.md after independent
review; this version entry is not an external four-party approval.

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
- Add Bats/ShellCheck CI, a fixed training ground, a complete example and MIT license.

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
