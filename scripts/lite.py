#!/usr/bin/env python3
import json
import subprocess
import sys


def main():
    repo, base, head, config = sys.argv[1:]
    try:
        data = json.load(open(config, encoding='utf-8'))
    except (OSError, ValueError):
        return 64
    if (not isinstance(data, dict) or set(data) != {'stages', 'network', 'publish', 'risk'} or
            type(data['stages']) is not int or type(data['network']) is not bool or type(data['publish']) is not bool or not isinstance(data['risk'], str)):
        return 64
    def git(*args):
        return subprocess.check_output(['git', '-C', repo, *args], stderr=subprocess.DEVNULL)
    try:
        base = git('rev-parse', '--verify', base + '^{commit}').strip().decode()
        head = git('rev-parse', '--verify', head + '^{commit}').strip().decode()
        delta = git('diff', '--no-ext-diff', '--no-renames', '--numstat', '-z', base, head)
        changed = 0
        for row in filter(None, delta.split(b'\0')):
            added, removed, name = row.split(b'\t', 2)
            # Conservative, deterministic eligibility. Runtime edits need full
            # review even when a one-line change looks harmless to its author.
            path = name.decode('utf-8').lower()
            if (not path.endswith(('.md', '.rst', '.txt')) or
                    any(part in path for part in ('skill.md', 'agents.md', 'brief', 'policy', 'contract',
                                                  'auth', 'security', 'migration', 'lockfile', '.github/'))):
                print('lite refused: executable or safety-sensitive change')
                return 1
            if added == b'-' or removed == b'-':
                print('lite refused: binary changes')
                return 1
            changed += int(added) + int(removed)
        modes = git('diff', '--no-ext-diff', '--raw', base, head).decode()
        if any('160000' in line.split('\t')[0] or '120000' in line.split('\t')[0] for line in modes.splitlines()):
            print('lite refused: submodule or symlink changes')
            return 1
    except (subprocess.CalledProcessError, ValueError):
        return 65
    eligible = changed <= 50 and data == {'stages': 1, 'network': False, 'publish': False, 'risk': 'documentation-only'}
    print(f'lite {"eligible" if eligible else "refused"}: {changed} changed lines; landing audit remains mandatory')
    return 0 if eligible else 1


if __name__ == '__main__':
    sys.exit(main())
