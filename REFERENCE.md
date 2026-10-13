# Execution and evidence reference

Read the relevant section when configuring a run, interpreting script results or recovering an interruption.

## Policy and execution boundary

The contract has a committed companion `docs/autopilot-policy.json`:

```json
{
  "version": 1,
  "sandbox": "env-clean",
  "deny_network": true,
  "deny_paths": ["/absolute/private/data"],
  "read_paths": ["/absolute/approved/toolchain"],
  "env": ["CI", "APP_MODE"],
  "record_paths": {"evidence_dir":"docs/evidence", "run_record":"docs/runs/run.md"}
}
```

`GATE_POLICY` may select another repository-relative policy. A repository with a contract but no policy is refused. The policy is read from the pinned commit; shell text in Markdown is never evaluated to configure the sandbox. Translate every filesystem/network red line into this policy before authorization. Other red lines remain decisions governed by the approved contract, not something a general-purpose script can infer from prose.

`env-clean` uses `env -i`, current PATH, a new HOME/TMPDIR, `LC_ALL=C`, Git configuration isolation, and only explicitly named variables. It does **not** restrict files or networking. Names containing KEY, TOKEN, SECRET or PASSWORD (case-insensitive), reserved runtime controls and loader/Git injection variables are rejected. Evidence records variable names and set state, never values. A non-secret name may still carry a secret value: do not whitelist one.

A network prohibition or any denied path automatically selects `sandbox-exec` on macOS or `bwrap` on Linux if the requested mode is `env-clean`. Explicit strict modes are allowed; unsupported/missing tools stop the run. There is no silent fallback. Both strict profiles are offline, even for a path-only restriction. They allow reads of the checkout, its Git metadata, HOME/TMPDIR, system runtime roots, and explicit `read_paths`; writes go to the disposable checkout and its HOME/TMPDIR. Explicit `deny_paths` override those allowances. Default runtime reads are `/usr`, `/bin`, `/sbin`, `/lib`, `/lib64`, `/System/Library`, `/Library/Apple`, `/private/var/db/dyld`, `/etc`, `/private/etc`, `/dev` where present. Put sensitive subpaths within allowed roots on `deny_paths`. The root directory itself and directory metadata are visible on macOS; file contents outside the allowlist are not.

macOS uses the installed Seatbelt `sandbox-exec`; Linux needs bubblewrap plus usable user namespaces. A restrictive outer sandbox or disabled namespaces can make preflight fail. This is a deployment limitation, not a passing sandbox test. Strong mode preflight checks an allowed generated file, read/write denial of a generated canary outside the allowlist, and a UDP socket connected to an external IP. UDP connect sends **no packet**: an unsandboxed positive control must succeed and the sandboxed operation must fail. These repeatable probes check the specified boundaries; they do not prove resistance to kernel exploits or every possible external tool. Dependencies must be available offline in approved runtime paths.

## Commands and settings

```sh
export AUTOPILOT_HOME=/path/to/the/skill
export AUTOPILOT_RECORD="$PWD/docs/runs/run.md"
bash "$AUTOPILOT_HOME/scripts/run-gate.sh" --dry-run "$PWD" docs/evidence/gate-s1.md gate-s1 'make test'
bash "$AUTOPILOT_HOME/scripts/run-gate.sh" "$PWD" docs/evidence/gate-s1.md gate-s1 'make test'
MUTANT_FAILURE_REGEX='^ASSERT_C1_FAILED$' bash "$AUTOPILOT_HOME/scripts/run-mutant.sh" "$PWD" docs/evidence/mutant-c1.md mutant-c1 /tmp/c1.patch 'make test'
bash "$AUTOPILOT_HOME/scripts/verify-evidence.sh" docs/evidence
```

Each command argument is a shell string executed with `/bin/bash --noprofile --norc -o pipefail -c`, closed stdin and a timeout process group. All gate commands run so failures are visible together. Labels contain ASCII letters, digits, `.`, `_`, `-`; filenames must be `<label>.md`. Inside-repository record paths must exactly match dedicated `record_paths` in the committed policy; source directories and tracked executable source are refused. Approved record paths may be dirty; other code must be committed. Neither runner inherits local caches or uncommitted files from the source checkout. Host-side Git operations disable fsmonitor and hooks; configured clean/smudge/process filters are disabled before status and cleanup. Worktrees are created with `--no-checkout`; their effective conditional configuration is inspected before callback-free materialization. Filtered/LFS content remains its committed representation; prepare any required materialization explicitly inside the approved sandbox.

