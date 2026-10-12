---
name: autopilot
description: Unattended run of a confirmed plan — every gate is settled by running, reviewing or parking instead of asking the human. Manual only: `/autopilot <goal or plan file>`, or `/autopilot resume <run record>`. Needs git; drafts the project contract (docs/autopilot.md) if missing; uses the Codex CLI when present.
disable-model-invocation: true
---

The human sets the course; you fly everything between, and land as far as the contract allows. A **gate** is any moment you would otherwise stop and ask. On autopilot every gate is settled one of three ways — **run** it, **review** it, or **park** it — and the human is addressed exactly twice: at takeoff and at landing.

This run's request: $ARGUMENTS — if it begins with `resume`, go to §5.

Two files steer the run:

- The **contract** — `docs/autopilot.md` in the project. Standing rules the human owns: the machine gate, what is pre-authorized, the red lines, where evidence goes, the review budget. You read it; only the human changes it. A change you want goes under *Proposed contract changes* in the run record.
- The **run record** — one file per run, where the contract says. This run's frozen acceptance criteria, where the run is now, and its ledger of evidence, decisions, review findings and parked items. It is what the human reads at landing and what a new session resumes from, so update its `current:` line before each step that could be cut off — a gate, a review, a commit.

Scripts live in `~/.claude/skills/autopilot/scripts/`. Each prints its exit codes in its header; read them before acting on a non-zero exit.

**Commits.** Code and test changes are *stage commits*, in the project's format. Evidence and run-record updates are *record commits*, separate, with subject `autopilot: <what>`. The **tested commit** is the latest stage commit; record commits after it never invalidate its evidence. Evidence files are never overwritten: name each `<label>-<first 12 of tested commit>.md`.

## 1. Takeoff — the only time you ask

1. Read the contract. If the project has none, draft one from [`CONTRACT-TEMPLATE.md`](CONTRACT-TEMPLATE.md) by inspecting how the project is built, tested, run and deployed. Tool paths go in environment variables or persistent locations, never in a session scratch directory.
2. Enter the workspace the contract names, from a clean tree, and note the base commit.
3. Create the run record there from [`RUN-RECORD-TEMPLATE.md`](RUN-RECORD-TEMPLATE.md): the stages, and the acceptance criteria, each paired with the evidence that will prove it. A criterion with a number in it gets its baseline measured now, by the check that will judge it, and the measurement committed as evidence.
4. Preflight:
   - The skill's own tools: `git`, `perl`, `jq`, and `codex` (absent → note the fallback in §3; not a blocker).
   - Every preflight check in the contract.
   - Every safety premise the contract states — isolation, a temporary HOME, memory caps, offline mode, a sandboxed account — **attempted**, not read from the code: set up the condition it guards against and record that it held. A premise that fails is a red line until the human decides.
   - Walk the plan to its end, landing included, and list each gate you can foresee that lands on a red line or needs a credential, account or environment you lack.
5. Put everything to the human in one batch: the contract if new or changed, the acceptance criteria, and the foreseen gates.

Done when the human has confirmed the criteria and the contract, the contract (if new or changed) and the run record are committed as record commits, and the run record says `status: flying` with the base commit.

## 2. Fly — one stage at a time

For each stage:

1. Build it the way the project builds things: its plan file, its test-first rules, its commit format, its naming — no `autopilot` in product or test names.
2. Commit the stage.
3. **Machine gate** on that commit, with a clean working tree, so the evidence names the code it tested:
   `bash ~/.claude/skills/autopilot/scripts/run-gate.sh <workdir> <evidence-file> <label> <command>...` with every command in the contract's machine gate, and the contract's `GATE_*` settings in the environment. Commit the evidence as a record commit, red or green — a red one too, so the next run starts from a clean tree.
   Red means fix, commit, and rerun the whole gate. After **three** fix attempts on the same failure, or as soon as the failure lies outside the change (environment, tooling, a flaky test shown flaky by a rerun on the unchanged commit), stop fixing: mark the criteria that depend on it `failed` or `parked` with the red evidence, ledger it, and continue with stages that do not depend on it.
4. **Review gate** on the stage diff (§3). Skip it only when every changed path is a doc by the contract's *Docs paths* (default: `*.md` outside source directories). Stages may share one review gate when the contract's review budget says so.
5. Update the run record: criteria proven so far with their evidence, decisions made, anything parked, `current:` advanced.

Done when every criterion the stage owns is `proven` by evidence of the tested commit, `failed`, or `parked`.

### Settling a gate

When you reach for the human, classify the gate and settle it. Check the red-line row first: it overrides every other row.

