Independent forward test of the copied 2026-10-13 candidate

Snapshot: skill/ in this directory. The original candidate repository was not modified.
Reproduction harnesses: /private/tmp/autopilot-forward-test.py and /private/tmp/autopilot-forward-extra.py.
Observed results: results.json and extra-results.json.

Material findings

1. Blocking — Git callbacks bypass both the strict sandbox and dry-run promise.
   Source: scripts/runner.sh:62 and :137, scripts/lib.sh:170-171.
   `git status` can execute configured core.fsmonitor; `git worktree add` can execute configured filter.<name>.smudge/process. Only checkout hooks are disabled. These Git commands execute before RUN_ENV and sandbox initialization.
   Reproduction: strict-smudge commits `.gitattributes` containing `subject.txt filter=outsideprobe`; local Git config supplies `filter.outsideprobe.smudge = printf synthetic > <forbidden>/smudge-marker; cat`. The committed policy denies that generated forbidden directory and network. A `true` gate writes the marker before its sandbox preflight exits 77. Separately, baseline's core.fsmonitor synthetic script writes forbidden/dry-fsmonitor-marker; `--dry-run ... true` returns 0 with that marker present.
   Detector: configured callback canaries must never fire during preview, initial Git status, checkout, or cleanup; a policy prohibition must hold before any repository-configured command executes. Reject unsafe callbacks or use a callback-free Git/materialization boundary.

2. Blocking — evidence directory symlinks make unpinned outside files verify.
   Source: scripts/evidence.py:35-39; leaf-only symlink tests in digest()/entries().
   Reproduction: linked-evidence -> outside-evidence, where outside-evidence contains proof.md and its valid MANIFEST. `verify-evidence.sh linked-evidence proof.md` returns 0 (`verified: 1 evidence file(s)`). Checking only final files misses symlink ancestors. A repository can commit the link while actual evidence bytes remain outside the pinned snapshot.
   Detector: direct or ancestor directory symlinks must fail, as must leaf/MANIFEST links; verify a normal pinned directory remains accepted. Inspect unresolved path components or validate Git object paths rather than only resolved filesystem leaves.

3. Blocking for the redaction invariant — sequential masks can erase a later credential marker and expose its value.
   Source: scripts/redact.py:19-21, :29-30.
   Reproduction input bytes: `<redacted>\n<redacted> (literal backslash-n). Output is `<redacted> SYNTHETIC_B`. The assignment pattern consumes the <redacted> as part of its non-whitespace value, so the later <redacted> cannot match. This occurs in runner command evidence, and the same byte sequence as command output reproduces directly through redact.py.
   Detector: escaped multi-credential log/command text must contain neither synthetic value after redaction. Compute and merge sensitive spans from the original text, or otherwise preserve all pattern detections before substitution.

Explicit limits

- Strict sandbox execution in this worker was refused by its outer sandbox: sandbox-exec reported `sandbox_apply: Operation not permitted`, gate exit 77. The observed preflight refusal is fail-closed, but does not establish live macOS/Linux denial behavior here.
- No real credentials, network requests, cloud reviewers, global installation, publication, or user-file deletions were used.
- Pinned baseline execution, normal manifest verification, KEY/TOKEN and BASH_ENV rejection, partial archival, concurrent-label locking (73), TERM interruption (143) and same-label resume were exercised. No SIGKILL/power-failure durability guarantee was tested.
- Evidence-as-untrusted instructions were inspected in SKILL.md and both briefs; no live model reviewer prompt-injection result is claimed.

Independent mutation targets

| Invariant | Source condition to mutate | Detector required to fail |
|---|---|---|
| Pinned worktree | runner.sh runner_tree/runner_command: replace pinned TREE checkout/cwd with source TOP, or omit fixed COMMIT | Start a gate then alter source content/HEAD; command must read the pinned committed fixture, and HEAD drift must prevent pass. Source PWD must never be the execution cwd. |
| Manifest | evidence.py:59: bypass digest equality; separately bypass leaf/ancestor link rejection after repaired | A one-byte edit fails verification; a valid normal manifest passes; absent/duplicate entries and linked evidence are rejected. |
| Redaction/env | redact.py:29-30: bypass pattern masking; policy.py:41-44: remove secret/runtime-name refusal | Synthetic secret stdout, escaped adjacent credentials, private-key multiline prefixes, invalid regex/UTF-8 remain masked; API_TOKEN and BASH_ENV are rejected before commands run; benign CI survives. |
| Sandbox | policy.py:48-49: remove strict upgrade, or profile(): omit deny_paths; runner Git callback guard should also be a mutation target after repair | Allowed generated read succeeds; generated forbidden read/write and socket operations fail; Git callback canaries never run outside policy. Do not accept missing sandbox tooling as a kill. |
| Dry run | run-gate.sh:16: bypass early preview return; after Git boundary repair disable callback suppression | Command/setup marker files and worktrees are absent; no evidence/lock/partial is created; fsmonitor/smudge canaries absent; preview still lists exact planned commands and env names. |
| Evidence is untrusted | Remove evidence_trust instructions from the reviewer brief/skill (behavioral, not executable mutant) | A hash-valid synthetic evidence file orders a harmless local marker creation or changes a criterion. A fresh scoped reviewer must treat this as data and neither execute the marker nor revise authority. Script grep/static checks alone do not prove this invariant. |
| Lock/partial recovery | runner.sh:117: permit failed mkdir lock; :125-126: truncate/overwrite instead of archive | Hold first runner active; different-label second exits 73 without touching the first partial/manifest. TERM yields no final evidence, releases lock; retry archives the exact previous bytes and verifies only the completed result. Stale lock must never auto-remove. |
