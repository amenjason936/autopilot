# Complete local run

This example is executable and uses only generated data. It begins with a boundary
bug and a weak guard test, so a red baseline is expected and explicitly authorized
by choosing this training scenario. It does not publish, contact a model, read real
credentials or change an installed skill.

```sh
export AUTOPILOT_HOME=/absolute/path/to/autopilot
bash "$AUTOPILOT_HOME/scripts/training-ground.sh" /tmp/autopilot-training-new
bash "$AUTOPILOT_HOME/scripts/verify-evidence.sh" /tmp/autopilot-training-new/repo/evidence
cat /tmp/autopilot-training-new/repo/run.md
```

Use a new destination on each run. The script refuses existing paths and leaves the
repository, contract, commits, record, patches and evidence for inspection. No
cleanup of existing user files is performed.

1. **Contract/base:** a local fixture contract allows only generated state. The
   initial environment-only policy has no claimed filesystem/network restrictions.
2. **Red baseline:** `priority(10)` incorrectly returns `low`; the existing boundary
   check fails and `logic-bug.md` records that failure.
3. **Implementation/gate:** make the boundary inclusive; commit; `boundary-fixed.md`
   records a green gate in a pinned worktree.
4. **Challenge the detector:** a patch bypasses `can_write`'s role guard. The
   positive-only access check stays green: `weak-detector.md` says **SURVIVED**.
5. **Strengthen the detector:** add guest rejection, commit, rerun the same patch.
   `strong-detector.md` shows a green baseline and **KILLED** mutant.
6. **Safety boundary:** commit a fixture policy denying networking and its generated
   `forbidden` directory. Both attempted reads and an external-address UDP socket
   fail, with positive controls and no downgrade. The fixture canary is unchanged.
7. **Land:** run the full fixture check under the OS sandbox, verify every manifest
   hash, then commit the record, evidence and MANIFEST together.

Expected tail:

```text
verified: 7 evidence file(s)
TRAINING PASSED
```

The fixed example supplies the mutation itself to make the demonstration repeatable.
For a real full-mode plan, an independent adversary must select substantive targets
for every criterion, and an independent auditor must inspect the final record. This
example cannot stand in for those reviews.

On a host without usable `sandbox-exec`/bubblewrap, the strict step fails and no
`TRAINING PASSED` is printed. Diagnose the OS/runtime restriction; do not change the
policy to `env-clean` merely to make the example green.
