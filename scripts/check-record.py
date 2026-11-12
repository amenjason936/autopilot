#!/usr/bin/env python3
"""Check a run record's state against the rules a run must keep.

  check-record.py [--landing] [--evidence DIR] REPO RECORD [COMMIT]

RECORD and DIR are repository-relative; DIR defaults to the committed policy's
record_paths.evidence_dir. The record, MANIFEST and evidence are read from
COMMIT (default HEAD), because reviewers and a resume read committed bytes.

Checked: the status and `current:` vocabulary and their agreement; full
commits and the helper pin once flying; every proven criterion cites
registered evidence whose runner footer is `passed` or `KILLED`; mutation targets
(full mode: an adversary-selected KILLED mutant per criterion that has
targets; lite small-change: a KILLED mutant per criterion); finding statuses;
parked ids named by `current:`. At landing (--landing, or a landing/landed
`current:`): no open criterion, no open blocking finding, and current
evidence for proven criteria unless *Not verified* names the file.

It reads structure only. Whether evidence shows what a criterion says stays
with the reviewers. Exit 0 consistent; 1 violations (one per line); 64 usage
or policy; 66 the record is not committed at COMMIT.
"""
import re
import subprocess
import sys

sys.dont_write_bytecode = True
import policy  # noqa: E402  (same directory; never leave bytecode beside helpers)

STATUSES = ('planned', 'flying', 'landed', 'aborted')
CRITERION_STATUSES = ('open', 'proven', 'failed', 'parked')
FINDING_STATUSES = ('blocking-fixed', 'blocking-open', 'minor-fixed', 'minor-open', 'fixed-unreviewed',
                    'parked', 'rejected', 'approve', 'dispute')
STEP = re.compile(r'takeoff|stage \d+ build|stage \d+ (?:gate|mutant) [A-Za-z0-9._-]+|stage \d+ review r\d+(?: .*)?|'
                  r'stage \d+ record|landing preparation|landing review r\d+(?: .*)?|landing action \S.*|'
                  r'landed(?: — parked P\d+(?:, ?P\d+)*)?')
CITED = re.compile(r'[A-Za-z0-9][A-Za-z0-9._-]*\.(?:md|json|txt|png|jpg|jpeg|html|log)\b')
SHA = re.compile(r'[0-9a-f]{40}(?:[0-9a-f]{24})?')


class Snapshot:
    """Committed bytes of one repository at one commit."""

    def __init__(self, repo, commit):
        self.repo, self.commit = repo, commit

    def git(self, *args):
        return subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-C', self.repo, *args], capture_output=True)

    def read(self, path):
        proc = self.git('show', f'{self.commit}:{path}')
        return proc.stdout.decode('utf-8', errors='replace') if proc.returncode == 0 else None

    def changed_since(self, old, excluded):
        """True when code differs between OLD and the commit, record paths aside."""
        spec = ['.'] + [f':(exclude){p}' for p in excluded if p]
        return self.git('diff', '--quiet', old, self.commit, '--', *spec).returncode != 0


def header(text):
    fields = {}
    for match in re.finditer(r'^- ([a-z][a-z ]*): (.*)$', text.split('\n## ')[0], re.M):
        fields.setdefault(match[1], re.sub(r'<!--.*?-->', '', match[2]).strip())
    return fields


def section(text, title):
    match = re.search(r'^#{2,4} ' + re.escape(title) + r'[ \t]*\n(.*?)(?=^#{1,4} |\Z)', text, re.M | re.S)
    return match[1] if match else ''


def rows(text, title):
    """Data rows of the first table under TITLE, as lists of stripped cells."""
    lines = [line for line in section(text, title).splitlines() if line.startswith('|')]
    return [[cell.strip() for cell in re.split(r'(?<!\\)\|', line.strip().strip('|'))] for line in lines[2:]]


def runner_result(body):
    """(kind, tested commit, result) from runner-written structure only, or None."""
    kind = 'mutant' if body.startswith('# Mutant') else 'gate' if body.startswith('# Machine gate') else None
    if kind is None:
        return None
    tested = re.search(r'^- tested commit: ([0-9a-f]{40,64})$', body, re.M)
    footer = re.search(r'\n- finished: [^\n]*\n- result: ([A-Za-z]+)[^\n]*\n\Z', body)
    return kind, tested[1] if tested else None, footer[1] if footer else 'INCOMPLETE'


