#!/usr/bin/env python3
"""Run repeatable regression mutations selected from an independent review.

This is an execution-data negative control, not proof of LLM prompt-injection
resistance. Patches and evidence are retained; a non-KILLED result fails the run.
"""
import difflib
import hashlib
import signal
import json
import os
import re
import pathlib
import subprocess
import sys

# Runtime targets follow validation/independent-review.md. The output-data
# mutation is an author-added script check, not the reviewer's model-level test.
TARGETS = [
    ('p0-1-worktree', 'scripts/runner.sh', 'cd "$TREE$SUBDIR" || return 72', 'cd "$WORKDIR" || return 72', 'gate runs at pinned commit', 'tests/gate.bats'),
    ('p0-2-manifest', 'scripts/evidence.py', 'name not in known or digest(directory / name) != known[name]', 'name not in known', 'manifest detects tampering', 'tests/gate.bats'),
    ('p0-3-redaction', 'scripts/redact.py', "pattern.sub('<redacted>', chunks[index])", 'pattern.sub(lambda match: match.group(0), chunks[index])', 'redaction covers commands', 'tests/redaction.bats'),
    ('p0-3-environment', 'scripts/policy.py', "re.search(r'KEY|TOKEN|SECRET|PASSWORD', upper)", 'False', 'secret and injection environment', 'tests/gate.bats'),
    ('p0-4-sandbox', 'scripts/policy.py', "if (network or denied) and sandbox == 'env-clean':", 'if False:', 'contract policy forces', 'tests/policy.bats'),
    ('p0-4-git-callback', 'scripts/lib.sh', 'command git -c core.fsmonitor=false -c core.hooksPath=/dev/null', 'command git -c core.hooksPath=/dev/null', 'dry-run never executes repository fsmonitor', 'tests/gate.bats'),
    ('p0-4-conditional-filter', 'scripts/lib.sh', 'worktree add --quiet --no-checkout --detach', 'worktree add --quiet --detach', 'worktree-conditional filters cannot execute', 'tests/gate.bats'),
    ('p0-5-preview', 'scripts/run-gate.sh', 'if [ "$DRY_RUN" -eq 1 ]; then', 'if [ "$DRY_RUN" -eq 9 ]; then', 'dry-run prints setup commands', 'tests/gate.bats'),
    ('p0-6-output-data', 'scripts/runner.sh', 'tail -n "$keep" "$WORK/clean-output"', '/bin/bash "$WORK/clean-output"; tail -n "$keep" "$WORK/clean-output"', 'untrusted output is recorded', 'tests/gate.bats'),
    ('p0-7-lock', 'scripts/runner.sh', "|| die 73 'evidence directory locked; inspect owner before recovering a stale lock'", '|| true', 'directory lock rejects', 'tests/gate.bats'),
    ('p0-7-partial', 'scripts/runner.sh', 'mv "$PARTIAL" "$PARTIAL.$(date -u +%Y%m%dT%H%M%SZ).$$"', ': >"$PARTIAL"', 'partial resume archives', 'tests/gate.bats'),
    ('c1-env-inheritance', 'scripts/runner.sh', 'RUN_ENV=(env -i ', 'RUN_ENV=(env ', 'clean environment drops ambient', 'tests/gate.bats'),
    ('c1-probe-enforcement', 'scripts/runner.sh', 'runner_probe() {', 'runner_probe() {\n  return 0', 'fake sandbox allowing access fails', 'tests/policy.bats'),
    ('c3-diff-only', 'scripts/suggest_mutants.py', 'for number in sorted(touched):', 'for number in range(1, len(lines) + 1):', 'mutant suggestions touch only added diff lines', 'tests/methods.bats'),
    ('c3-lite-boundary', 'scripts/lite.py', 'changed <= 50', 'changed <= 51', 'lite exact boundary permits 50', 'tests/supplements.bats'),
    ('c4-portability', 'scripts/training-ground.sh', 'SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"', 'SKILL_DIR="$HOME/.claude/skills/autopilot"', 'relocated training uses package fixtures', 'tests/supplements.bats'),
    ('supplement-evidence-write', 'scripts/lib.sh', 'die() {', 'die() {\n  case "${2:-}" in "cannot write command evidence"|"cannot write evidence footer"|"incomplete evidence cannot be published") return 0 ;; esac', 'evidence write failure cannot publish', 'tests/supplements.bats'),
    ('supplement-failure-signature', 'scripts/run-mutant.sh', 'if ! { [ "$PHASE_MATCHED" -eq 1 ] && [ "$PHASE_UNEXPECTED" -eq 0 ]; }; then', 'if false; then', 'failure signature rejects unrelated errors', 'tests/supplements.bats'),
    ('supplement-record-scope', 'scripts/runner.sh', 'python3 "$SCRIPT_DIR/record_scope.py" "$TOP" "$COMMIT" "$EVIDENCE_DIR" "$RECORD"', 'cat >/dev/null', 'record exclusions reject undeclared', 'tests/supplements.bats'),
    ('supplement-review-identity', 'scripts/review_identity.py', "if (job['version'] != 1", "if False and (job['version'] != 1", 'review identity rejects stale head scope', 'tests/supplements.bats'),
    ('supplement-review-policy', 'scripts/review_identity.py', "if policy['sandbox'] != 'env-clean' or policy['deny_network'] or policy['deny_paths']:", 'if False:', 'restrictive policy parks cloud dispatch', 'tests/supplements.bats'),
    ('supplement-resume', 'scripts/runner.sh', '[ "${GATE_RERUN_POLICY:-}" = safe ]', 'true', 'interrupted side effects stay parked', 'tests/supplements.bats'),

    ('supplement-lite-risk', 'scripts/lite.py', "if (not path.endswith(('.md', '.rst')) or", "if False and (not path.endswith(('.md', '.rst')) or", 'lite refuses one-line runtime and safety instruction edits', 'tests/supplements.bats'),
    ('author-output-symlink', 'scripts/runner.sh', 'python3 "$SCRIPT_DIR/evidence.py" path "$2"', 'true', 'committed evidence symlink cannot redirect writer', 'tests/supplements.bats'),
    ('rc2-control-root', 'scripts/policy.py' if sys.platform == 'darwin' else 'scripts/runner.sh', 'tree, source, gitdir, work, helpers, evidence' if sys.platform == 'darwin' else '--ro-bind \"$WORK\" \"$WORK\"', 'tree, source, gitdir' if sys.platform == 'darwin' else '--bind \"$WORK\" \"$WORK\"', 'commands cannot rewrite runner controls', 'tests/rc2.bats'),
    ('rc2-policy-selection', 'scripts/policy.py', "path = os.environ.get('GATE_POLICY', 'docs/autopilot-policy.json')", "path = 'docs/autopilot-policy.json'", 'alternate policy controls review dispatch', 'tests/rc2.bats'),
    ('rc2-git-errors', 'scripts/runner.sh', 'state="$(cd "$TOP" && git_code status --porcelain)" || return 1', 'state="$(cd "$TOP" && git_code status --porcelain)"', 'failed git status with empty output', 'tests/rc2.bats'),
    ('rc2-source-snapshot', 'scripts/source_state.py', 'if actual != json.loads(target.read_text()):', 'if False:', 'applied mutant snapshot rejects extra edits', 'tests/rc2.bats'),
    ('rc2-filter-errors', 'scripts/runner.sh', 'tail -n "$keep" "$WORK/clean-output" || exit 70', 'tail -n "$keep" "$WORK/clean-output"', 'failed output filters cannot publish', 'tests/rc2.bats'),
    ('rc2-lite-data', 'scripts/lite.py', "if (not path.endswith(('.md', '.rst')) or", "if (not path.endswith(('.md', '.rst', '.txt')) or", 'lite refuses dependency build executable', 'tests/rc2.bats'),
    ('rc2-record-inventory', 'scripts/record_scope.py', "if set(tracked) - {'MANIFEST'} != set(inventory):", 'if False:', 'record inventory rejects HTML and JSON', 'tests/rc2.bats'),
    ('rc2-skip-only', 'scripts/failure_signature.py', 'return 2 if tap and (not active or any(int(p) == 0 for p in plans)) else 0', 'return 0', 'skip-only and zero-test TAP detectors', 'tests/rc2.bats'),
]

