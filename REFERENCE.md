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
  "write_dirs": ["out"],
  "record_paths": {"evidence_dir":"docs/evidence", "run_record":"docs/runs/run.md"}
}
```

`GATE_POLICY` may select another repository-relative policy. A repository with a contract but no policy is refused. Gate, dispatch and review identity share that selected path and its pinned content/effective-policy digest. The policy is read from the pinned commit; shell text in Markdown is never evaluated to configure the sandbox. Translate every filesystem/network red line into this policy before authorization. Other red lines remain decisions governed by the approved contract, not something a general-purpose script can infer from prose.

`env-clean` uses `env -i`, current PATH, a new HOME/TMPDIR, `LC_ALL=C`, Git configuration isolation, and only explicitly named variables. When a backend is usable, it adds an OS-enforced read-only source/Git and runner-control/helper/evidence boundary with a real write-denial probe. If the backend is absent or cannot launch, unrestricted `env-clean` runs with endpoint source verification and records **source protection: NOT OS-ENFORCED**. This cannot detect write/test/restore, prevent host writes, or isolate helpers and evidence. Persistent helper/control changes are checked separately before and after every command; this detects tampering without preventing the write itself. A backend that launches but fails its write-denial control is refused rather than downgraded. This mode does **not** restrict other host files or networking. Names containing KEY, TOKEN, SECRET or PASSWORD (case-insensitive), reserved runtime controls and loader/Git injection variables are rejected. Evidence records variable names and set state, never values. A non-secret name may still carry a secret value: do not whitelist one.

A network prohibition or any denied path automatically selects `sandbox-exec` on macOS or `bwrap` on Linux if the requested mode is `env-clean`. Explicit strict modes are allowed; unsupported/missing tools stop the run. There is no silent fallback. Both strict profiles are offline, even for a path-only restriction. They allow reads of the checkout, its Git metadata, HOME/TMPDIR, system runtime roots, and explicit `read_paths`; the checkout and shared Git storage are read-only. Writes go to HOME/TMPDIR, `$AUTOPILOT_OUTPUT`, and newly created relative `write_dirs` declared in policy. A writable directory may not already exist in committed source or traverse a symlink. Setup uses the same restriction: provision dependencies into a new declared cache/output directory, not by rewriting source. Baseline and mutant get fresh outputs. External dependencies still need their own frozen inputs; source immutability is not a claim of fully reproducible builds. Explicit `deny_paths` override those allowances. Default runtime reads are `/usr`, `/bin`, `/sbin`, `/lib`, `/lib64`, `/System/Library`, `/Library/Apple`, `/private/var/db/dyld`, `/etc`, `/private/etc`, `/dev` where present. Put sensitive subpaths within allowed roots on `deny_paths`. Linux strict mode remounts synthetic root directories read-only while keeping explicit output mounts writable. The root directory itself and directory metadata are visible on macOS; file contents outside the allowlist are not.

macOS uses the installed Seatbelt `sandbox-exec`; Linux needs bubblewrap plus usable user namespaces. A restrictive outer sandbox or disabled namespaces can make preflight fail. This is a deployment limitation, not a passing sandbox test. Strong mode preflight checks an allowed generated file, read/write denial of a generated canary outside the allowlist, and a UDP socket connected to an external IP. UDP connect sends **no packet**: an unsandboxed positive control must succeed and the sandboxed operation must fail. These repeatable probes check the specified boundaries; they do not prove resistance to kernel exploits or every possible external tool. Dependencies must be available offline in approved runtime paths.

## Evidence format and redaction

Machine conclusions come only from runner-written structure: a result is the
file's final two lines, `- finished: …` and `- result: …`; header fields come
before any command output. Tools (`mutant-status.py`, `api-review.py`, the
auditor) never take a `- result:` line from anywhere else. Untrusted text
(commands, output, patches) is embedded with every run of three or more
backticks broken by zero-width spaces, so it cannot close a fence.

Redaction fails closed. A redactor error (an invalid `REDACT_REGEX`, which the
runner also rejects up front with exit 64, or any internal failure) prints
nothing and exits non-zero; the runner then refuses to publish (exit 70) and
prints `diagnostic withheld: the redactor failed` instead of an unredacted
message. Output that is not UTF-8 is a deliberate outcome, not a failure: the
whole block becomes `<non-UTF-8 output withheld>`. Failure signatures and TAP
detection read output with invalid bytes replaced, so binary noise never
breaks a valid gate.

`codex-review.sh` accepts `CODEX_REVIEW_EFFORT` only as minimal, low, medium,
high or xhigh, and `CODEX_REVIEW_MODEL` only as a plain identifier
(`[A-Za-z0-9._:/-]`); anything else exits 64 before the CLI starts.

## Host adaptation

`host-doctor.sh [--fix] [REPO]` checks the required tools, whether the OS sandbox
launches (bwrap on Linux with an unshared user and network namespace,
`sandbox-exec` on macOS), why not (bwrap missing, AppArmor restricting user
namespaces without a bwrap profile, `unprivileged_userns_clone=0`, a container),
whether `sudo` works without a password and which package manager exists. It
reads the committed policy at REPO's HEAD and prints one recommendation:

| recommendation | exit | meaning |
|---|---|---|
| `strict` | 0 | the backend launches; run the policy as written |
| `env-clean` | 0 | unrestricted policy; gates run env-clean and disclose it |
| `degraded` | 0 | restrictive policy, no backend, policy approves `"fallback": "env-clean"` |
| `install` | 1 | the listed host changes would make it launch |
| `park` | 2 | restrictive policy, no backend, no approved fallback |

`--fix` applies the `install` changes (installing bubblewrap, an AppArmor profile
for `/usr/bin/bwrap` only, enabling unprivileged user namespaces) through
passwordless `sudo`, then probes again. These change the host: run it only when
the contract pre-authorizes host setup or the human approves it at takeoff.

**The fallback.** A policy field `"fallback": "park" | "env-clean"` (default
`park`) says what a restrictive policy does when the backend cannot launch. Only
the human sets it, in the committed policy. With `env-clean`, gates run without
the OS sandbox: evidence carries `RED LINES NOT OS-ENFORCED: the policy denies …`
and `source protection: NOT OS-ENFORCED`; network denial is reduced to dead proxy
variables (`HTTP(S)_PROXY`, `ALL_PROXY`, `npm_config_offline=true`,
`PIP_NO_INDEX=1`) that well-behaved clients honour and nothing enforces; denied
paths stay readable. The record lists every red line it no longer enforces under
*Not verified*. A backend that launches but fails its probes is still refused,
never degraded.

## Runner integrity in fallback mode

Before execution, the runner loads its integrity checker into parent-shell memory
and freezes a digest of the entire helper directory. Symlink and special-file
inputs are refused rather than following mutable targets outside that directory. Policy, current source-state
snapshot, sandbox profile and frozen mutant patch are also hashed. Expected digests
remain in the parent process, not a writable scratch manifest. The checker runs
from that preloaded code using Python `-I -S`, so project/helper import shadows and
changes to the on-disk checker cannot replace the verification code.

Every command, including setup and probes, is bracketed by integrity verification.
A missing, replaced, added or persistently changed helper/control stops the run
with exit **70**, before another project command or helper/redactor is called.
A fixed diagnostic is printed directly; no passing evidence is published and any
partial remains unverified. Restore helpers from a trusted checkout/installation
before retrying. The runner does not silently restore files or claim that a future
invocation can authenticate an already compromised initial installation.

The runner refreshes the expected control digest only for its own preparation of
a fresh tree or an applied mutant snapshot, after checking the preceding state.
Generate caches/output outside the helper directory; changing its contents during
a run is an integrity failure, including a concurrent update by another process.

Across invocations, `runner_init` compares the on-disk inventory with a trusted
reference before anything runs, so a change persisted by an aborted gate cannot
become the next gate's baseline (issue #3). The reference is, in order:
`AUTOPILOT_HELPER_PIN` (the inventory sha256 that `run-gate.sh --dry-run` prints
at takeoff, recorded in the run record and exported for every gate); a clean Git
checkout of the skill (`git status` on `scripts/`, untracked files included); the
`installed_sha256` inventory in `INSTALLATION.json`. Without any of them the
runner refuses to start. Each refusal exits **70** and names the changed files and
how to restore them. Evidence records the reference used (`helper reference:`).
A tamper that also rewrites the reference (commits to the skill checkout, edits
the receipt, changes the exported pin) is outside this check.

A gate aborted this way leaves `<label>.md.partial`; rerunning that label exits
**76**. Use a new label, or set `GATE_RERUN_POLICY=safe` once the commands are
known to be rerun-safe.

This is endpoint integrity under a trusted initial runtime, **not** OS isolation.
Transient write/restore, a process racing the checks, or compromise of the parent
process/interpreter are outside this guarantee. Restrictive policies still require
a working OS backend; no checksum fallback satisfies a path/network prohibition.

## Commands and settings

```sh
export AUTOPILOT_HOME=/path/to/the/skill
export AUTOPILOT_RECORD="$PWD/docs/runs/run.md"
bash "$AUTOPILOT_HOME/scripts/run-gate.sh" --dry-run "$PWD" docs/evidence/gate-s1.md gate-s1 'make test'
bash "$AUTOPILOT_HOME/scripts/run-gate.sh" "$PWD" docs/evidence/gate-s1.md gate-s1 'make test'
MUTANT_FAILURE_REGEX='^ASSERT_C1_FAILED$' bash "$AUTOPILOT_HOME/scripts/run-mutant.sh" "$PWD" docs/evidence/mutant-c1.md mutant-c1 /tmp/c1.patch 'make test'
bash "$AUTOPILOT_HOME/scripts/verify-evidence.sh" docs/evidence
```

Each command argument is a shell string executed with `/bin/bash --noprofile --norc -o pipefail -c`, closed stdin and a timeout process group. All gate commands run so failures are visible together. Labels contain ASCII letters, digits, `.`, `_`, `-`; filenames must be `<label>.md`. Inside-repository record paths must exactly match dedicated `record_paths` in the committed policy. Every tracked evidence artifact must already be registered in its pinned MANIFEST with matching bytes; unregistered live files are refused. This preserves legitimate HTML/JSON reports without treating their suffixes as proof that a directory contains no source. New evidence directories start empty; interrupted partials and the lock owner are the only unregistered runtime exceptions. Approved record paths may be dirty; other code must be committed. Neither runner inherits local caches or uncommitted files from the source checkout. Host-side Git operations disable fsmonitor and hooks; configured clean/smudge/process filters are disabled before status and cleanup. Worktrees are created with `--no-checkout`; their effective conditional configuration is inspected before callback-free materialization. Filtered/LFS content remains its committed representation; prepare any required materialization explicitly inside the approved sandbox.

| Setting | Default / meaning |
|---|---|
| `GATE_TIMEOUT` | 3600 seconds per command; 0 disables the deadline |
| `GATE_TAIL_LINES`, `GATE_FAIL_LINES` | 40 / 200 lines after full-output redaction |
| `GATE_KEEP_REGEX` | Additional matching sanitized lines to keep, after a labelled separator as `<line>:<text>`. Use it for the criterion tests' result lines, which a 40-line tail may drop |
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

A missing command, timeout, terminating signal, zero-test TAP plan or skip-only TAP detector cannot establish a killed mutant. Non-TAP commands still need meaningful detector review. Every failed mutant command must match the frozen signature and expected exit; the signature must identify the target assertion, not a generic error or framework exit. Other nonzero exits are INCONCLUSIVE. Matching results still need reviewer inspection: a syntax error or unrelated failed dependency is not evidence that the criterion was tested. Setup must not change tracked code. Baseline and mutant each have a fresh worktree/HOME to avoid leftover state causing a kill.

## Evidence, commit binding and recovery

The tested commit is the most recent commit changing something outside this run's record paths. The runner pins the full HEAD, writes both SHAs and checks for concurrent HEAD/source-tree changes. Git read errors fail closed. It freezes an actual source digest after applying the mutant and verifies that state after every command; extra source changes or failed reads are infrastructure failures. Where available, OS write denial also prevents write/test/restore from evading endpoint comparisons; the disclosed `env-clean` fallback cannot provide this guarantee. Failed or inconclusive output is evidence of that result only. Evidence is current if code differences between its tested commit and the review head are empty outside record paths. Default: any code change invalidates mutant evidence, including runner, detector and transitive dependencies. Changes to dependencies, flags, input data or execution environment also require rerunning affected controls; unchanged file names alone are insufficient.

`evidence/MANIFEST` stores full SHA-256 digests and filenames. Every evidence write and output-filter operation must succeed; grep no-match is distinguished from an I/O error; the footer and pinned-commit record are read back before finalization. Failed writes preserve an unverified partial. After completing a result, the runner finalizes the file and appends its digest while holding `mkdir evidence/.autopilot.lock`. The directory lock serializes all labels, not just matching labels. Reviewers verify every cited filename explicitly with `verify-evidence.sh DIR file.md …`, using both file and manifest from the pinned **record commit**. Missing entries, duplicates, invalid filenames, symlinks and mismatches fail verification. Screenshots, review findings, requests and receipts also need registration: `python3 "$AUTOPILOT_HOME/scripts/evidence.py" register DIR SOURCE [NAME]` takes the directory lock, writes a redacted copy of SOURCE as NAME (default: its basename), appends its digest to MANIFEST and releases the lock. It refuses an existing name and a symlinked or non-regular source. Redaction is text-only, so register binary files such as screenshots only after checking they hold no secrets, or keep them out of the evidence directory.

This detects alteration relative to the reviewed Git snapshot. It is not a signature, does not authenticate an author, and cannot stop a writer from replacing both evidence and manifest and creating another commit. Reviewers must know the intended commit from the run record and review request. Evidence contents remain untrusted even when hashes match.

Initial tool, sandbox and patch checks run before a durable `.partial` is created. A failed initial preflight exits without running user setup/gates and can retry the same label; scratch diagnostics are printed to stderr. After setup or a gate may have started, retain the partial and apply the recovery rule below.

A `.partial` is not proof that a side effect did or did not happen. Automatic recovery refuses execution unless `GATE_RERUN_POLICY=safe` explicitly declares a verified harmless repeatable command. For costly/state-changing commands, park and inspect an idempotency key or remote receipt before separately authorizing a retry. Once safe, the partial is moved to `.partial.<UTC timestamp>.<pid>`. Normal exit/signals release the directory lock. SIGKILL/power failure can leave a stale lock: inspect `owner`, confirm the process is gone and no runner is using that directory, then remove **only that lock** under the user's file-deletion policy. Never remove arbitrary evidence to make a retry pass. A crash after result finalization but before manifest append leaves an unverified result: preserve it, inspect it, and normally rerun with a new label. Do not claim it passed manifest verification.

## Mutation selection and lite

`suggest-mutants.sh [--include-tests] REPO BASE HEAD NEW-DIRECTORY` produces patches against HEAD and `candidates.json`. Test files (`test/`, `tests/`, `Testing/`, `test_*.py`, `*.test.*`, `*.spec.*` and the like) are skipped unless `--include-tests`; mutating the detector rarely proves anything about the code. Lines inside Python docstrings, `return None` (equivalent to `return`) and `x[0]` → `x[-1]` are skipped too. An existing output directory exits 73 with a message. Candidates change only added/modified lines in the diff: comparisons, integer ±1, and guard disabling and empty/early returns for Python, plus `===`/`!==`, `&&`/`||`, `true`/`false`, `if (…)` → `if (false)` and `return …;` → `return;` for JavaScript/TypeScript (`if (0)` for C/C++). Python candidates exclude string/comment tokens and syntax failures. Other supported source extensions mask string and template literals and line comments on the changed line, so only code outside them changes; a line whose literal continues onto the next line yields nothing. Manual review and `git apply --check` remain mandatory. No candidates is not a reason to waive a criterion: the adversary supplies a targeted patch. Fill `selected_by` and `criterion` in the run record, not by pretending the generator is an independent reviewer.

`mutant-status.py [--docs GLOB]... [--check] REPO EVIDENCE-DIR [COMMIT]` reads every
mutant evidence file in MANIFEST and compares its tested commit with COMMIT
(default HEAD). A KILLED result stays current when everything that changed since
is a docs path (`--docs`, the contract's *Docs paths*), a record path, or a test
file whose change only appends lines after its old end, none of which can exit,
return, skip or swallow a failure (the detector's own files and paths that look
like tests), so existing assertions still run unchanged. Gate settings and
environment are not tracked: change one and rerun by hand. The mutated file, any
other source, edited or deleted test lines, or helpers the detector runs mean a
rerun. It prints label, result, tested commit, `current`/`rerun` and the reason;
`--check` exits 1 when a KILLED mutant needs a rerun. The rule is a heuristic the
reviewers may challenge: a test that adds an early exit can still change what
runs. Rearranging tests silently retargets a regex signature, which is why edits
to existing test lines always count.

`check-lite.sh REPO BASE HEAD RUN-CONFIG.json` counts added+removed lines across the diff, except the policy's record paths, which the runner admits only as registered evidence and a `.md` record. Config must contain exactly `{"stages":1,"network":false,"publish":false,"risk":"documentation-only"}` or the same with `"risk":"small-change"`. Files under the policy's `generated_paths` (committed build output such as `dist/`) are not counted either; the contract must then have a gate command proving them fresh against the source (e.g. compile a copy into `$AUTOPILOT_OUTPUT` and diff), and `suggest-mutants.sh` skips them along with `*.min.js`, `*.map` and `*.d.ts`. Sensitive names are matched as whole words of the path, split on `/ . _ -` and camelCase: `authMiddleware.ts` and `oauth/` are refused, `author.ts` is not. The policy's `lite` list (default `["documentation-only"]`) is the human's opt-in per risk class. small-change also refuses any added or removed code line (outside tests) containing an access-control or secret word — `auth*`, `admin*`, `role`, `permission`, `privilege`, `password`, `secret`, `credential`, `csrf`, `cors`, `acl`, `rbac`, `sudo`, `chmod`, `signature`, `encrypt`/`decrypt`, `sanitize`, allow/deny lists — because a two-line guard removal looks small and innocuous to a path check. An executable bit is refused only when it changes or arrives with a new file; symlinks and submodules always. small-change: at most 4 files, 40 changed lines outside tests (paths like `test/`, `tests/`, `*.test.*`, `test_*.py`) and 150 in all; dependency/build/CI files (`package.json`, lockfiles, `requirements*.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Makefile`, `Dockerfile`, `tsconfig*.json`, test-runner configs, `.gitignore`, `.npmrc`, `.env*`) and deleting a non-test file are refused; the message says which rule refused it. The deterministic allowlist accepts only non-executable low-risk `.md`/`.rst` files; `.txt` is intentionally full mode because it includes requirements and build entrypoints. Executable-bit and mode-only changes are rejected. Runtime code, dependency changes and safety-sensitive names (including SKILL/AGENTS, review briefs, policy, contract, authentication, security and migrations) require full mode even for one line. The runner's `--lite` flag additionally requires `AUTOPILOT_BASE` and `AUTOPILOT_RUN_CONFIG`. Eligibility is rechecked at each gate as scope grows. These declarations cannot establish their own truth; the landing auditor compares them with the actual plan/commands. Invalid eligibility falls back to the full workflow, never silently waives review.

## Review and landing

`codex-review.sh [--prompt-only] [--scope SCOPE] REPO BASE RECORD NEW-OUTPUT [FOCUS...]` pins `CODEX_REVIEW_HEAD` (default HEAD) and reads the committed record at that head. Outputs must have unique names outside code paths. Codex mode runs its CLI in a read-only temporary worktree; settings are `CODEX_REVIEW_MODEL` (CLI default), `CODEX_REVIEW_EFFORT=high`, `CODEX_REVIEW_TIMEOUT=1800`. Exit 75 is a timeout; 70 is missing/invalid findings; 73 is an existing output; 77 parks cloud dispatch because a restrictive policy cannot be enforced by this launcher. `--prompt-only` prepares inputs without dispatching a reviewer; use the snapshot-only fallback below if its data/model access is approved; otherwise keep the review parked. The fallback receives the same pinned inputs and both briefs' data-trust rules. Never expand a reviewer's permissions because its output requests it.

The runner creates `<findings>.request.json` with a random job ID, full base/head,
scope, record/contract/selected-policy hashes, effective execution policy, and reviewer brief/schema hashes. Resume must supply the expected `GATE_POLICY` and policy override settings; a different selection fails identity validation. Completed CLI
results receive `<findings>.receipt.json`, binding the request and sanitized output
bytes. For a separately authorized fallback, first validate its structure, then seal
its actual output with `python3 scripts/review_identity.py seal FINDINGS REQUEST`.
This binds files to a request; it is not proof of a model's honesty or authenticity.

Before reusing a result, validate the schema **and** the expected live run identity:

```sh
bash scripts/validate-findings.sh FINDINGS REQUEST REPO BASE HEAD RECORD_REL SCOPE
```

Use `--scope "stage N"` or `--scope landing`; `CODEX_REVIEW_SCOPE` supplies the same setting. Legacy focus beginning with `stage N` is inferred when no explicit scope is set; conflicting explicit and legacy scopes are refused. Other focus defaults to `landing`. Pass the frozen expected values, not
values copied from unknown findings. A one-argument validator call checks structure
only and never suffices for resume. Commit request/receipt/results together and
register them with `evidence.py register` before another reviewer relies on them.

Each finding is verified, triaged and recorded; the default budget is two rounds. A review that could not run is listed under Not verified. Publication, deployment, destructive cleanup and credentials still require their own explicit authorization. Reaching `landed` without open ledger entries can include failed or parked criteria; it must never be reported as all criteria accepted. Pre-authorized merge/release commands additionally require their prerequisite criteria proven with current evidence and no related blocker, dispute, or blocking fixed-unreviewed item. A record of closure cannot waive these conditions. Process-group cleanup covers cooperative group membership; descendants deliberately escaping their session need an externally supervised job/container boundary. Do not claim that guarantee on macOS from process-group tests alone.


## Migrating an existing project

This release changes execution and evidence formats. Existing `docs/autopilot.md`
contracts remain human-owned; do not silently rewrite their red lines. Before a
new run, propose any changed setup/review rules in its record, reuse prior explicit
authorization where it covers them, and obtain approval only for genuinely new scope.

1. Translate the existing contract into `docs/autopilot-policy.json` and commit it.
   An unrestricted minimal policy is `{"version":1,"sandbox":"env-clean"}`.
   Preserve every existing path/network prohibition with `deny_paths` and
   `deny_network`; never use the minimal example to remove a red line. For records
   inside the repository, declare the exact `record_paths.evidence_dir` and
   `record_paths.run_record`. Use new dedicated paths for new runs; existing
   evidence must have a verified committed MANIFEST before it is excluded from
   source checks. Historical logs without matching provenance remain historical.
2. Commit the dependency lockfile and required source inputs. Fresh worktrees do
   not include ignored/untracked `node_modules`, virtual environments or build
   caches. Source is read-only under an enforced backend. Outputs belong in
   `$AUTOPILOT_OUTPUT`, HOME/TMPDIR, or new untracked paths named in `write_dirs`.
   For example, declare `"write_dirs":["node_modules","dist"]` only when neither
   directory exists in committed source. Do not declare `docs` or another source
   directory writable. Prefer output flags (for example `tsc --outDir dist`) to
   build tools that rewrite source. Even fallback mode rejects lasting source edits.
3. Put repeatable dependency setup in `GATE_SETUP`; `MUTANT_SETUP` overrides it
   for mutation runs. Setup runs independently for baseline and mutant. For an
   npm project whose lockfile is already committed, one offline pattern is:

   ```sh
   # Before takeoff, in an approved preparation environment, populate an npm
   # cache for the exact lockfile/toolchain. Network access needs existing scope.
   # Then expose that frozen cache read-only via policy read_paths.
   export GATE_SETUP='cp -R /absolute/offline/npm-cache "$HOME/npm-cache"; npm ci --offline --cache "$HOME/npm-cache" --ignore-scripts --no-audit --no-fund'
   ```

   The policy must include that cache in `read_paths`, `node_modules` in
   `write_dirs`, and any non-system toolchain path needed to run npm. Disabling
   install scripts is suitable only if this project does not need them. If scripts
   are required, review/authorize them and list their output directories. The
   copied cache is writable; the approved original remains read-only in strict
   mode. Freeze the cache/toolchain identity in the record. An incomplete offline
   cache is a setup failure, never permission to enable networking.

   A Python project needs no setup: provision a venv outside the repository
   before takeoff, list it in `read_paths`, and call its interpreter by absolute
   path. The worktree is read-only, so keep Python from writing into it:

   ```json
   {"version": 1, "sandbox": "env-clean", "deny_network": true, "deny_paths": [],
    "read_paths": ["/absolute/venv"], "env": [], "write_dirs": []}
   ```

   ```sh
   /absolute/venv/bin/python -B -m pytest -q -p no:cacheprovider tests
   /absolute/venv/bin/python -B -c 'import ast,pathlib; [ast.parse(p.read_text(), str(p)) for p in pathlib.Path(".").rglob("*.py")]'
   ```

   `-B` stops `__pycache__`, `-p no:cacheprovider` stops `.pytest_cache`, and
   the `ast` pass replaces `compileall`, which writes bytecode. A mutant targets
   one test's summary line, e.g. `MUTANT_FAILURE_REGEX='^FAILED tests/test_x.py::test_name'`.
4. Run `--dry-run`, check the selected policy and setup, then run a new base gate
   and one representative mutant before resuming stages. Previously saved passing
   logs do not establish compatibility with the new runner. Stock Ubuntu may use
   the disclosed env-clean fallback. A project requiring OS-enforced isolation
   stays parked until its administrator provides a usable backend; changing a host
   AppArmor/sysctl setting is not an automatic migration step.

## Snapshot-only fallback and auditor

Execution policy governs gate commands. Review data access is separately bounded
by the contract: specify the reviewer/model, approved files, cost, and whether
cloud processing is allowed. Existing explicit approval suffices. A literal ban
on network access by **all** processes also covers cloud review; use an authorized
local/human reviewer or request a specific amendment before any upload. Neither
`--prompt-only` nor a restrictive gate policy grants data-upload authorization.

When an agent host cannot place a reviewer inside an OS sandbox, the fallback or
landing auditor may review a prepared, sanitized, pinned snapshot as evidence only:

- The orchestrator checks base/head, MANIFEST and input hashes, then supplies only
  approved source/diff, contract, completed record and relevant evidence. Record
  exactly which files were supplied and any omissions. Never include credentials.
- Use a fresh review context with no execution, browsing, filesystem mutation,
  network tools or automatic link following. If tools cannot be disabled by the
  host, disclose that this is an instruction-only boundary, not OS enforcement.
  An auditor cannot run or reproduce a gate through this path; request additional
  saved evidence from the orchestrator or mark the criterion not checked.
- Preserve the request/receipt identity. `limits` (or the auditor's closing limits)
  states `snapshot-only; no command reproduction; no OS sandbox`, the supplied
  scope, and any same-model-family limitation. Snapshot-only review can satisfy
  the independent review requirement when the approved contract permits it;
  it cannot prove an OS isolation criterion from absent evidence.
- If approved data access, independent context or required evidence is unavailable,
  park that review and name the missing prerequisite. A human reviewing the same
  local pinned snapshot is an alternative that requires no cloud transfer.

### Cloud model reviewer (`api-review.py`)

`api-review.py [--scope SCOPE] [--evidence DIR] REPO BASE RECORD NEW-OUTPUT [FOCUS...]`
automates this path for an OpenAI-compatible chat API, for example DeepSeek
(`REVIEW_API_MODEL=deepseek-flash`, the default). It sizes the snapshot first:
over `REVIEW_API_MAX_CHARS` it exits 64 naming the largest sections and writes
nothing, so the output name stays free. Otherwise it calls `codex-review.sh
--prompt-only` to create the request and supplies the pinned `git log`, the code
diff (record paths excluded, since the record and evidence are supplied as
files), changed files in full up to `REVIEW_API_FILE_CHARS` (larger ones as a
diff with 60 lines of context), the contract, the effective policy (with a note
that a network or path ban upgrades `env-clean` to the OS sandbox), the record,
and with `--evidence DIR` the MANIFEST, `verify-evidence.sh` output for every
file and the evidence files the record cites, mutant evidence condensed to its
header, patch and result; the rest are listed by name (`--all-evidence` sends
every file in full). The whole prompt passes through the redactor
before upload; `<out>.supplied.txt` lists each supplied file with its sha256,
and `<out>.log.txt` the model, usage and finish reason (`.txt`, so a `*.log`
ignore rule never hides it). The model gets no tools, so `limits` must start with
`snapshot-only; no command reproduction; no OS sandbox; reviewer: <model> via API`.
A reply cut off at `REVIEW_API_MAX_TOKENS` (default 131072, reasoning included)
exits 70 and says so; raise the limit or lower `REVIEW_API_EFFORT` (high,
medium, low). A reply that is not valid findings is kept as `<out>.invalid`; a
valid one is sealed, and resume validates it like any other review.

It refuses (exit 77) unless `REVIEW_API_UPLOAD=approved`: set it only when the
contract names this reviewer, model and cloud processing. The key comes from the
variable named by `REVIEW_API_KEY_ENV` (default `DEEPSEEK_API_KEY`), or that one
variable in `REVIEW_API_ENV_FILE`; it is never written to disk or evidence.
Other settings: `REVIEW_API_BASE` (default `https://api.deepseek.com`),
`REVIEW_API_EFFORT=high`, `REVIEW_API_MAX_TOKENS=131072`, `REVIEW_API_TIMEOUT=1800`,
`REVIEW_API_MAX_CHARS=600000`, `REVIEW_API_FILE_CHARS=40000`. A contract that uses it
sets the effort, the size cap and how failed calls count against its budget.
A different model family is the point: record it as the reviewer in the ledger
(`deepseek-flash`), not as `codex` or a same-family fallback.

