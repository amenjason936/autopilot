# <run title>

- status: planned <!-- planned → flying → landed -->
- workspace: autopilot/<slug>
- base: <commit>
- contract: docs/autopilot.md

## Goal

What the human asked for, in their words.

## Acceptance criteria

Frozen at takeoff. A run changes `status` and `evidence`, never the criterion.

| id | criterion | proven by | status | evidence |
|---|---|---|---|---|
| C1 | | | open | |

`status` is `open`, `proven` or `parked`.

## Stages

1. [ ] <stage> — owns C1

## Ledger

### Decisions

| id | stage | chose | rejected | wrong if |
|---|---|---|---|---|

### Review findings

| id | round | reviewer | finding | status | note |
|---|---|---|---|---|---|

`status` is `blocking-fixed`, `minor-fixed`, `minor-open`, `fixed-unreviewed`, `parked`, `rejected` or `dispute`. The note holds the commit that fixed it or the evidence that refutes it; a dispute states both positions.

### Parked

In the order the human should do them.

| id | needs | exact action | unblocks | verify afterward |
|---|---|---|---|---|

### Not verified

Everything the run did not or could not check, and why.

## Acceptance walk

Riskiest first.

| # | where | do | should see |
|---|---|---|---|
