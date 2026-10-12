# Autopilot contract — <project>

Standing rules for unattended runs (the `autopilot` skill). The human owns this file: a run reads it and never edits it.

Status: proposed <!-- becomes "in force since <date>" once the human confirms -->

## Workspace

How a run stays reversible. Default: a fresh branch `autopilot/<slug>` from the main branch. For work outside git, name the copy or directory the run owns.

Say whether anything runs from the main checkout itself — a service, a scheduler, a deployment that serves its files. If so, a run works in a separate worktree, because switching a branch there changes what is running.

## Preflight

Checks that must pass before takeoff. One row each: the command, and the result that counts as ready.

| check | command | ready when |
|---|---|---|

## Machine gate

Commands run after every stage; all must pass. `rerun` says whether a reviewer may run the command again (`safe`) or must rely on the saved output (`no`: slow, costly, or changes state).

| command | proves | rerun |
|---|---|---|

## Pre-authorized

What a run does without asking. Be specific: which environments, hosts, ports, accounts, and any spend limit.

If landing is pre-authorized, write it as the exact commands in order — merge, dependency install, release — and the conditions that must hold first. A step missing from that list is a red line.

## Red lines

What a run parks. For each, the action and what the run prepares instead.

| red line | prepare instead |
|---|---|

## Evidence

Where evidence files go, how they are named, and what each records: the command, exit status, time and commit.

## Review heuristics

Paths to project-specific rules the reviewers apply.

## Run records

Where run records live and how they are named.
