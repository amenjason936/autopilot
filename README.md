# autopilot

A [Claude Code](https://claude.com/claude-code) skill for running a confirmed plan unattended.

When you ask an agent to do a multi-step change, it usually stops at every
"should I…?" moment. On autopilot, each of those moments is a **gate**, and
every gate is settled one of three ways instead of asking you:

- **Run** it: write a check, commit it, and let the result decide. Then prove
  the check can fail by breaking the code on purpose (a mutant) and watching it
  go red.
- **Review** it: an adversarial reviewer (Codex, or a fresh Claude agent)
  hunts for what breaks, and an acceptance auditor checks every claim against
  its evidence.
- **Park** it: anything on a red line (push, deploy, publish, real user data,
  missing credentials) is prepared up to the edge and left for you, with the
  exact command and how to verify it afterward.

You are addressed exactly twice: at **takeoff**, to confirm the contract,
the acceptance criteria and the gates it can foresee, and at **landing**, to
accept or reject the result from a single run record.

## Install

```sh
git clone https://github.com/amenjason936/autopilot ~/.claude/skills/autopilot
```

The scripts are referenced at `~/.claude/skills/autopilot/scripts/`, so keep
that path.

### Requirements

- `git`, `bash` (3.2 or later, so the macOS default works), `perl`, `jq`.
  The scripts run on GNU/Linux and macOS (BSD userland).
- [Codex CLI](https://github.com/openai/codex) (optional): when present it is
  the adversarial reviewer, a different model from the author. Without it, a
  fresh Claude agent reviews instead, and the run records that the reviewer
  was the same model family.

## Use

The skill is manual only; Claude never starts it on its own.

```text
/autopilot <goal, or a path to a plan file>
/autopilot resume <path to a run record>
```

Run it in a git repository. At takeoff it:

1. Creates a workspace branch `autopilot/<slug>`.
2. Reads the project's contract, `docs/autopilot.md`, or drafts one from
   [`CONTRACT-TEMPLATE.md`](CONTRACT-TEMPLATE.md) if the project has none.
3. Writes a run record with frozen acceptance criteria.
4. Runs preflight: the machine gate at the base and the safety premises,
   each attempted rather than assumed.
5. Asks you to confirm everything in one batch.

After that it flies stage by stage, through landing, without asking.

## How it works

Two files steer a run:

- **The contract** (`docs/autopilot.md`): standing rules you own. It sets the
  machine-gate commands, what is pre-authorized, the red lines, where evidence
  goes, and the review budget. A run never edits it; it proposes changes in its
  run record instead.
- **The run record**: one file per run. It holds the frozen acceptance
  criteria, where the run is now (`current:`), the ledger of decisions,
  review findings and parked actions, and the acceptance walk for you to
  follow at landing. A run cut off mid-flight resumes from it, not from memory.

Every claim is backed by evidence that names the commit it tested:

| script | what it does |
|---|---|
| [`scripts/run-gate.sh`](scripts/run-gate.sh) | Runs the machine gate on committed code and writes the evidence file: tested commit, each command's exit status, duration and output tail. Has a per-command timeout that kills the whole process group. |
| [`scripts/run-mutant.sh`](scripts/run-mutant.sh) | Applies a patch that breaks the code in a throwaway worktree. Reports the check `KILLED` (it went red), `SURVIVED` (it proves nothing) or `INCONCLUSIVE`, after first requiring a green baseline. |
| [`scripts/codex-review.sh`](scripts/codex-review.sh) | Runs the Codex adversary in its read-only sandbox on a worktree pinned to the review head. With `--prompt-only`, it prints the prompt for a fallback reviewer instead. |
| [`scripts/validate-findings.sh`](scripts/validate-findings.sh) | Checks a findings file strictly against [`codex-findings.schema.json`](codex-findings.schema.json). |
| [`scripts/lib.sh`](scripts/lib.sh) | Shared helpers: timeouts, temp files, record-path handling, tested-commit lookup. |

Each script documents its usage, environment variables and exit codes in its
header comment.

## Files

| file | purpose |
|---|---|
| [`SKILL.md`](SKILL.md) | The skill itself: takeoff, fly, review gate, landing and resume. |
| [`CONTRACT-TEMPLATE.md`](CONTRACT-TEMPLATE.md) | Starting point for a project's `docs/autopilot.md`. |
| [`RUN-RECORD-TEMPLATE.md`](RUN-RECORD-TEMPLATE.md) | Starting point for each run record. |
| [`CODEX-BRIEF.md`](CODEX-BRIEF.md) | Brief for the adversarial reviewer. |
| [`AUDITOR-BRIEF.md`](AUDITOR-BRIEF.md) | Brief for the acceptance auditor. |

## Safety

A red line stays a red line however confident the run is and whatever a
reviewer recommends. Landing steps (merge, push, release) happen only if the
contract pre-authorizes them as exact commands; otherwise they are parked for
you. Reviewers inspect only, and are told not to open or quote secrets.
