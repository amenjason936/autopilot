#!/usr/bin/env python3
"""Run repeatable regression mutations selected from an independent review.

This is an execution-data negative control, not proof of LLM prompt-injection
resistance. Patches and evidence are retained; a non-KILLED result fails the run.
"""
import difflib
import json
import pathlib
import subprocess
import sys

# Targets were independently specified in validation/independent-review.md.
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
]


def main():
    if len(sys.argv) != 4:
        return 64
    repo, evidence, patches = map(lambda p: pathlib.Path(p).resolve(), sys.argv[1:])
    patches.mkdir(parents=True, exist_ok=False)
    evidence.mkdir(parents=True, exist_ok=True)
    head = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD']).decode().strip()
    results = []
    for label, name, before, after, test, suite in TARGETS:
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
                                  str(evidence/(label+'.md')), label, str(target), command])
        results.append(dict(label=label, target=name, selected_by='independent forward-test reviewer; author concretized patch',
                            head=head, exit=status, evidence=label+'.md'))
        if status != 0:
            break
    (patches/'results.json').write_text(json.dumps(results, indent=2)+'\n')
    return 0 if len(results) == len(TARGETS) and all(r['exit'] == 0 for r in results) else 1


if __name__ == '__main__':
    sys.exit(main())
