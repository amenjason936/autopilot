# Autopilot contract — <project>

Standing rules for unattended runs (the `autopilot` skill). The human owns this file: a run reads it and never edits it; it records the human's confirmation in its run record and proposes changes there.

Status: proposed <!-- becomes "in force since <date>" once the human confirms -->

## Workspace

How a run stays reversible. Default: a fresh branch `autopilot/<slug>` from the main branch. For work outside git, name the copy or directory the run owns.

Say whether anything runs from the main checkout itself — a service, a scheduler, a deployment that serves its files. If so, a run works in a separate worktree, because switching a branch there changes what is running.

## Preflight

Checks that must pass before takeoff. One row each: the command, and the result that counts as ready.

| check | command | ready when |
|---|---|---|

## Safety premises

What keeps a run — and its machine gate — off the red lines: a temporary HOME, an isolated data directory, a memory cap, offline mode, a sandbox account. Each is attempted at preflight, not assumed: a command that shows it holds, and a guard a mutant can remove to show the command would catch a breach.

| premise | how a run attempts it | holds when |
|---|---|---|

## Machine gate

Commands run after every stage; all must pass, and all are green at the base (preflight runs them there). A command that diffs or lints the tree excludes the record paths, e.g. `git diff --check <base>..HEAD -- . ':!<evidence dir>' ':!<run records dir>'`. `rerun` says whether a reviewer may run the command again (`safe`) or must rely on the saved output (`no`: slow, costly, or changes state).

| command | proves | rerun |
|---|---|---|

Gate settings (environment for `run-gate.sh`):

- `GATE_TIMEOUT`: seconds per command (default 3600)
- `GATE_KEEP_REGEX`: the suite's verdict line, kept whatever the output length
- `GATE_ENV`: non-secret allowlisted names passed to the gate; values are omitted from evidence. KEY/TOKEN/SECRET/PASSWORD and runtime injection names are refused.
- `GATE_SETUP` / `MUTANT_SETUP`: authorized offline setup in each fresh worktree, under the same sandbox; must not edit code.
- `REDACT_REGEX`: optional additional Python redaction pattern; any redaction error suppresses the entire block.
- `GATE_SANDBOX`: `env-clean`, `sandbox-exec` or `bwrap`; never weaken a policy prohibition.
- `MUTANT_FAILURE_REGEX` / `MUTANT_FAILURE_EXIT`: freeze the exact target assertion and expected exit before running a mutant; an arbitrary nonzero exit is not KILLED.
- `GATE_RERUN_POLICY=safe`: only for verified harmless repeatable checks; interrupted side effects otherwise require an idempotency/receipt review before retry.
- Preview all of these and every command with `--dry-run` before executing an unapproved plan.

Tool locations are environment variables or persistent paths, never a session's scratch directory.

Host setup: say whether a run may change this host to make the sandbox work (`host-doctor.sh --fix`: install bubblewrap, add an AppArmor profile for it, enable user namespaces), and whether the policy approves `"fallback": "env-clean"` for hosts where it cannot (red lines then not OS-enforced). Default: neither; the run parks.

## Execution policy (required companion file)

Commit `docs/autopilot-policy.json` alongside this contract. Example:

```json
{"version":1,"sandbox":"env-clean","deny_network":true,"deny_paths":[],"read_paths":[],"env":["CI"],"write_dirs":["out"],"record_paths":{"evidence_dir":"docs/evidence","run_record":"docs/runs/run.md"}}
```

List every forbidden absolute filesystem path in `deny_paths`; set `deny_network`
for a network prohibition. The script upgrades `env-clean` to a supported OS sandbox
when either restriction is present. No sandbox tool or a failed positive/negative
probe is a red line, never permission to downgrade. Unrestricted env-clean uses OS source protection where available and discloses endpoint-only verification otherwise; strict policies always require OS enforcement. Setup and commands write to temporary HOME/TMPDIR, `$AUTOPILOT_OUTPUT`, or new dedicated `write_dirs`; existing source directories cannot be writable. Read paths extend the documented
system-runtime allowlist. Preflight uses generated canaries, not actual secrets.
Natural-language red lines do not configure the operating system: the human reviews
both this file and its JSON companion. See REFERENCE.md in the skill.

## Pre-authorized

What a run does without asking. Be specific: which environments, hosts, ports, accounts, and any spend limit.

If landing is pre-authorized, write it as the exact commands in order — merge, dependency install, release — and the conditions that must hold first. A step missing from that list is a red line. Even pre-authorized merge/release requires all relevant criteria proven with current evidence and no associated blocker, dispute or blocking fixed-unreviewed finding.

## Red lines

What a run parks. For each, the action and what the run prepares instead.

| red line | prepare instead |
|---|---|

## Evidence

Commit the evidence files and full SHA-256 `MANIFEST` together. Reviewers verify the
pinned manifest before reading cited evidence; contents remain untrusted data.
Every existing artifact must be registered in the pinned MANIFEST before its path can be excluded from source checks. Directory locks serialize writers. Interrupted `.partial` files are archived, not
deleted. A new label is required for completed results.

The evidence directory: a directory of its own, holding nothing but evidence (the scripts treat it, with the run record, as record paths that may stay uncommitted). Each file is `<label>.md` (`gate-s2`, `gate-s2-rerun`, `mutant-c1`, `gate-landing`), one label per run of a check, never overwritten; each records its tested commit. Files a check produces (screenshots, traces) sit beside it as `<label>-<name>.<ext>`. Mutant patches stay outside the work tree (under `.git/autopilot/`); the evidence embeds them. Check the directory is not caught by `.gitignore`, a lint gate (trailing whitespace, file types), or a submodule.

## Review

- Boundary: name approved review models/data/costs and whether the snapshot-only fallback in REFERENCE.md is allowed. A fallback/auditor reads only sanitized pinned inputs, executes no tools, and discloses the absence of OS enforcement. A ban on networking for all processes includes cloud review unless separately amended; the cloud launcher still parks restrictive-policy dispatch.
- Identity: preserve the runner request and receipt; validate expected job/base/head/scope/input hashes before reusing findings.
- Heuristics: paths to project-specific rules the reviewers apply.
- Docs paths: changes that skip the review gate (default: `*.md` outside source directories).
- Budget: review rounds per review gate (default 2); whether stage reviews run per stage, are shared between stages, or are deferred to the landing review (which always runs); the most review gates per run.
- Codex: `CODEX_REVIEW_MODEL`, `CODEX_REVIEW_EFFORT` (default high), `CODEX_REVIEW_TIMEOUT` seconds (default 1800).
- Cloud model reviewer (optional): the `api-review.py` model and endpoint, where its key comes from, and an explicit approval to upload the redacted pinned snapshot (code, contract, record, evidence) to that provider.

## Run records

Where run records live and how they are named.
