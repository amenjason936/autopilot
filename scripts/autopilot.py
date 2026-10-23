#!/usr/bin/env python3
"""Local project setup: preview drafts, inspect setup, or run the existing doctor.

This entry point never runs project checks, commits configuration or approves a
run. Existing runner and policy helpers retain their execution semantics.
"""
import argparse
import json
import os
import pathlib
import re
import shlex
import stat
import subprocess
import sys

sys.dont_write_bytecode = True
from policy import normalize  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
POLICY = 'docs/autopilot-policy.json'
CONTRACT = 'docs/autopilot.md'
RECORD = 'docs/runs/run.md'
MAX_FILE = 1_000_000


class SetupError(Exception):
    def __init__(self, message, code=64):
        super().__init__(message)
        self.code = code


def git_environment():
    env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
    env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull,
               GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0')
    return env


def git(repo, *args):
    # Read-only plumbing needs neither user Git overrides nor repo callbacks.
    return subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-c',
                           'core.fsmonitor=false', '-C', str(repo), *args],
                          env=git_environment(), capture_output=True, timeout=30)


def project(path):
    result = git(path, 'rev-parse', '--show-toplevel')
    if result.returncode:
        raise SetupError('use an existing Git working tree', 65)
    repo = pathlib.Path(os.fsdecode(result.stdout).rstrip('\n')).resolve()
    result = git(repo, 'rev-parse', '--verify', 'HEAD^{commit}')
    if result.returncode:
        raise SetupError('create the initial project commit before setup', 65)
    return repo, result.stdout.decode().strip()


def relative(name):
    if (not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9_./-]+', name)
            or name.startswith('/') or any(p in ('', '.', '..', '.git') for p in name.split('/'))):
        raise SetupError('configuration paths must stay inside the repository')
    return pathlib.Path(name)


def safe_path(repo, name):
    path = repo
    parts = relative(name).parts
    for i, part in enumerate(parts):
        path = path / part
        if path.is_symlink():
            raise SetupError('symlink configuration path refused: ' + name)
        if path.exists():
            mode = path.stat().st_mode
            if i < len(parts) - 1:
                if not stat.S_ISDIR(mode) or (path / '.git').exists():
                    raise SetupError('configuration parent is not a plain directory: ' + name)
            elif not stat.S_ISREG(mode):
                raise SetupError('configuration must be a regular file: ' + name)
    return path


def read_file(repo, name):
    path = safe_path(repo, name)
    if not path.exists():
        return None
    if path.stat().st_size > MAX_FILE:
        raise SetupError('configuration file exceeds 1 MB: ' + name)
    return path.read_bytes()


def blank_record(template):
    """Keep the canonical headings/instructions, omit illustrative table rows."""
    lines, in_table = [], False
    for line in template.splitlines():
        if line.startswith('|'):
            if not in_table or re.fullmatch(r'[| :\-]+', line):
                lines.append(line)
            in_table = True
        else:
            in_table = False
            lines.append(line)
    return '\n'.join(lines) + '\n'


def drafts(repo, head, goal, checks):
    if any(ord(c) < 32 for c in goal) or not goal.strip():
        raise SetupError('--goal must be a non-empty single line')
    for command in checks:
        if not command.strip() or any(ord(c) < 32 for c in command):
            raise SetupError('each --check must be a non-empty single line')
    policy = dict(version=1, sandbox='env-clean', deny_network=True,
                  deny_paths=[], read_paths=[], env=[], write_dirs=[], fallback='park',
                  record_paths=dict(evidence_dir='docs/evidence', run_record=RECORD))
    # Validate through the same rules as the runner, without freezing a
    # machine-specific backend or importing environment overrides into the draft.
    normalize(policy)
    contract = (ROOT / 'CONTRACT-TEMPLATE.md').read_text().replace('<project>', repo.name, 1)
    proposed = '\n### Proposed checks (not executed or authorized by setup)\n\n'
    if checks:
        for command in checks:
            fence = '`' * max(3, max((len(x) + 1 for x in re.findall(r'`+', command)), default=3))
            proposed += f'{fence}sh\n{command}\n{fence}\n\n'
        proposed += 'Review these commands and complete the Machine gate table above.\n'
    else:
        proposed += 'Choose the project checks and complete the Machine gate table above.\n'
    contract = contract.replace('Gate settings (environment for `run-gate.sh`):',
                                proposed + '\nGate settings (environment for `run-gate.sh`):', 1)
    record = blank_record((ROOT / 'RUN-RECORD-TEMPLATE.md').read_text())
    record = record.replace('# <run title>', '# Proposed run', 1)
    record = record.replace('- cut from: <full commit>', '- cut from: ' + head, 1)
    record = record.replace('- tested commit: <full commit>', '- tested commit: not tested', 1)
    record = record.replace('What the human asked for, in their words.', goal, 1)
    record = record.replace('## Goal', '> Setup draft: no authorization, checks, evidence or reviews have been recorded.\n\n## Goal', 1)
    return {CONTRACT: contract, POLICY: json.dumps(policy, indent=2) + '\n', RECORD: record}


