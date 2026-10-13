#!/usr/bin/env python3
"""Install a complete local Autopilot package, retaining replaced installations."""
import argparse
import datetime
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import uuid


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def destination(host):
    home = pathlib.Path.home()
    roots = {
        'codex': pathlib.Path(os.environ.get('CODEX_HOME', str(home / '.codex'))),
        'claude-code': pathlib.Path(os.environ.get('CLAUDE_CONFIG_DIR', str(home / '.claude'))),
        'zcode': home / '.agents',
        'ccmr': home / '.claude-gateway',
    }
    return roots[host] / 'skills' / 'autopilot'


def inventory(root):
    result = {}
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('package symlinks are not supported: ' + str(path))
        if path.is_file():
            result[path.relative_to(root).as_posix()] = digest(path)
    return result


def package_files(source):
    if (source / '.git').exists():
        def git(*args):
            return subprocess.check_output(['git', '-C', str(source), *args])
        if git('status', '--porcelain', '--untracked-files=no').strip():
            raise ValueError('commit tracked package changes before installation')
        head = git('rev-parse', 'HEAD').decode().strip()
        files = [pathlib.Path(p.decode()) for p in git('ls-files', '-z').split(b'\0') if p]
    else:
        head = None
        files = [p.relative_to(source) for p in source.rglob('*')
                 if p.is_file() and not any(x in ('.git', '__pycache__', '.DS_Store') for x in p.relative_to(source).parts)
                 and p.name != 'INSTALLATION.json']
    for relative in files:
        if relative.is_absolute() or '..' in relative.parts or (source / relative).is_symlink():
            raise ValueError('unsafe package member: ' + str(relative))
    for required in ('SKILL.md', 'VERSION', 'agents/openai.yaml', 'scripts/run-gate.sh', 'AUDITOR-BRIEF.md'):
        if pathlib.Path(required) not in files:
            raise ValueError('incomplete package: ' + required)
    return files, head


def adapt_skill(text, host):
    if host == 'codex':
        return text
    if not text.startswith('---\n') or '\n---\n' not in text[4:]:
        raise ValueError('missing skill frontmatter')
    end = text.index('\n---\n', 4)
    lines = [line for line in text[4:end].splitlines()
             if not line.startswith('disable-model-invocation:')]
    return '---\n' + '\n'.join(lines + ['disable-model-invocation: true']) + text[end:]


def install(args):
    source = pathlib.Path(__file__).resolve().parent.parent
    dest = pathlib.Path(args.dest).expanduser().absolute() if args.dest else destination(args.host).absolute()
    # Resolve parent aliases without following the existing installation symlink.
    dest = dest.parent.resolve() / dest.name
    if dest.name != 'autopilot':
        raise ValueError('destination must be the autopilot skill folder')
    if source == dest or source in dest.parents or dest in source.parents:
        raise ValueError('source and destination must not overlap')
    exists = dest.exists() or dest.is_symlink()
    if exists and not args.replace:
        raise ValueError('destination exists; use --replace to retain it in a backup and replace it')
    if exists and not dest.is_dir():
        raise ValueError('existing installation must be a directory or a valid directory symlink')
    files, head = package_files(source)
    backup_root = pathlib.Path(args.backup_root).expanduser().absolute() if args.backup_root else dest.parent.parent / 'skill-backups'
    backup_root = backup_root.resolve()
    if backup_root == dest or dest in backup_root.parents or backup_root == source or source in backup_root.parents:
        raise ValueError('backup location must be outside source and installed skill')
    receipt = {'host': args.host, 'source_commit': head, 'version': (source / 'VERSION').read_text().strip(),
               'destination': str(dest), 'file_count': len(files), 'replaces_existing': exists,
               'frontmatter_adapter': args.host != 'codex'}
    if args.dry_run:
        print(json.dumps({**receipt, 'backup_root': str(backup_root), 'dry_run': True}, indent=2))
        return
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
    backup = backup_root / ('autopilot-' + stamp)
    backup.mkdir(parents=True, exist_ok=False)
    dest.parent.mkdir(parents=True, exist_ok=True)
    # Retain failed staging directories for inspection; never delete an old copy.
    stage = pathlib.Path(tempfile.mkdtemp(prefix='.autopilot-stage-', dir=dest.parent))
    for relative in files:
        target = stage / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if head:
            target.write_bytes(subprocess.check_output(['git', '-C', str(source), 'show', head + ':' + relative.as_posix()]))
            mode = subprocess.check_output(['git', '-C', str(source), 'ls-tree', head, '--', relative.as_posix()]).split()[0]
            target.chmod(0o755 if mode == b'100755' else 0o644)
        else:
            shutil.copy2(source / relative, target)
    source_hashes = inventory(stage)
    skill = stage / 'SKILL.md'
    skill.write_text(adapt_skill(skill.read_text(), args.host))
    expected = inventory(stage)
    for name, checksum in source_hashes.items():
        if name != 'SKILL.md' or args.host == 'codex':
            if expected[name] != checksum:
                raise ValueError('staged bytes differ: ' + name)
    receipt.update({'backup': str(backup), 'source_sha256': source_hashes, 'installed_sha256': expected})
    if exists:
        receipt['previous_sha256'] = inventory(dest.resolve())
        if dest.is_symlink():
            receipt['previous_symlink'] = os.readlink(dest)
            shutil.copytree(dest.resolve(), backup / 'previous-target', symlinks=True)
            if inventory(backup / 'previous-target') != receipt['previous_sha256']:
                raise ValueError('symlink target backup verification failed')
        dest.rename(backup / 'previous')
    try:
        stage.rename(dest)
    except OSError:
        if exists:
            (backup / 'previous').rename(dest)
        raise
    if inventory(dest) != expected:
        raise ValueError('installed package verification failed; previous copy remains at ' + str(backup))
    serialized = json.dumps(receipt, indent=2) + '\n'
    (dest / 'INSTALLATION.json').write_text(serialized)
    (backup / 'receipt.json').write_text(serialized)
    print(json.dumps({k: receipt[k] for k in ('host', 'version', 'source_commit', 'destination', 'file_count', 'backup')}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', required=True, choices=('codex', 'claude-code', 'zcode', 'ccmr'))
    parser.add_argument('--dest', help='exact autopilot folder; overrides the host default')
    parser.add_argument('--backup-root', help='retain previous copies and receipts here')
    parser.add_argument('--replace', action='store_true', help='back up and fully replace an existing installation')
    parser.add_argument('--dry-run', action='store_true', help='print the plan without writing files')
    try:
        install(parser.parse_args())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print('installation failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