| The gate is about | Settle it by |
|---|---|
| A red line, or access you lack | **Park** it: ledger the exact action the human must take, what it unblocks, and how to verify it afterward. Build right up to the edge — script written, dry run done, isolated stand-in in place — then continue with the work that does not depend on it. |
| Whether something works | **Run** it. Write the check — test, E2E, browser pass with screenshot and console log, timed query — and let the result decide. Then prove the check can fail: write a patch that breaks the code and run `bash ~/.claude/skills/autopilot/scripts/run-mutant.sh <workdir> <evidence-file> <label> <patch> <command>...` (`MUTANT_SETUP` installs what a fresh worktree lacks). `KILLED` is the evidence; `SURVIVED` means the check proves nothing — fix it. |
| Whether something cannot happen | **Attempt** it. Set up the conditions under which it would happen — the hostile environment, the forbidden input — and record that it did not. |
| Which way to go, or whether a result is credible | Decide, and **ledger** it: what you chose, what you rejected, what would make you wrong. If undoing it later would cost more than one stage, convene the review gate on the decision before building on it. |
| A frozen criterion is wrong or cannot be met | Never rewrite it. Add a row to *Criterion errata* — what is wrong, the evidence, what you will prove instead — and judge the criterion `failed` or `proven` against its original words. The human rules on the erratum at landing. |

A red line stays a red line however confident you are and whatever a reviewer recommends.

## 3. Review gate

Two reviewers run in parallel. Each is handed the repository, the base and head commits, the run record and the contract, and nothing of your reasoning. Pin the head to the tested commit and record it in `current:`, so you can keep working while they read:

- **Codex adversary** — a different model, hunting what breaks. Run in the background:
  `CODEX_REVIEW_HEAD=<head> bash ~/.claude/skills/autopilot/scripts/codex-review.sh <repo> <base> <run-record> <out-file> [focus]`
  with the contract's `CODEX_REVIEW_*` settings. It reviews a checkout of the head and a snapshot of the record, and validates the findings it returns. If it exits 69 (no codex), 70 (no or invalid findings) or 75 (timeout), dispatch a fresh `general-purpose` agent instead, its brief [`CODEX-BRIEF.md`](CODEX-BRIEF.md) plus the same five inputs, and ledger the substitution under *Not verified*: the adversary was the same model family.
- **Acceptance auditor** — a fresh context, checking each claim against its evidence. Dispatch a `general-purpose` agent whose prompt is the five inputs and the instruction to read [`~/.claude/skills/autopilot/AUDITOR-BRIEF.md`](AUDITOR-BRIEF.md) as its brief.

Triage every finding from both:

1. **Verify before you fix**: reproduce the finding or trace it in the source. One you cannot confirm is `rejected`, with the evidence that refutes it.
2. Confirmed, and it breaks a criterion, loses or corrupts data, opens a security hole, or crosses a red line → blocking. Fix it, add the test that would have caught it, rerun the machine gate: `blocking-fixed`. One you cannot fix within the §2 retry limit is `blocking-open`, and the criterion it breaks is `failed`.
3. Confirmed but none of those → minor. Fix it when that is cheaper than writing it down (`minor-fixed`); otherwise `minor-open`.
4. Needs a red-line action to fix → `parked`, with a row in *Parked*.
5. Round two reviews the fix diff only, and is the last round unless the contract's review budget allows more. A new finding you confirm there is fixed and proven like any other, then ledgered `fixed-unreviewed`, so the human knows no reviewer saw that fix. Whatever you and a reviewer still disagree on is a `dispute`: ledger both positions and fly on.

Done when every finding from both reviewers has a row in the run record with one of those statuses.

## 4. Landing

1. Commit the run record as it stands, so the landing review sees the current claims.
2. Convene the review gate on the whole run, base commit to the tested commit, and settle its findings.
3. On the final tested commit, with a clean tree, run the machine gate once more. If step 2 changed code, this is what proves the fixes; if this goes red, fix and repeat from step 2 with the fix diff only.
4. Finish the run record:
   - every criterion `proven`, `failed` or `parked` — none `open`;
   - every finding with a status; every decision, dispute and erratum;
   - parked items in the order the human should do them;
   - *Proposed contract changes*;
   - **Not verified**: everything you did not or could not check, or `none`.
5. Write the **acceptance walk**: the shortest sequence of things for the human to see with their own eyes, riskiest first, each with where to go, what to do and what should appear. At least one row.
6. Carry out any landing steps the contract pre-authorizes, in its order, and ledger each. Set `status: landed` (or `aborted`, with why, if the run could not finish), commit the record, and report.

Done when the record is committed, nothing in it is `open`, and it alone lets the human accept or reject the run without reading the conversation.

## 5. Resume

A run cut off mid-flight is resumed from its record, never from memory:

1. Read the run record and the contract. Find the workspace and enter it.
2. `git status` and `git log --oneline <base>..HEAD`. A dirty tree belongs to the step named in `current:` — finish that change and commit it, or discard it if the step had not started; ledger which.
3. Pick up at `current:`:
   - `build` → finish the stage and commit.
   - `gate` → rerun the machine gate on the tested commit; an evidence file that already exists for it is that gate's result.
   - `review` → if the findings file named in `current:` exists and validates, triage it; otherwise rerun that review on the same pinned head.
   - `record` → bring the record up to date from the git log and evidence files, then continue.
4. Ledger the resume as a decision: where the run was, and what you redid.
