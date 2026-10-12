---
name: autopilot
description: Unattended run of a confirmed plan — every gate is settled by running, reviewing or parking instead of asking the human.
disable-model-invocation: true
---

The human sets the course and lands the plane; you fly everything between. A **gate** is any moment you would otherwise stop and ask. On autopilot every gate is settled one of three ways — **run** it, **review** it, or **park** it — and the human is addressed exactly twice: at takeoff and at landing.

Two files steer the run:

- The **contract** — `docs/autopilot.md` in the project. Standing rules the human owns: the machine gate, what is pre-authorized, the red lines, where evidence goes. You read it; only the human changes it.
- The **run record** — one file per run, where the contract says. This run's frozen acceptance criteria and its ledger of evidence, decisions, review findings and parked items. It is what the human reads at landing. It is also where a new session resumes a run that was cut off, so it is current at the end of every stage.

## 1. Takeoff — the only time you ask

1. Read the contract. If the project has none, draft one from [`CONTRACT-TEMPLATE.md`](CONTRACT-TEMPLATE.md) by inspecting how the project is built, tested, run and deployed.
2. Create the run record from [`RUN-RECORD-TEMPLATE.md`](RUN-RECORD-TEMPLATE.md): the stages, and the acceptance criteria, each paired with the evidence that will prove it.
3. Preflight: execute every preflight check in the contract, then walk the plan to its end, landing included, and list each gate you can foresee that lands on a red line or needs a credential, account or environment you lack.
4. Put everything to the human in one batch: the contract if new or changed, the acceptance criteria, and the foreseen gates.

Done when the human has confirmed the criteria and the contract, you are in the workspace the contract names, and the run record says `status: flying` with the base commit.

## 2. Fly — one stage at a time

For each stage:

1. Build it the way the project builds things: its plan file, its test-first rules, its commit format.
2. Commit the stage.
3. **Machine gate** on that commit, with a clean working tree, so the evidence names the code it tested:
   `bash ~/.claude/skills/autopilot/scripts/run-gate.sh <workdir> <evidence-file> <label> <command>...` with every command in the contract's machine gate. Red means fix, commit, and rerun the whole gate. Commit the evidence on its own.
4. **Review gate** on the stage diff (§3). Docs-only stages skip it.
5. Update the run record: criteria proven so far with their evidence, decisions made, anything parked.

Done when every criterion the stage owns is `proven` by evidence from the stage's final commit, or `parked`.

### Settling a gate

When you reach for the human, classify the gate and settle it:

| The gate is about | Settle it by |
|---|---|
| Whether something works | **Run** it. Write the check — test, E2E, browser pass with screenshot and console log, timed query — and let the result decide. Then break the thing on purpose and watch the check go red: a check that cannot fail proves nothing. |
| Whether something cannot happen | **Attempt** it. Set up the conditions under which it would happen — the hostile environment, the forbidden input — and record that it did not. |
| Which way to go, or whether a result is credible | Decide, and **ledger** it: what you chose, what you rejected, what would make you wrong. If undoing it later would cost more than one stage, convene the review gate on the decision before building on it. |
| A red line, or access you lack | **Park** it: ledger the exact action the human must take, what it unblocks, and how to verify it afterward. Build right up to the edge — script written, dry run done, isolated stand-in in place — then continue with the work that does not depend on it. |

A red line stays a red line however confident you are and whatever a reviewer recommends.

## 3. Review gate

Two reviewers run in parallel. Each is handed the repository, the base and head commits, the run record and the contract, and nothing of your reasoning. Pin the head to a commit, so you can keep working while they read:

- **Codex adversary** — a different model, hunting what breaks. Run in the background:
  `CODEX_REVIEW_HEAD=<head> bash ~/.claude/skills/autopilot/scripts/codex-review.sh <repo> <base> <run-record> <out-file> [focus]`
- **Acceptance auditor** — a fresh context, checking each claim against its evidence. Dispatch the `acceptance-auditor` agent with those five inputs as its whole prompt. In a session that does not list that agent, dispatch `general-purpose` with the same inputs and the instruction to read `~/.claude/agents/acceptance-auditor.md` as its brief.

Triage every finding from both:

1. **Verify before you fix**: reproduce the finding or trace it in the source. One you cannot confirm is `rejected`, with the evidence that refutes it.
2. Confirmed, and it breaks a criterion, loses or corrupts data, opens a security hole, or crosses a red line → `blocking`. Fix it, add the test that would have caught it, rerun the machine gate.
3. Confirmed but none of those → `minor`. Fix it when that is cheaper than writing it down; otherwise ledger it open.
4. Round two reviews the fix diff only, and is the last round. A new finding you confirm there is fixed and proven like any other, then ledgered `fixed-unreviewed`, so the human knows no reviewer saw that fix. Whatever you and a reviewer still disagree on is a `dispute`: ledger both positions and fly on.

Done when every finding from both reviewers has a row in the run record with its status.

## 4. Landing

1. On the final commit with a clean working tree, run the machine gate once more.
2. Convene the review gate on the whole run, base commit to HEAD.
3. Finish the run record: criteria with evidence, decisions, disputes, parked items in the order the human should do them, and **not verified** — everything you did not or could not check.
4. Write the **acceptance walk**: the shortest sequence of things for the human to see with their own eyes, riskiest first, each with where to go, what to do and what should appear.
5. Set `status: landed` and report.

Done when the run record alone lets the human accept or reject the run without reading the conversation.
