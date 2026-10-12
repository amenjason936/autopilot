---
name: autopilot
description: Unattended run of a confirmed plan — every gate is settled by running, reviewing or parking instead of asking the human. Manual only: `/autopilot <goal or plan file>`, or `/autopilot resume <run record>`. Needs git; drafts the project contract (docs/autopilot.md) if missing; uses the Codex CLI when present.
disable-model-invocation: true
---

The human sets the course; you fly everything between, and land as far as the contract allows. A **gate** is any moment you would otherwise stop and ask. On autopilot every gate is settled one of three ways — **run** it, **review** it, or **park** it — and the human is addressed exactly twice: at takeoff and at landing.

This run's request: $ARGUMENTS — if it begins with `resume`, go to §5; if it is empty, ask for the goal as part of takeoff.

Two files steer the run:

- The **contract** — `docs/autopilot.md` in the project. Standing rules the human owns: the machine gate, what is pre-authorized, the red lines, where evidence goes, the review budget. You read it and never edit it; a change you want goes under *Proposed contract changes* in the run record.
- The **run record** — one file per run, where the contract says. This run's frozen acceptance criteria, where the run is now (`current:`), and its ledger. It is what the human reads at landing and what a new session resumes from: update `current:` before every step that could be cut off.

**Scripts** live in `~/.claude/skills/autopilot/scripts/`; each documents its exit codes in its header comment. Export `AUTOPILOT_RECORD=<run record>` for all of them.

**Record paths and commits.** The run record and the evidence directory are *record paths*: they may stay uncommitted while you work, and the scripts ignore them when checking the tree is clean. Everything else is code. *Stage commits* hold code only, in the project's format; *record commits* hold record paths only, subject `autopilot: <what>`, made at the end of each stage and before each review. The **tested commit** is the latest commit that changed code; the scripts compute it and write it into every evidence file. Evidence is never overwritten: each run of a check gets its own label and file `<label>.md` (`gate-s2`, `gate-s2-rerun`, `mutant-c1`).