| Setting | Default / meaning |
|---|---|
| `GATE_TIMEOUT` | 3600 seconds per command; 0 disables the deadline |
| `GATE_TAIL_LINES`, `GATE_FAIL_LINES` | 40 / 200 lines after full-output redaction |
| `GATE_KEEP_REGEX` | Additional matching sanitized lines to keep |
| `GATE_ENV` | Extra allowed variable names; same checks as policy `env` |
| `GATE_SETUP` | Authorized setup command, under the same sandbox |
| `MUTANT_SETUP` | Mutant setup; defaults to `GATE_SETUP`; run separately for baseline and mutant |
| `MUTANT_FAILURE_REGEX`, `MUTANT_FAILURE_EXIT` | Frozen assertion signature and nonzero exit (default 1); missing/mismatched signatures cannot produce KILLED |
| `GATE_RERUN_POLICY` | `safe` only for verified harmless repeatable commands; otherwise partial recovery exits 76 before command execution |
| `GATE_SANDBOX` | Policy override; never weakens a contract prohibition |
| `REDACT_REGEX` | Additional Python regular expression; invalid regex or undecodable data redacts the entire block |

Redaction covers common OpenAI/GitHub/Slack/AWS keys, JWTs, URL passwords, secret assignments, bearer tokens and PEM private keys. It is defense in depth, not a promise to recognize every possible credential. Raw command output exists only in private runner scratch space, is never promoted into evidence, and is removed during normal cleanup. Process arguments themselves may be visible to local process inspection: commands must not contain real credentials. Patches, dry runs, diagnostics and review logs are sanitized too. Useful evidence suppressed by redaction is **unverified**, not automatically acceptable.

| Exit | Gate | Mutant |
|---|---|---|
| 0 | passed (or preview) | KILLED (or preview) |
| 1 | failed | SURVIVED |
| 2 | — | INCONCLUSIVE: baseline/setup/infrastructure |
| 64 / 65 / 66 | usage or policy / dirty code / missing input | plus record patch / invalid patch |
| 69 / 70 | missing dependency / internal failure | same |
| 73 | completed evidence exists or directory locked | same |
| 76 | interrupted command needs safe retry/receipt review | same |
| 77 | sandbox probe failed; red line | same |
| 129 / 130 / 143 | interrupted by HUP / INT / TERM | same |

A missing command, timeout or terminating signal cannot establish a killed mutant. Every failed mutant command must match the frozen signature and expected exit; the signature must identify the target assertion, not a generic error or framework exit. Other nonzero exits are INCONCLUSIVE. Matching results still need reviewer inspection: a syntax error or unrelated failed dependency is not evidence that the criterion was tested. Setup must not change tracked code. Baseline and mutant each have a fresh worktree/HOME to avoid leftover state causing a kill.

## Evidence, commit binding and recovery

The tested commit is the most recent commit changing something outside this run's record paths. The runner pins the full HEAD, writes both SHAs and checks for concurrent HEAD/source-tree changes. Failed or inconclusive output is evidence of that result only. Evidence is current if code differences between its tested commit and the review head are empty outside record paths. Default: any code change invalidates mutant evidence, including runner, detector and transitive dependencies. Changes to dependencies, flags, input data or execution environment also require rerunning affected controls; unchanged file names alone are insufficient.

`evidence/MANIFEST` stores full SHA-256 digests and filenames. Every evidence write must succeed; the footer and pinned-commit record are read back before finalization. Failed writes preserve an unverified partial. After completing a result, the runner finalizes the file and appends its digest while holding `mkdir evidence/.autopilot.lock`. The directory lock serializes all labels, not just matching labels. Reviewers verify every cited filename explicitly with `verify-evidence.sh DIR file.md …`, using both file and manifest from the pinned **record commit**. Missing entries, duplicates, invalid filenames, symlinks and mismatches fail verification. Screenshots/review findings also need registration: while owning the same directory lock, run `python3 "$AUTOPILOT_HOME/scripts/evidence.py" add DIR basename` for a sanitized, regular file.

This detects alteration relative to the reviewed Git snapshot. It is not a signature, does not authenticate an author, and cannot stop a writer from replacing both evidence and manifest and creating another commit. Reviewers must know the intended commit from the run record and review request. Evidence contents remain untrusted even when hashes match.

