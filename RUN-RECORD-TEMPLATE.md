# <run title>

- status: planned <!-- planned → flying → landed | aborted -->
- workspace: autopilot/<slug>
- base: <full commit>
- tested commit: <full commit> <!-- latest commit that changed code; the scripts print it -->
- contract: docs/autopilot.md
- current: takeoff <!-- takeoff | stage <n> build | stage <n> gate <label> | stage <n> review r<k> head <sha> → <findings files> | stage <n> record | landing <step> -->

## Goal

What the human asked for, in their words.

## Preflight

| check | how | result | evidence |
|---|---|---|---|
| premise: tests never touch the real HOME | ran the suite with HOME read-only; then removed the guard and saw the suite fail | held | `premise-home.md` |

## Acceptance criteria

Frozen at takeoff. A run changes `status` and `evidence`, never the criterion; a criterion that turns out wrong gets an erratum below.

| id | criterion | proven by | status | evidence |
|---|---|---|---|---|
| C1 | `/api/export` streams 1 GB without exceeding 200 MB RSS | `npm run bench:export` with RSS sampling | open | |

`status` is `open`, `proven`, `failed` or `parked`. At landing none is `open`. `proven` cites current evidence and, for a check the run wrote, the mutant that proves it can fail (`gate-s2.md`, `mutant-c1.md`).

### Criterion errata

Append only. The human rules on each at landing.

| id | criterion | what is wrong | evidence | proving instead |
|---|---|---|---|---|

## Stages

1. [ ] <stage> — owns C1

## Ledger

### Decisions

| id | stage | chose | rejected | wrong if |
|---|---|---|---|---|
| D1 | 2 | stream with backpressure | buffer then write | a client reads slower than 1 MB/s |

### Review findings

| id | round | reviewer | finding | status | note |
|---|---|---|---|---|---|
| R1 | 1 | codex | export holds the DB cursor open on client abort | blocking-fixed | fixed a1b2c3d4e5f6, test `export aborts release cursor` |
| R2 | 2 | auditor | C1 evidence predates the fix | fixed-unreviewed | minor; regated as `gate-s2-rerun` |

`status` is one of:

- `blocking-fixed`, `blocking-open` — a blocking finding fixed, or not fixable within the retry limit (its criterion is `failed`)
- `minor-fixed`, `minor-open`
- `fixed-unreviewed` — found and fixed in the last round; no reviewer saw the fix (the note gives its severity)
- `parked` — the fix needs a red-line action; see *Parked*
- `rejected` — could not be confirmed; the note holds the refuting evidence
- `dispute` — the note states both positions

The note holds the commit that fixed it or the evidence that refutes it.

### Parked

In the order the human should do them.

| id | needs | exact action | unblocks | verify afterward |
|---|---|---|---|---|
| P1 | production DB credentials | `psql $PROD_URL -f migrations/0042.sql` | C3 | `select count(*) from exports_v2` returns > 0 |

### Proposed contract changes

What the run learned the contract should say. The human accepts or rejects each.

### Not verified

Everything the run did not or could not check, and why — or `none`.

## Acceptance walk

Riskiest first.

| # | where | do | should see |
|---|---|---|---|