The CLI's restrictive-policy refusal remains: its autonomous tool boundary cannot
express the full execution policy. This documented fallback does not bypass it.

## Resume by current

Before acting on the saved `current:`, check it against Git and the evidence:
`git log` since the record's last commit, `git status`, the MANIFEST (registered
but uncommitted files), any `.autopilot.lock` or `.partial`, and review outputs
newer than the record. When they show the step finished, advance `current:` to
the step they show and record the reconciliation in the record's resume log.

| Saved `current:` | Next action |
|---|---|
| `takeoff` | Re-read authorization and policy; retry failed initial checks after repair. |
| `stage <n> build` | Inspect branch and unfinished changes; continue without discarding work. |
| `stage <n> gate <label>` / `stage <n> mutant <label>` | Verify existing evidence; resolve partial/receipt safety before repeating commands. |
| `stage <n> review r<k>` | Validate request/head/scope identity; reuse only matching completed results, otherwise restart review. |
| `stage <n> record` | Bring the record up to date from Git and the evidence MANIFEST, then make the record commit. |
| `landing preparation` | Refresh evidence, complete acceptance rows and record; keep `status: flying`, then commit. |
| `landing review r<k>` | Review the completed pinned record; append dispositions and settle blockers before final status. |
| `landing action <step>` | Check receipts for already completed external actions; execute only approved, eligible remaining actions. |
| `landed — parked <P ids>` | Report the recorded state; resume parked work only when its prerequisite is resolved. |

Contract **Docs paths** may exempt qualifying stage documentation changes from the
stage adversary review; record the exemption. They never exempt the landing audit
or override full-mode requirements for policy/security/skill changes.


## Test hosts without a sandbox

`make check` runs the full suite on both kinds of host. Eight tests specifically
requiring OS write/path/network enforcement or strict training use an independent
backend launch probe. They report **SKIP: isolation not verified** when no backend
can launch; portable and fallback-integrity regressions still execute. A backend
that launches but fails its actual boundary tests is a failure, not a skip.
Destructive helper tests always use a disposable copy, never the running checkout.

Set `AUTOPILOT_REQUIRE_SANDBOX=1` to turn unavailable isolation coverage into a test
failure. The enforced Linux/macOS CI jobs set it and additionally reject skipped
checks before running the regression mutations and strict training. The portable
Ubuntu job preserves namespace settings and runs the complete suite twice: once on
the default host and once with unavailable-backend stubs. It also checks that tests
did not modify tracked checkout files. Skipped tests are not evidence of isolation;
the default-host results and enforced-backend results must be reported separately.