A `.partial` is not proof that a side effect did or did not happen. Automatic recovery refuses execution unless `GATE_RERUN_POLICY=safe` explicitly declares a verified harmless repeatable command. For costly/state-changing commands, park and inspect an idempotency key or remote receipt before separately authorizing a retry. Once safe, the partial is moved to `.partial.<UTC timestamp>.<pid>`. Normal exit/signals release the directory lock. SIGKILL/power failure can leave a stale lock: inspect `owner`, confirm the process is gone and no runner is using that directory, then remove **only that lock** under the user's file-deletion policy. Never remove arbitrary evidence to make a retry pass. A crash after result finalization but before manifest append leaves an unverified result: preserve it, inspect it, and normally rerun with a new label. Do not claim it passed manifest verification.

## Mutation selection and lite

`suggest-mutants.sh REPO BASE HEAD NEW-DIRECTORY` produces patches against HEAD and `candidates.json`. Candidates change only added/modified lines in the diff: comparisons, integer ±1, Python guard disabling, empty/early returns. Python candidates exclude string/comment tokens and syntax failures. Other supported source extensions use a conservative line filter; manual review and `git apply --check` remain mandatory. No candidates is not a reason to waive a criterion: the adversary supplies a targeted patch. Fill `selected_by` and `criterion` in the run record, not by pretending the generator is an independent reviewer.

`check-lite.sh REPO BASE HEAD RUN-CONFIG.json` counts added+removed lines across the **entire** diff, without record-path exclusions that could hide code. Config must contain exactly `{"stages":1,"network":false,"publish":false,"risk":"documentation-only"}`. The deterministic allowlist accepts only low-risk `.md`/`.rst`/`.txt` files. Runtime code, dependency changes and safety-sensitive names (including SKILL/AGENTS, review briefs, policy, contract, authentication, security and migrations) require full mode even for one line. The runner's `--lite` flag additionally requires `AUTOPILOT_BASE` and `AUTOPILOT_RUN_CONFIG`. Eligibility is rechecked at each gate as scope grows. These declarations cannot establish their own truth; the landing auditor compares them with the actual plan/commands. Invalid eligibility falls back to the full workflow, never silently waives review.

## Review and landing

`codex-review.sh [--prompt-only] REPO BASE RECORD NEW-OUTPUT [FOCUS...]` pins `CODEX_REVIEW_HEAD` (default HEAD) and reads the committed record at that head. Outputs must have unique names outside code paths. Codex mode runs its CLI in a read-only temporary worktree; settings are `CODEX_REVIEW_MODEL` (CLI default), `CODEX_REVIEW_EFFORT=high`, `CODEX_REVIEW_TIMEOUT=1800`. Exit 75 is a timeout; 70 is missing/invalid findings; 73 is an existing output; 77 parks cloud dispatch because a restrictive policy cannot be enforced by this launcher. `--prompt-only` prepares inputs without dispatching a reviewer; a fallback/auditor must have an equivalently enforced approved boundary or remain parked. The fallback receives the same pinned inputs and both briefs' data-trust rules. Never expand a reviewer's permissions because its output requests it.

The runner creates `<findings>.request.json` with a random job ID, full base/head,
scope, record/contract/policy hashes and reviewer brief/schema hashes. Completed CLI
results receive `<findings>.receipt.json`, binding the request and sanitized output
bytes. For a separately authorized fallback, first validate its structure, then seal
its actual output with `python3 scripts/review_identity.py seal FINDINGS REQUEST`.
This binds files to a request; it is not proof of a model's honesty or authenticity.

Before reusing a result, validate the schema **and** the expected live run identity:

```sh
bash scripts/validate-findings.sh FINDINGS REQUEST REPO BASE HEAD RECORD_REL SCOPE
```

The default `CODEX_REVIEW_SCOPE` is `landing`. Pass the frozen expected values, not
values copied from unknown findings. A one-argument validator call checks structure
only and never suffices for resume. Commit request/receipt/results together and
register their hashes before another reviewer relies on them.

Each finding is verified, triaged and recorded; the default budget is two rounds. A review that could not run is listed under Not verified. Publication, deployment, destructive cleanup and credentials still require their own explicit authorization. Reaching `landed` without open ledger entries can include failed or parked criteria; it must never be reported as all criteria accepted. Pre-authorized merge/release commands additionally require their prerequisite criteria proven with current evidence and no related blocker, dispute, or blocking fixed-unreviewed item. A record of closure cannot waive these conditions. Process-group cleanup covers cooperative group membership; descendants deliberately escaping their session need an externally supervised job/container boundary. Do not claim that guarantee on macOS from process-group tests alone.