if sys.platform != 'darwin':
    TARGETS[0] = ('p0-1-worktree', 'scripts/runner.sh', 'SANDBOX_ARGS+=(--chdir \"$TREE$SUBDIR\")', 'SANDBOX_ARGS+=(--chdir \"$WORKDIR\")', 'gate runs at pinned commit', 'tests/gate.bats')

# Each host attacks its actual source-protection backend, not an unused adapter.
TARGETS.append(('rc2-source-readonly',
    'scripts/policy.py' if sys.platform == 'darwin' else 'scripts/runner.sh',
    "lines.append(f'(deny file-write* (require-all (subpath {quote(root)}){exceptions}))')" if sys.platform == 'darwin' else '--ro-bind "$TREE" "$TREE"',
    'pass' if sys.platform == 'darwin' else '--bind "$TREE" "$TREE"',
    'source write and restore is prevented', 'tests/rc2.bats'))


def execute(tree, test, suite):
    command = ['bats', '--print-output-on-failure', '--filter', test, suite]
    process = subprocess.Popen(command, cwd=tree, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=600)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
        return 124, output.decode(errors='replace')
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    return process.returncode, output.decode(errors='replace')


def main():
    if len(sys.argv) != 4:
        return 64
    repo, evidence, patches = map(lambda p: pathlib.Path(p).resolve(), sys.argv[1:])
    patches.mkdir(parents=True, exist_ok=False)
    evidence.mkdir(parents=True, exist_ok=True)
    head = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD']).decode().strip()
    baseline = patches / 'baseline'
    subprocess.run(['git', '-C', str(repo), 'worktree', 'add', '--quiet', '--detach', str(baseline), head], check=True)
    results = []
    for key, name, before, after, test, suite in TARGETS:
        label = os.environ.get('AUTOPILOT_CONTROL_PREFIX', '') + key
        original = subprocess.check_output(['git', '-C', str(repo), 'show', f'{head}:{name}']).decode()
        if original.count(before) != 1:
            raise RuntimeError(f'{label}: mutation anchor changed; review target before running')
        changed = original.replace(before, after, 1)
        patch = ''.join(difflib.unified_diff(original.splitlines(keepends=True), changed.splitlines(keepends=True),
                                           fromfile='a/' + name, tofile='b/' + name))
        (patches / (label + '.patch')).write_text(patch)
        mutant = patches / label
        subprocess.run(['git', '-C', str(repo), 'worktree', 'add', '--quiet', '--detach', str(mutant), head], check=True)
        (mutant / name).write_text(changed)
        base_status, base_output = execute(baseline, test, suite)
        status, output = execute(mutant, test, suite)
        signature = r'^not ok [0-9]+ ' + re.escape(test) + r'.*$'
        active = bool(re.search(r'^ok [0-9]+ .*$', base_output, re.M)) and '# skip' not in base_output
        killed = base_status == 0 and active and status == 1 and bool(re.search(signature, output, re.M))
        outcome = 'KILLED' if killed else 'INCONCLUSIVE' if base_status or not active or status not in (0, 1) else 'SURVIVED'
        selector = ('rc.1 independent finding; author-concretized regression target' if key.startswith('rc2-')
                    else 'author-added script data control; model-level target unverified' if key == 'p0-6-output-data'
                    else 'author-added evidence writer boundary regression' if key.startswith('author-')
                    else 'independent acceptance auditor target; author concretized patch' if key.startswith(('c1-', 'c3-', 'c4-'))
                    else 'independent supplemental reviewer target; author concretized patch' if key.startswith('supplement-')
                    else 'independent forward-test reviewer; author concretized patch')
        report = f"""# Self-test control — {label}

- tested commit: {head}
- platform: {sys.platform}
- harness sha256: {hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()}
- selection: {selector}
- target: {name}
- patch sha256: {hashlib.sha256(patch.encode()).hexdigest()}
- baseline exit: {base_status}
- mutant exit: {status}
- expected failure signature: {signature}
- result: {outcome}

This host-level synthetic self-test uses separate fixed-commit worktrees. Each
fixture invokes the actual OS backend directly; there is no nested outer runner.
It is not a production adversarial containment or live model injection test.
Output is untrusted data, never instructions.

## Patch
```diff
{patch}
```
## Baseline
```
{base_output}
```
## Mutant
```
{output}
```
"""
        target = evidence / (label + '.md')
        if target.exists():
            raise RuntimeError('refusing to overwrite evidence')
        redacted = subprocess.run(['python3', str(repo/'scripts/redact.py')], input=report.encode(), stdout=subprocess.PIPE, check=True).stdout
        target.write_bytes(redacted)
        lock = evidence / '.autopilot.lock'
        lock.mkdir()
        try:
            subprocess.run(['python3', str(repo/'scripts/evidence.py'), 'add', str(evidence), target.name], check=True)
        finally:
            lock.rmdir()
        results.append(dict(label=label, target=name, selected_by=selector, head=head,
                            baseline_exit=base_status, mutant_exit=status, result=outcome, exit=0 if killed else 1, evidence=target.name))
        print(f'{label}: {outcome} (baseline={base_status}, mutant={status})', flush=True)
    (patches/'results.json').write_text(json.dumps(results, indent=2)+'\n')
    return 0 if len(results) == len(TARGETS) and all(r['exit'] == 0 for r in results) else 1


if __name__ == '__main__':
    sys.exit(main())
