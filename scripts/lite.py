#!/usr/bin/env python3
"""Deterministic lite eligibility. Two risk classes:

documentation-only: at most 50 added+removed lines, only .md/.rst files.
small-change: at most 4 files, at most 40 changed lines outside tests and 150 in
  all; code allowed, but no dependency, build, CI, lockfile or safety-sensitive
  file, and no file deleted outside tests.
Both: exactly one stage, no network work, no publishing, no binary, executable,
submodule or symlink change. The policy's record paths (evidence directory and
run record) are not counted: the runner admits only registered evidence there.
"""
import fnmatch
import json
import pathlib
import subprocess
import sys

SENSITIVE = ('skill.md', 'agents.md', 'brief', 'policy', 'contract', 'auth', 'security', 'secret',
             'credential', 'migration', 'lockfile', '.github/', '.gitlab-ci', '.circleci/')
BUILD = ('package.json', 'package-lock.json', 'npm-shrinkwrap.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb',
         'requirements*.txt', 'constraints*.txt', 'pyproject.toml', 'setup.py', 'setup.cfg', 'pipfile', 'pipfile.lock',
         'poetry.lock', 'uv.lock', 'go.mod', 'go.sum', 'cargo.toml', 'cargo.lock', 'gemfile', 'gemfile.lock',
         'cmakelists.txt', 'makefile', 'dockerfile', '*.gradle', 'pom.xml', '.gitignore', '.gitattributes',
         '.npmrc', 'tsconfig*.json', 'vite.config.*', 'vitest.config.*', 'jest.config.*', '.env*')
TESTS = ('test/*', 'tests/*', '*/test/*', '*/tests/*', '*/testing/*', 'testing/*', '__tests__/*', '*/__tests__/*',
         'test_*.py', '*/test_*.py', '*_test.py', '*_test.go', '*.test.*', '*.spec.*', '*.bats')
LIMITS = {'documentation-only': dict(files=None, code=50, total=50),
          'small-change': dict(files=4, code=40, total=150)}


def main():
    repo, base, head, config = sys.argv[1:]
    try:
        data = json.load(open(config, encoding='utf-8'))
    except (OSError, ValueError):
        return 64
    if (not isinstance(data, dict) or set(data) != {'stages', 'network', 'publish', 'risk'} or
            type(data['stages']) is not int or type(data['network']) is not bool or type(data['publish']) is not bool or not isinstance(data['risk'], str)):
        return 64
    risk = data['risk']
    if risk not in LIMITS:
        print(f'lite refused: unknown risk {risk!r} (documentation-only or small-change)')
        return 1

    def git(*args):
        return subprocess.check_output(['git', '-C', repo, *args], stderr=subprocess.DEVNULL)
    try:
        base = git('rev-parse', '--verify', base + '^{commit}').strip().decode()
        head = git('rev-parse', '--verify', head + '^{commit}').strip().decode()
        records = []
        policy = subprocess.run(['git', '-C', repo, 'show', f'{head}:docs/autopilot-policy.json'], capture_output=True)
        if policy.returncode == 0:
            try:
                records = [v.strip('/') for v in json.loads(policy.stdout).get('record_paths', {}).values() if v]
            except (ValueError, AttributeError):
                records = []

        def recorded(path):
            return any(path == r or path.startswith(r + '/') for r in records)
        status = {}
        raw = git('diff', '--no-ext-diff', '--no-renames', '--name-status', '-z', base, head).split(b'\0')
        for kind, name in zip(raw[0::2], raw[1::2]):
            status[name.decode('utf-8')] = kind.decode()
        delta = git('diff', '--no-ext-diff', '--no-renames', '--numstat', '-z', base, head)
        code = total = 0
        files = []
        for row in filter(None, delta.split(b'\0')):
            added, removed, name = row.split(b'\t', 2)
            path = name.decode('utf-8')
            if recorded(path):
                continue
            lower = path.lower()
            leaf = pathlib.PurePosixPath(lower).name
            if added == b'-' or removed == b'-':
                print('lite refused: binary changes')
                return 1
            if any(part in lower for part in SENSITIVE):
                print(f'lite refused: safety-sensitive change: {path}')
                return 1
            is_test = any(fnmatch.fnmatch(lower, p) for p in TESTS)
            if risk == 'documentation-only' and not lower.endswith(('.md', '.rst')):
                print(f'lite refused: executable or safety-sensitive change: {path} (documentation-only)')
                return 1
            if risk == 'small-change':
                if any(fnmatch.fnmatch(leaf, p) for p in BUILD):
                    print(f'lite refused: dependency, build or CI file: {path}')
                    return 1
                if status.get(path) == 'D' and not is_test:
                    print(f'lite refused: file deleted: {path}')
                    return 1
            lines = int(added) + int(removed)
            total += lines
            if not is_test:
                code += lines
            files.append(path)
        modes = git('diff', '--no-ext-diff', '--raw', base, head).decode()
        for line in modes.splitlines():
            meta, _, path = line.partition('\t')
            if recorded(path):
                continue
            if any(mode in meta.split()[:2] for mode in ('100755', ':100755', '160000', ':160000', '120000', ':120000')):
                print('lite refused: executable, submodule or symlink changes')
                return 1
    except (subprocess.CalledProcessError, ValueError):
        return 65
    limit = LIMITS[risk]
    scope_ok = data['stages'] == 1 and not data['network'] and not data['publish']
    size_ok = code <= limit['code'] and total <= limit['total'] and (limit['files'] is None or len(files) <= limit['files'])
    eligible = scope_ok and size_ok
    detail = (f'{total} changed lines' if risk == 'documentation-only'
              else f'{len(files)} files, {code} changed lines outside tests, {total} in all '
                   f'(limits {limit["files"]} / {limit["code"]} / {limit["total"]})')
    reason = '' if eligible else (' — needs one stage, no network, no publishing' if not scope_ok else ' — over the limits')
    print(f'lite {"eligible" if eligible else "refused"} ({risk}): {detail}{reason}; landing audit remains mandatory')
    return 0 if eligible else 1


if __name__ == '__main__':
    sys.exit(main())
