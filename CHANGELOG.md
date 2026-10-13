# Changelog

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

The four-party numerical re-rating and remote CI are external acceptance steps;
this changelog does not imply they have passed.

## Prototype — through ce24999

Corrections from the token-watcher trials: record-path separation, portable temp
files, timeout handling, and baseline checks for mutation runs. No release tag was
present at the start of this upgrade.