class Check:
    def __init__(self, snapshot, record_path, text, evidence_dir, landing):
        self.snap, self.record_path, self.text, self.evidence_dir = snapshot, record_path, text, evidence_dir
        self.fields = header(text)
        self.parts = [part.strip() for part in self.fields.get('current', '').split(';') if part.strip()]
        self.landing = (landing or self.fields.get('status') == 'landed'
                        or any(part.startswith(('landing review', 'landing action', 'landed')) for part in self.parts))
        self.failures, self.notes = [], []
        self.manifest = self.load_manifest()
        self.criteria = [row for row in rows(text, 'Acceptance criteria') if len(row) >= 5]

    def fail(self, message):
        self.failures.append(message)

    def load_manifest(self):
        raw = self.snap.read(f'{self.evidence_dir}/MANIFEST') if self.evidence_dir else None
        if raw is None:
            return {}
        return dict(reversed(line.split('  ', 1)) for line in raw.splitlines() if '  ' in line)

    def evidence(self, name):
        """Runner result of a registered evidence file, or a failure string."""
        if name not in self.manifest:
            return f'{name} is not in MANIFEST at {self.snap.commit[:12]}'
        return runner_result(self.snap.read(f'{self.evidence_dir}/{name}') or '')

    def check_header(self):
        status, current = self.fields.get('status', ''), self.fields.get('current', '')
        if status not in STATUSES:
            self.fail(f'status: "{status}" is not one of {", ".join(STATUSES)}')
        if not self.parts:
            self.fail('current: is missing')
        for part in self.parts:
            if not STEP.fullmatch(part):
                self.fail(f'current: "{part}" is not a step the record template lists')
        closed = any(part.startswith('landed') for part in self.parts)
        if status == 'landed' and not closed:
            self.fail(f'status landed needs current: landed, found "{current}"')
        if closed and status != 'landed':
            self.fail(f'current: "{current}" needs status landed, found {status}')
        if status == 'planned' and self.parts != ['takeoff']:
            self.fail(f'status planned needs current: takeoff, found "{current}"')
        if status in ('flying', 'landed'):
            for key in ('base', 'tested commit'):
                if not SHA.fullmatch(self.fields.get(key, '')):
                    self.fail(f'{key}: needs a full commit once the run is {status}')
            if not re.fullmatch(r'[0-9a-f]{64}', self.fields.get('helper pin', '')):
                self.fail('helper pin: needs the 64-hex inventory sha256 from the takeoff dry run')

    def check_criteria(self):
        not_verified = section(self.text, 'Not verified')
        seen = set()
        for identifier, _, _, status, cited, *_ in self.criteria:
            if identifier in seen:
                self.fail(f'{identifier} appears twice in Acceptance criteria')
            seen.add(identifier)
            if status not in CRITERION_STATUSES:
                self.fail(f'{identifier} has unknown status "{status}"')
            if status == 'open' and self.landing:
                self.fail(f'{identifier} is still open at landing')
            if status != 'proven':
                continue
            names = CITED.findall(cited)
            if not names:
                self.fail(f'{identifier} is proven but cites no evidence')
            for name in names:
                self.check_proof(identifier, name, not_verified)

    def check_proof(self, identifier, name, not_verified):
        found = self.evidence(name)
        if isinstance(found, str):
            return self.fail(f'{identifier}: {found}')
        if found is None:
            return None  # registered, not runner evidence (a report, findings, an image)
        kind, tested, result = found
        if (kind, result) not in (('gate', 'passed'), ('mutant', 'KILLED')):
            return self.fail(f'{identifier}: {name} result is {result}')
        if self.landing and tested and name not in not_verified and self.snap.changed_since(
                tested, (self.evidence_dir, self.record_path)):
            self.fail(f'{identifier}: {name} is stale: code changed after its tested commit {tested[:12]} '
                      '(rerun under a new label, or list it under Not verified)')
        return None

    def killed(self, cell):
        return any(isinstance(found, tuple) and found[0] == 'mutant' and found[2] == 'KILLED'
                   for found in map(self.evidence, CITED.findall(cell)))

    def check_mutants(self):
        mode = self.fields.get('mode', 'full')
        if 'documentation-only' in mode:
            return
        targets = [row for row in rows(self.text, 'Independent mutation targets') if len(row) >= 6]
        for identifier, _, _, status, *_ in self.criteria:
            if status != 'proven':
                continue
            mine = [row for row in targets if row[0] == identifier]
            standing = [row for row in mine if row[1] and self.killed(row[5])]
            if mode.startswith('lite'):
                if not standing:
                    self.fail(f'{identifier} has no KILLED mutant with a recorded selector (lite small-change needs one)')
            elif not mine:
                self.notes.append(f'{identifier} is proven with no mutation target: justify it or add one')
            elif not any(not row[1].lower().startswith('author') for row in standing):
                self.fail(f'{identifier} has no KILLED mutation target selected by an independent adversary')

    def check_ledger(self):
        for row in rows(self.text, 'Review findings'):
            if len(row) < 6:
                continue
            identifier, status, note = row[0], row[4], row[5]
            if status not in FINDING_STATUSES:
                self.fail(f'{identifier} has unknown status "{status}"')
            elif status == 'blocking-fixed' and not re.search(r'\b[0-9a-f]{7,64}\b', note):
                self.fail(f'{identifier} is blocking-fixed but its note names no commit')
            elif status == 'blocking-open' and self.landing:
                self.fail(f'{identifier} is blocking-open at landing')
        parked = {row[0] for row in rows(self.text, 'Parked')}
        for identifier in re.findall(r'\bP\d+\b', ' '.join(p for p in self.parts if p.startswith('landed'))):
            if identifier not in parked:
                self.fail(f'current names {identifier}, which is not in Parked')

    def run(self):
        self.check_header()
        self.check_criteria()
        self.check_mutants()
        self.check_ledger()
        return self


