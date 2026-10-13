#!/usr/bin/env python3
"""Run repeatable regression mutations selected from an independent review.

This is an execution-data negative control, not proof of LLM prompt-injection
resistance. Patches and evidence are retained; a non-KILLED result fails the run.
"""
import difflib
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
    ('rc2-policy-selection', 'scripts/policy.py', "path = os.environ.get('GATE_POLICY', 'docs/autopilot-policy.json')", "path = 'docs/autopilot-policy.json'", 'alternate policy controls review dispatch', 'tests/rc2.bats'),
    ('rc2-git-errors', 'scripts/runner.sh', 'state="$(cd "$TOP" && git_code status --porcelain)" || return 1', 'state="$(cd "$TOP" && git_code status --porcelain)"', 'failed git status with empty output', 'tests/rc2.bats'),
    ('rc2-source-snapshot', 'scripts/source_state.py', 'if actual != json.loads(target.read_text()):', 'if False:', 'applied mutant snapshot rejects extra edits', 'tests/rc2.bats'),
    ('rc2-filter-errors', 'scripts/runner.sh', 'tail -n "$keep" "$WORK/clean-output" || exit 70', 'tail -n "$keep" "$WORK/clean-output"', 'failed output filters cannot publish', 'tests/rc2.bats'),
    ('rc2-lite-data', 'scripts/lite.py', "if (not path.endswith(('.md', '.rst')) or", "if (not path.endswith(('.md', '.rst', '.txt')) or", 'lite refuses dependency build executable', 'tests/rc2.bats'),
    ('rc2-record-inventory', 'scripts/record_scope.py', "if set(tracked) - {'MANIFEST'} != set(inventory):", 'if False:', 'record inventory rejects HTML and JSON', 'tests/rc2.bats'),
    ('rc2-skip-only', 'scripts/failure_signature.py', 'return 2 if plans and (not active or any(int(p) == 0 for p in plans)) else 0', 'return 0', 'skip-only and zero-test TAP detectors', 'tests/rc2.bats'),
]

# Each host attacks its actual source-protection backend, not an unused adapter.
TARGETS.append(('rc2-source-readonly',
    'scripts/policy.py' if sys.platform == 'darwin' else 'scripts/runner.sh',
    "lines.append(f'(deny file-write* (require-all (subpath {quote(root)}){exceptions}))')" if sys.platform == 'darwin' else '--ro-bind "$TREE" "$TREE"',
    'pass' if sys.platform == 'darwin' else '--bind "$TREE" "$TREE"',
    'source write and restore is prevented', 'tests/rc2.bats'))


def main():
    if len(sys.argv) != 4:
        return 64
    repo, evidence, patches = map(lambda p: pathlib.Path(p).resolve(), sys.argv[1:])
    patches.mkdir(parents=True, exist_ok=False)
    evidence.mkdir(parents=True, exist_ok=True)
    head = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD']).decode().strip()
    results = []
    for key, name, before, after, test, suite in TARGETS:
        label = os.environ.get("AUTOPILOT_CONTROL_PREFIX", "") + key
        original = subprocess.check_output(['git', '-C', str(repo), 'show', f'{head}:{name}']).decode()
        if original.count(before) != 1:
            raise RuntimeError(f'{label}: mutation anchor changed; review target before running')
        changed = original.replace(before, after, 1)
        patch = ''.join(difflib.unified_diff(original.splitlines(keepends=True), changed.splitlines(keepends=True),
                                           fromfile='a/' + name, tofile='b/' + name))
        target = patches / (label + '.patch')
        target.write_text(patch)
        command = f"bats --print-output-on-failure --filter '{test}' {suite}"
        status = subprocess.call(['bash', str(repo/'scripts/run-mutant.sh'), str(repo),
                                  str(evidence/(label+'.md')), label, str(target), command],
                                 env={**os.environ, 'MUTANT_FAILURE_REGEX': r'^not ok [0-9]+ ' + re.escape(test) + r'.*$'})
        selector = ('rc.1 independent finding; author-concretized regression target' if key.startswith('rc2-')
                    else 'author-added script data control; model-level target unverified' if key == 'p0-6-output-data'
                    else 'author-added evidence writer boundary regression' if key.startswith('author-')
                    else 'independent acceptance auditor target; author concretized patch' if key.startswith(('c1-', 'c3-', 'c4-'))
                    else 'independent supplemental reviewer target; author concretized patch' if key.startswith('supplement-')
                    else 'independent forward-test reviewer; author concretized patch')
        results.append(dict(label=label, target=name, selected_by=selector,
                            head=head, exit=status, evidence=label+'.md'))
        if status != 0:
            break
    (patches/'results.json').write_text(json.dumps(results, indent=2)+'\n')
    return 0 if len(results) == len(TARGETS) and all(r['exit'] == 0 for r in results) else 1


if __name__ == '__main__':
    sys.exit(main())