def write_new(repo, name, content):
    """Exclusive files and no-follow directory traversal; keep partials on error."""
    parts = relative(name).parts
    directory = os.open(repo, os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in parts[:-1]:
            try:
                os.mkdir(part, mode=0o755, dir_fd=directory)
            except FileExistsError:
                pass
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
            os.close(directory)
            directory = child
        fd = os.open(parts[-1], os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=directory)
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
    finally:
        os.close(directory)


def initialize(args):
    repo, head = project(args.repo)
    if os.environ.get('GATE_POLICY', POLICY) != POLICY:
        raise SetupError('init uses docs/autopilot-policy.json; unset GATE_POLICY or keep the existing custom setup')
    files = drafts(repo, head, args.goal, args.check)
    # Check the whole bundle before creating anything. Never use --force or
    # silently repair an existing setup, even when its contents look generated.
    for name in files:
        if safe_path(repo, name).exists():
            raise SetupError('setup file already exists; use status and edit it deliberately: ' + name, 73)
        ignored = git(repo, 'check-ignore', '-q', '--no-index', '--', name)
        if ignored.returncode == 0:
            raise SetupError('setup path is ignored by Git: ' + name)
        if ignored.returncode != 1:
            raise SetupError('cannot check ignored setup paths', 65)
    written = []
    if args.write:
        try:
            for name, content in files.items():
                write_new(repo, name, content)
                written.append(name)
        except OSError as error:
            raise SetupError('setup stopped; existing files and any partial writes are preserved. '
                             'Completed: ' + ', '.join(written) + '; ' + str(error), 74) from error
    result = {'mode': 'written' if args.write else 'preview', 'repo': str(repo), 'head': head,
              'files': files, 'executed_checks': False,
              'next': ['Review the proposed contract, red lines, gate commands and measurable acceptance criteria.',
                       'Commit the reviewed configuration, then run the doctor and the gate command preview.',
                       'Continue the explicit Autopilot takeoff with the existing authorization rules.']}
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print('Proposed setup ' + ('written' if args.write else 'preview — no files written'))
        print('Policy: offline OS sandbox selection; fallback: park; no dependency sharing.')
        for name, content in files.items():
            print('\n--- ' + name + ' ---\n' + content)
        if not args.write:
            print('To create these drafts, repeat this command with --write.')
        for i, step in enumerate(result['next'], 1):
            print(f'{i}. {step}')
        print('Doctor: ' + shlex.join(['python3', str(ROOT / 'scripts/autopilot.py'), 'doctor', str(repo)]))


def file_state(repo, head, name):
    working = read_file(repo, name)
    committed = git(repo, 'cat-file', 'blob', f'{head}:{name}')
    if working is None:
        return 'missing'
    if committed.returncode:
        return 'uncommitted'
    return 'committed' if working == committed.stdout else 'modified'


def status(args):
    repo, head = project(args.repo)
    policy_path = os.environ.get('GATE_POLICY', POLICY)
    relative(policy_path)
    raw = read_file(repo, policy_path)
    paths = [CONTRACT, policy_path]
    policy_state = 'missing'
    needs = []
    if raw is not None:
        try:
            policy = normalize(json.loads(raw))
        except (ValueError, TypeError, AttributeError):
            raise SetupError('working-tree policy is invalid: ' + policy_path)
        policy_state = 'valid working-tree policy'
        run_record = policy['record_paths'].get('run_record')
        if run_record:
            paths.append(run_record)
        else:
            needs.append('No run record is configured in record_paths.run_record.')
    else:
        paths.append(RECORD)
    files = {name: file_state(repo, head, name) for name in dict.fromkeys(paths)}
    if needs or any(value != 'committed' for value in files.values()):
        next_step = 'Review missing or uncommitted configuration; use init only for a project without setup files.'
    else:
        next_step = 'Run doctor, preview the gate commands, and follow the approved takeoff or resume procedure.'
    result = {'repo': str(repo), 'head': head, 'policy': policy_state, 'files': files,
              'paths_from': 'working-tree policy; gates use the committed policy',
              'needs': needs, 'verification': 'setup inspection only; authorization, gates and evidence are not evaluated',
              'next': next_step}
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print('Setup status at ' + head)
        for name, state in files.items():
            print(f'  {name}: {state}')
        for need in needs:
            print('Needs: ' + need)
        print(result['verification'])
        print('Next: ' + next_step)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    init = sub.add_parser('init', help='preview proposed setup; --write creates new files only')
    init.add_argument('repo')
    init.add_argument('--goal', required=True)
    init.add_argument('--check', action='append', default=[], help='proposed command; never executed by init')
    init.add_argument('--write', action='store_true')
    init.add_argument('--json', action='store_true')
    show = sub.add_parser('status', help='inspect draft versus committed configuration without running project code')
    show.add_argument('repo')
    show.add_argument('--json', action='store_true')
    doctor = sub.add_parser('doctor', help='run the existing host diagnosis without --fix')
    doctor.add_argument('repo')
    args = parser.parse_args()
    if args.command == 'init':
        initialize(args)
    elif args.command == 'status':
        status(args)
    else:
        repo, _ = project(args.repo)
        return subprocess.run(['bash', str(ROOT / 'scripts/host-doctor.sh'), str(repo)], env=git_environment()).returncode
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SetupError as error:
        print('autopilot: ' + str(error), file=sys.stderr)
        sys.exit(error.code)
    except (OSError, UnicodeError, subprocess.TimeoutExpired) as error:
        print('autopilot: cannot inspect setup: ' + str(error), file=sys.stderr)
        sys.exit(74)
