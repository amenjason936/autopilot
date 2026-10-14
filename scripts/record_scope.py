#!/usr/bin/env python3
"""Only registered artifacts in committed dedicated paths may be excluded."""
import hashlib
import json
import pathlib
import re
import subprocess
import sys


def refuse(reason):
    print('record paths: ' + reason, file=sys.stderr)
    return 64


def manifest(raw):
    records = {}
    for line in raw.decode('utf-8').splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  ([A-Za-z0-9][A-Za-z0-9._-]*)', line)
        if not match or match[2] in records or match[2] in ('.', '..', 'MANIFEST') or '.partial' in match[2]:
            raise ValueError('invalid artifact inventory')
        records[match[2]] = match[1]
    return records


def main():
    repo, commit, evidence, record = sys.argv[1:]
    top = pathlib.Path(repo)
    allowed = json.load(sys.stdin)['record_paths']
    reserved = {'src', 'source', 'scripts', 'lib', 'tests', 'test', 'node_modules',
                '.git', '.github', '.codex', '.agents', 'build', 'dist'}
    def git(*args):
        return subprocess.check_output(['git', '-C', repo, *args], stderr=subprocess.DEVNULL)
    for kind, raw in (('evidence_dir', evidence), ('run_record', record)):
        if not raw:
            continue
        path = pathlib.Path(raw)
        try:
            relative = path.relative_to(top)
        except ValueError:
            continue
        if str(relative) != allowed.get(kind):
            return refuse(f'{relative} is not the policy\'s record_paths.{kind} ({allowed.get(kind)})')
        if relative == pathlib.Path('.') or reserved.intersection(x.lower() for x in relative.parts):
            return refuse(f'{relative} is the top or a reserved source directory')
        if kind == 'run_record':
            if path.is_dir() or path.suffix != '.md':
                return refuse(f'{relative} must be a .md file')
            continue
        # Every existing tracked artifact must be in the pinned inventory. File
        # suffixes do not distinguish HTML/JSON application source from evidence.
        entries = git('ls-tree', '-r', '-z', commit, '--', str(relative))
        tracked = {}
        for entry in filter(None, entries.split(b'\0')):
            metadata, name = entry.split(b'\t', 1)
            file = pathlib.Path(name.decode('utf-8')).relative_to(relative)
            if metadata.split()[0] != b'100644' or len(file.parts) != 1:
                return refuse(f'{relative}/{file} is not a plain committed file at the top of the evidence directory')
            tracked[str(file)] = metadata.split()[2].decode()
        inventory = manifest(git('cat-file', 'blob', tracked['MANIFEST'])) if 'MANIFEST' in tracked else {}
        untracked = sorted(set(inventory) - set(tracked))
        if untracked:
            return refuse(f'MANIFEST at {commit[:12]} lists files that are not committed: {", ".join(untracked)} '
                          '(a .gitignore rule may have skipped them; commit them with git add -f)')
        unlisted = sorted(set(tracked) - {'MANIFEST'} - set(inventory))
        if unlisted:
            return refuse(f'committed files missing from MANIFEST at {commit[:12]}: {", ".join(unlisted)}')
        for name, expected in inventory.items():
            if hashlib.sha256(git('cat-file', 'blob', tracked[name])).hexdigest() != expected:
                return refuse(f'{relative}/{name} at {commit[:12]} does not match its MANIFEST hash')
        # Newly generated records may remain uncommitted, but an unregistered
        # source file cannot disappear merely because it lives in this directory.
        if path.exists():
            live_manifest = path/'MANIFEST'
            if live_manifest.is_symlink():
                return refuse('symlink MANIFEST')
            live = manifest(live_manifest.read_bytes()) if live_manifest.is_file() else {}
            for item in path.iterdir():
                if item.is_symlink():
                    return refuse(f'symlink in the evidence directory: {item.name}')
                if item.name == '.autopilot.lock' and item.is_dir():
                    if any(p.name != 'owner' or not p.is_file() or p.is_symlink() for p in item.iterdir()):
                        return refuse('unexpected content in the evidence lock')
                    continue
                if not item.is_file():
                    return refuse(f'not a regular file: {item.name}')
                if item.name == 'MANIFEST':
                    continue
                if re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*\.md\.partial(?:\.[0-9]{8}T[0-9]{6}Z\.[0-9]+)?', item.name):
                    continue
                if item.name not in live:
                    return refuse(f'{item.name} in the evidence directory is not in MANIFEST; register it with evidence.py register')
                if hashlib.sha256(item.read_bytes()).hexdigest() != live[item.name]:
                    return refuse(f'{item.name} does not match its MANIFEST hash')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, UnicodeError, subprocess.CalledProcessError):
        sys.exit(64)
