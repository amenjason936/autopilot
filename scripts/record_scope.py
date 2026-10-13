#!/usr/bin/env python3
"""Only dedicated, committed policy paths may be omitted from code checks."""
import json
import pathlib
import subprocess
import sys


def main():
    repo, commit, evidence, record = sys.argv[1:]
    top = pathlib.Path(repo)
    allowed = json.load(sys.stdin)['record_paths']
    reserved = {'src', 'source', 'scripts', 'lib', 'tests', 'test', 'node_modules',
                '.git', '.github', '.codex', '.agents', 'build', 'dist'}
    data_suffixes = {'.md', '.txt', '.json', '.log', '.csv', '.tsv', '.png', '.jpg',
                     '.jpeg', '.svg', '.pdf', '.bundle', '.html', '.xml'}
    for kind, raw in (('evidence_dir', evidence), ('run_record', record)):
        if not raw:
            continue
        path = pathlib.Path(raw)
        try:
            relative = path.relative_to(top)
        except ValueError:
            continue
        if (str(relative) != allowed.get(kind) or relative == pathlib.Path('.')
                or reserved.intersection(x.lower() for x in relative.parts)):
            return 64
        if kind == 'run_record' and (path.is_dir() or path.suffix != '.md'):
            return 64
        entries = subprocess.check_output(['git', '-C', repo, 'ls-tree', '-r', '-z', commit, '--', str(relative)])
        for entry in filter(None, entries.split(b'\0')):
            metadata, name = entry.split(b'\t', 1)
            file = pathlib.Path(name.decode('utf-8'))
            if metadata.split()[0] != b'100644' or (file.name != 'MANIFEST' and file.suffix not in data_suffixes):
                return 64
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError):
        sys.exit(64)
