#!/usr/bin/env python3
"""Which recorded mutants still stand at the current tested commit.

  mutant-status.py [--docs GLOB]... [--check] REPO EVIDENCE-DIR [COMMIT]

A mutant result is tied to its tested commit. A later commit does not make it
stale when everything that changed since is one of:
  - a docs path (--docs, repeatable; e.g. '*.md', 'docs/**'), or
  - a test file (the detector's own files, or a path that looks like a test)
    whose change only APPENDS lines after its old end, none of which can exit,
    return, skip or swallow failures (exit, return, sys.exit, process.exit,
    skip, .only, xfail, trap, set +e, exec, `|| true`), so existing assertions
    still run unchanged. Flags and environment are not tracked: a changed
    gate setting means a rerun by hand.
Anything else — the mutated file, other source files, deleted or edited test
lines, helpers the detector runs — means rerun it under a new label.
Record paths (the policy's evidence directory and run record) never count.

Prints one row per mutant evidence file: label, result, tested commit, status
(current / rerun) and the reason. Exit 0; with --check, exit 1 when any
KILLED mutant needs a rerun. Only verifies against MANIFEST-listed files.
"""
import fnmatch
import json
import pathlib
import re
import subprocess
import sys

TEST_PATTERNS = ('test/*', 'tests/*', '*/test/*', '*/tests/*', '*/Testing/*', 'Testing/*', '__tests__/*',
                 '*/__tests__/*', 'test_*.py', '*/test_*.py', '*_test.py', '*_test.go', '*.test.*', '*.spec.*', '*.bats')


def git(repo, *args):
    return subprocess.check_output(['git', '-c', 'core.hooksPath=/dev/null', '-C', repo, *args], stderr=subprocess.DEVNULL).decode()


def parse(path):
    text = path.read_text(encoding='utf-8', errors='replace')
    if not text.startswith('# Mutant'):
        return None
    tested = re.search(r'^- tested commit: ([0-9a-f]{40,64})$', text, re.M)
    # Only the runner-written footer counts: the file's last two lines are
    # `- finished: …` and `- result: …`. A result line inside command output
    # can never be the last line (issue #8 item 1).
    result = re.search(r'\n- finished: [^\n]*\n- result: ([A-Z]+)[^\n]*\n\Z', text)
    mutated = re.search(r'^- mutated files: (.+)$', text, re.M)
    commands = re.findall(r'^## baseline \(unpatched\)\n\n```sh\n(.*?)\n```', text, re.M | re.S)
    if not tested:
        return None
    return dict(tested=tested[1], result=result[1] if result else 'INCOMPLETE',
                mutated=[m.strip() for m in mutated[1].split(',')] if mutated else [],
                command=' '.join(commands))


# Added lines that can stop or skip what runs after them: their presence in a
# test change means a rerun even when nothing was deleted (issue #8).
DISABLING = re.compile(r'(?i)(?:^|[\s;{(])(?:exit|return|sys\.exit|os\._exit|process\.exit|quit|skip\w*|xfail|'
                       r'\.only|\.skip|pytest\.mark|unittest\.skip|trap|set\s+\+e|exec|raise\s+SystemExit)\b|\|\|\s*true')


def appended_inert(repo, old, new, path):
    """True when PATH's change only appends lines after the old end, none of them able to disable checks."""
    try:
        old_lines = git(repo, 'show', f'{old}:{path}').count('\n')
        diff = git(repo, 'diff', '-U0', '--no-renames', f'{old}..{new}', '--', path)
    except subprocess.CalledProcessError:
        return False
    for line in diff.splitlines():
        hunk = re.match(r'@@ -(\d+)(?:,(\d+))? \+\d+(?:,\d+)? @@', line)
        if hunk:
            start, count = int(hunk[1]), int(hunk[2] if hunk[2] is not None else 1)
            if count != 0 or start < old_lines:
                return False
        elif line.startswith('+') and not line.startswith('+++') and DISABLING.search(line[1:]):
            return False
    return True


def classify(repo, mutant, commit, docs, records):
    if mutant['tested'] == commit:
        return 'current', 'same tested commit'
    try:
        rows = git(repo, 'diff', '--numstat', '--no-renames', f"{mutant['tested']}..{commit}").splitlines()
    except subprocess.CalledProcessError:
        return 'rerun', 'tested commit is not an ancestor in this repository'
    detector = set(re.findall(r'[\w./-]+\.\w+', mutant['command']))
    reasons = []
    for row in rows:
        added, deleted, path = row.split('\t', 2)
        if any(path == r or path.startswith(r.rstrip('/') + '/') for r in records):
            continue
        if any(fnmatch.fnmatch(path, g) for g in docs):
            continue
        if path in mutant['mutated']:
            reasons.append(f'{path} (mutated file) changed')
            continue
        is_test = path in detector or any(fnmatch.fnmatch(path, p) for p in TEST_PATTERNS)
        if is_test and deleted == '0' and added != '-' and appended_inert(repo, mutant['tested'], commit, path):
            continue
        reasons.append(f'{path} changed' + (' (test change is not an inert append)' if is_test else ''))
    return ('rerun', '; '.join(reasons)) if reasons else ('current', 'only docs, record paths or added test lines changed')


def main():
    args, docs, check = sys.argv[1:], [], False
    while args and args[0].startswith('--'):
        if args[0] == '--docs' and len(args) > 1:
            docs.append(args[1]); args = args[2:]
        elif args[0] == '--check':
            check = True; args = args[1:]
        else:
            print(__doc__.split('\n\n')[1], file=sys.stderr); return 64
    if len(args) not in (2, 3):
        print(__doc__.split('\n\n')[1], file=sys.stderr); return 64
    repo, evidence = args[0], pathlib.Path(args[1])
    commit = git(repo, 'rev-parse', '--verify', (args[2] if len(args) == 3 else 'HEAD') + '^{commit}').strip()
    records = []
    try:
        policy = json.loads(git(repo, 'show', f'{commit}:docs/autopilot-policy.json'))
        records = [v for v in policy.get('record_paths', {}).values() if v]
    except (subprocess.CalledProcessError, ValueError):
        pass
    listed = [line.split('  ', 1)[1] for line in (evidence / 'MANIFEST').read_text().splitlines() if '  ' in line]
    stale = 0
    for name in listed:
        mutant = parse(evidence / name)
        if mutant is None:
            continue
        status, reason = classify(repo, mutant, commit, docs, records)
        if status == 'rerun' and mutant['result'] == 'KILLED':
            stale += 1
        print(f"{name}\t{mutant['result']}\t{mutant['tested'][:12]}\t{status}\t{reason}")
    print(f'# tested commit {commit[:12]}: {stale} KILLED mutant(s) need a rerun', file=sys.stderr)
    return 1 if check and stale else 0


if __name__ == '__main__':
    sys.exit(main())