def summary(check):
    counts = {}
    for row in check.criteria:
        counts[row[3]] = counts.get(row[3], 0) + 1
    tally = ', '.join(f'{n} {status}' for status, n in sorted(counts.items())) or 'none'
    return (f'status {check.fields.get("status")}; current {check.fields.get("current")}; criteria: {tally}'
            + ('; landing rules applied' if check.landing else ''))


def main(argv):
    landing = '--landing' in argv
    argv = [a for a in argv if a != '--landing']
    evidence_dir = None
    if '--evidence' in argv:
        at = argv.index('--evidence')
        if at + 1 >= len(argv):
            return 64
        evidence_dir = argv[at + 1].rstrip('/')
        del argv[at:at + 2]
    if len(argv) not in (2, 3) or any(a.startswith('-') for a in argv):
        print(__doc__.split('\n\n')[1], file=sys.stderr)
        return 64
    repo, record_path = argv[0], argv[1]
    resolved = subprocess.run(['git', '-C', repo, 'rev-parse', '--verify', '--quiet',
                               (argv[2] if len(argv) == 3 else 'HEAD') + '^{commit}'], capture_output=True, text=True)
    if resolved.returncode:
        print('record check: not a commit in this repository', file=sys.stderr)
        return 64
    snapshot = Snapshot(repo, resolved.stdout.strip())
    text = snapshot.read(record_path)
    if text is None:
        print(f'record check: {record_path} is not committed at {snapshot.commit[:12]}', file=sys.stderr)
        return 66
    if evidence_dir is None:
        try:
            evidence_dir = policy.selected_policy(repo, snapshot.commit)['effective']['record_paths'].get('evidence_dir')
        except (ValueError, TypeError, OSError):
            print('record check: invalid or missing committed policy', file=sys.stderr)
            return 64
    check = Check(snapshot, record_path, text, evidence_dir, landing).run()
    if len(argv) == 2 and snapshot.git('diff', '--quiet', 'HEAD', '--', record_path).returncode != 0:
        check.fail(f'{record_path} has uncommitted changes: reviewers and a resume read the committed record')
    if not evidence_dir:
        check.notes.append('no evidence directory in the policy: pass --evidence DIR to check citations')
    for note in check.notes:
        print(f'record check: note: {note}')
    for failure in check.failures:
        print(f'record check: {failure}')
    if check.failures:
        return 1
    print(f'record check: OK — {summary(check)}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