**Current evidence.** Evidence is current when no code changed between its tested commit and the run's tested commit (`git diff --stat <its> <run's>` outside record paths is empty). A mutant record stays current while the files it mutated are unchanged.

## 1. Takeoff — the only time you ask

1. Enter the workspace — the contract's, or by default a new branch `autopilot/<slug>` from the main branch. The commit it starts from is the base.
2. Read the contract. If the base has none but another branch does, start from that one as a changed contract. If there is none at all, draft one from [`CONTRACT-TEMPLATE.md`](CONTRACT-TEMPLATE.md) by inspecting how the project is built, tested, run and deployed. Gate commands that diff or lint the tree (`git diff --check`, linters) must exclude the record paths.
3. Create the run record from [`RUN-RECORD-TEMPLATE.md`](RUN-RECORD-TEMPLATE.md): the stages, and the acceptance criteria, each paired with the evidence that will prove it. A criterion with a number in it gets its baseline measured now, by the check that will judge it.
4. Preflight, each result into the record's *Preflight* table:
   - `git`, `perl`, `jq`, `codex` on PATH (no codex → the §3 fallback; not a blocker);
   - every preflight check in the contract;
   - the full machine gate at the base (label `gate-base`). A command already red there is a foreseen gate: the human decides whether the run fixes it first, drops it, or treats it as known-red;
   - every safety premise in the contract, **attempted**: set up what it guards against, record that it held, and show the attempt would have caught a breach. A premise that fails is a red line;
   - walk the plan to its end, landing included, and list each gate you can foresee that lands on a red line or needs a credential, account or environment you lack.
5. Put everything to the human in one batch: the contract if new or changed, the acceptance criteria, and the foreseen gates.

Done when the human has confirmed. Then write their confirmation into the contract (`Status: in force since <date>`, the only contract edit a run makes), commit it and the record, and set `status: flying`. A new contract also goes under *Proposed contract changes*, to reach the main branch.

## 2. Fly — one stage at a time

For each stage:

1. Build it the way the project builds things: its plan file, its test-first rules, its commit format, its naming — no `autopilot` in product or test names. Commit it.
2. **Machine gate**: `bash ~/.claude/skills/autopilot/scripts/run-gate.sh <workdir> <evidence-dir>/<label>.md <label> <command>...` with every command in the contract's machine gate and its `GATE_*` settings.
   Red means fix, commit, and rerun the whole gate under a new label. After **three** fix attempts on one failure, or once the failure lies outside the change (environment, tooling, a test shown flaky by a rerun on the unchanged commit), stop: mark the dependent criteria `failed` or `parked` with the red evidence, ledger it, and continue with stages that do not depend on it.
3. **Review gate** on the stage diff (§3), unless every changed path is in the contract's *Docs paths*, or the contract's review budget defers stage reviews to landing.
4. Update the record — criteria proven with their evidence, decisions, anything parked, `tested commit:` and `current:` — and make the stage's record commit.

Done when every criterion the stage owns is `proven` by current evidence, `failed`, or `parked`.

### Settling a gate

When you reach for the human, classify the gate and settle it. Check the red-line row first: it overrides every other row.

| The gate is about | Settle it by |
|---|---|
| A red line, or access you lack | **Park** it: ledger the exact action the human must take, what it unblocks, and how to verify it afterward. Build right up to the edge — script written, dry run done, isolated stand-in in place — then continue with the work that does not depend on it. |
| Whether something works | **Run** it. Write the check — test, E2E, browser pass with screenshot and console log, timed query — commit it, and let the result decide. Then prove it can fail, once for each clause of the criterion: break the code, save `git diff` under `$(git rev-parse --git-common-dir)/autopilot/<label>.patch`, restore the code, and run `run-mutant.sh <workdir> <evidence-dir>/<label>.md <label> <patch> <command>...`. `KILLED` is the evidence; `SURVIVED` means the check proves nothing — fix it; `INCONCLUSIVE` means fix `MUTANT_SETUP` or the patch. |
| Whether something cannot happen | **Attempt** it. Set up the conditions under which it would happen — the hostile environment, the forbidden input — and record that it did not. |
| Which way to go, or whether a result is credible | Decide, and **ledger** it: what you chose, what you rejected, what would make you wrong. If undoing it later would cost more than one stage, convene the review gate on the decision before building on it. |
| A frozen criterion is wrong or cannot be met | Never rewrite it. Add a *Criterion errata* row — what is wrong, the evidence, what you will prove instead — and judge the criterion against its original words. The human rules on the erratum at landing. |

A red line stays a red line however confident you are and whatever a reviewer recommends.

## 3. Review gate

Set `current:` to the review, make the record commit, and pin the head to HEAD — reviewers see code, evidence and record as of that commit while you keep working; then add the head to `current:`. The base is the previous review's head (the run's base for the first review and for landing). Each reviewer gets the repository, base and head, run record, contract and scope (`stage <n>` or `landing`) — nothing of your reasoning. Findings files go under `$(git rev-parse --git-common-dir)/autopilot/`, outside the work tree.

- **Codex adversary** — a different model, hunting what breaks. Run in the background:
  `CODEX_REVIEW_HEAD=<head> bash ~/.claude/skills/autopilot/scripts/codex-review.sh <repo> <base> <run-record> <out-file> "scope: <stage n | landing>"` with the contract's `CODEX_REVIEW_*` settings.
  Any other non-zero exit than 64–66 (fix the call) — no codex, a failure, a timeout, invalid findings — means fall back: run it again with `--prompt-only` as the first argument, give that output as the whole prompt to a fresh `general-purpose` agent, and check the file it writes with `validate-findings.sh`. Ledger under *Not verified* that the adversary was the same model family.
- **Acceptance auditor** — a fresh context, checking each claim against its evidence. Dispatch a `general-purpose` agent whose prompt is the inputs above, an output file beside the findings files, and the instruction to read `~/.claude/skills/autopilot/AUDITOR-BRIEF.md` as its brief.

Triage every finding from both. A reviewer that returns none gets one row with status `approve`, so every review is on record.

1. **Verify before you fix**: reproduce the finding or trace it in the source. One you cannot confirm is `rejected`, with the evidence that refutes it.
2. Confirmed, and it breaks a criterion, loses or corrupts data, opens a security hole, or crosses a red line → blocking. Fix it, add the test that would have caught it, rerun the machine gate: `blocking-fixed`. Not fixable within the §2 retry limit → `blocking-open`, and the criterion it breaks is `failed`.
3. Confirmed but none of those → `minor-fixed` when fixing is cheaper than writing it down, otherwise `minor-open`.
4. Needs a red-line action to fix → `parked`, with a row in *Parked*.
5. Round two reviews the fix diff only, and is the last round unless the review budget allows more. A new finding you confirm there is fixed and proven like any other, then ledgered `fixed-unreviewed` with its severity in the note. What you and a reviewer still disagree on is a `dispute`: ledger both positions and fly on.

Done when every finding has a row in the record with one of those statuses, and the findings files are copied into the evidence directory.

## 4. Landing

Before each step, set `current: landing <step>`.

1. Bring every criterion's evidence current: rerun, under new labels, each check whose evidence is not current. A check the contract marks `rerun: no` is ledgered under *Not verified* instead.
2. Run the machine gate on the tested commit (label `gate-landing`). Red → fix within the §2 retry limit, then rerun as `gate-landing-2`, ….
3. Convene the review gate on the whole run (scope `landing`), base to HEAD, and settle its findings. If that changed code, repeat steps 1–2 for what changed, and round two reviews the fix diff only — within the retry limit and the review budget; when either runs out, mark the affected criteria `failed`.
4. Complete every section of the run record. Nothing is `open`; *Not verified* says `none` if so.
5. Write the **acceptance walk**: the shortest sequence of things for the human to see with their own eyes, riskiest first, each with where to go, what to do and what should appear.
6. Set `status: landed` (or `aborted`, with why) and make the final record commit. Then carry out any landing steps the contract pre-authorizes, in its order — before each, check it has not already taken effect (merged? tag exists?). Report, including the outcome of each landing step.

Done when the record is committed, nothing in it is `open`, and it alone lets the human accept or reject the run without reading the conversation.

## 5. Resume

A run cut off mid-flight is resumed from its record, never from memory:

1. Read the run record and the contract; enter the workspace; `git status` and `git log --oneline <base>..HEAD`. Uncommitted record paths are kept. Uncommitted code belongs to the step in `current:`: finish and commit it, or discard it if that step had not started.
2. Pick up at `current:`:
   - `takeoff` → restart §1; nothing was confirmed.
   - `build` → finish the stage and commit.
   - `gate <label>` → `<label>.md` is that gate's result; only a `.partial` means it was cut off — rerun it (the script replaces the partial).
   - `review` (or `landing 3`) → triage a findings file named in `current:` that validates; rerun any other reviewer on the same pinned head. With no head in `current:` yet, start the review over.
   - `record` → bring the record up to date from the git log and evidence files, then make the record commit.
   - `landing <step>` → resume there; a pre-authorized step is repeated only if it has not already taken effect.
3. Ledger the resume as a decision: where the run was, and what you redid.
