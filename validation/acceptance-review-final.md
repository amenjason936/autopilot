# Final local acceptance audit

Pinned head: `f0bdc03b5f4a8cc0a1144ae0c2029d82a93fd631`.
Base: `ce2499990917362d2c9674f59bad2b21f46d1d9b`.
Contract: `docs/autopilot.md`; record: `VALIDATION.md`; scope: landing.

**No remaining blocking finding in the stated local acceptance scope.** The previous C1/C3/C4 evidence gaps are closed. One record correction remains:

- **Minor — ledger R4, fixing-commit attribution.** The row attributes the linked-worktree conditional-filter repair to `6971c45`. I checked `git show --stat 6971c450f00e569f436366a1a4c4f272e4f2efca` and `git log -S'--no-checkout' <head> -- scripts/lib.sh`. The callback-free `--no-checkout` materialization fix was introduced in `12d1cd7dc599ebade7efc447b54cf733b589e8b0`; `6971c45` added the corresponding mutation target and other changes, without changing `lib.sh`. The current source, regression and `verified-p0-4-conditional-filter.md` carry the repair, so this does not invalidate C1. Correct R4 to distinguish the implementation commit from the later control-registration commit.

I archived the specified head into a separate temporary directory and verified all 72 manifest entries before interpreting the evidence. The snapshot's `verify-evidence.sh` received every manifest filename as an explicit argument; result: **verified: 72 evidence file(s)**. No missing entry, duplicate, mismatch or partial evidence was accepted. Both historical and current files are bound to this snapshot; hashes do not authenticate their authors or establish truth.

All 24 entries in `verified-controls.json` identify tested code commit `67289c7d8dcf7fa114b44e843aa795eb147c291e`, have matching record headers, green baselines, non-timeout mutant failures and final KILLED results. `git diff --name-only 67289c7d8dcf7fa114b44e843aa795eb147c291e f0bdc03b5f4a8cc0a1144ae0c2029d82a93fd631 -- . ':(exclude)validation' ':(exclude)VALIDATION.md'` is empty. This meets the current brief's conservative source-freshness rule. The current gate uses that same code commit, records all 54 Bats tests passing, zero ShellCheck diagnostics, syntax checks passing, and the completed training exercise. `git bundle verify validation/training-verified.bundle` passed and reported complete history.

The new C1 environment mutation removes `env -i` and is rejected by the ambient-variable detector. The probe mutation unconditionally succeeds and is rejected by the deliberately permissive-sandbox detector. C3 now has relevant changed-line, exact 50/51-line boundary and runtime-risk controls. C4's hardcoded legacy-root mutation completes the valid-decoy training path but fails the expected fixture-byte assertion; it is not a missing-file or unrelated setup failure. Its test file is unchanged by that mutation. These records implement the substantive targets selected in the earlier audit, with selection provenance preserved.

The `fixed-unreviewed` repairs are now independently assessed as follows:

| Ledger rows | Assessment at this head |
|---|---|
| R5 | Carried by the five new criterion controls and their current detectors. |
| R6 | Ledger and independent target table are present; every row has an allowed status and a fix/test reference. Only the R4 attribution correction above remains. |
| R7 | Evidence-write failures stop publication; checked write paths and completion readback are backed by the current refusal control. |
| R8 | KILLED requires the declared exit and failure signature; absent, unrelated and wrong-exit failures are rejected. The recorded target failures were inspected rather than treating their exit codes alone as sufficient. |
| R9 | Restrictive policy parks dispatch before the reviewer is invoked; the test uses a local stub and makes no cloud call. |
| R10 | Record exclusions are checked against committed dedicated policy paths, tracked source exclusions are refused, and the revised freshness rule covers all code. |
| R11 | The implementation and current negative control reject the tested runtime and safety-instruction edits from lite eligibility. |
| R12 | Request/receipt verification binds the expected repository, base/head, scope and recorded input hashes; the stale-scope/head/output checks pass. Historical reports were used as target provenance, not reused as current launcher approvals. |
| R13 | Interrupted execution is refused without a safe-rerun declaration. Publication prerequisite rules are explicit artifacts; no publication was performed or behaviorally certified. |
| R14 | Writer paths are checked before resolution, and the committed-link redirect detector/control carries the repair. |

The record may settle R5–R14 using this audit, while retaining the historical finding artifacts. `flying` and the pending-audit `current:` line are expected at the reviewed head. No open or disputed ledger status is present. Any later merge/release still requires its own authorization and applicable admission checks; this audit does not authorize external action.

I reran nine focused tests from the archived source with:

```sh
bats --print-output-on-failure --filter 'failure signature|record exclusions|approved record paths|lite exact|lite refuses one-line|review identity|restrictive policy|interrupted side effects|committed evidence symlink' tests/supplements.bats
```

All **9/9 passed**. Per the bounded review request, I did not rerun the full suite, relocated strict-sandbox training, or the known-unavailable nested OS sandbox tests in this worker. The current 54/54 and real OS results come from the manifest-verified main-run evidence, not this worker rerun.

C6, live model prompt-injection robustness, Linux/bubblewrap, hosted CI, deliberate process-session escape, SIGKILL/power-loss and disk-full guarantees remain honestly parked or unverified. The shell output-data control is not a model robustness result. The frozen contract is unchanged, and the reviewed source/evidence shows no red-line action; Git artifacts cannot establish unseen external actions. No numerical rating or broad containment certification is given.

C1: carried — current pinned-runner, environment and probe controls close the prior coverage gaps within the stated local scope.
C2: carried — current integrity, redaction, locking, partial preservation, write refusal and path controls support the local claims; stronger durability remains unverified.
C3: carried — current diff-only, boundary/risk and review identity/dispatch controls support the scripts and rule artifacts; model behavior is excluded.
C4: carried — local package artifacts and relocated execution are supported; cross-platform and hosted-CI execution are not claimed.
C5: carried — current 54-test gate, 24 relevant KILLED records and verified complete training bundle carry the local validation claim.
C6: not checked — correctly parked pending the actual four-party evaluations and scores.
