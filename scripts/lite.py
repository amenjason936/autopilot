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
import re
import subprocess
import sys

# Matched as whole words of the path (split on / . _ - and camelCase), so
# authMiddleware.ts and oauth/ are sensitive while author.ts is not.
SENSITIVE = {'skill', 'agents', 'brief', 'briefs', 'policy', 'policies', 'contract', 'contracts', 'auth', 'authn',
             'authz', 'oauth', 'oauth2', 'login', 'password', 'passwd', 'security', 'secret', 'secrets', 'credential',
             'credentials', 'crypto', 'permission', 'permissions', 'acl', 'rbac', 'migration', 'migrations', 'migrate',
             'lockfile'}
SENSITIVE_PREFIXES = ('.github/', '.gitlab-ci', '.circleci/')


def words(path):
    return {w.lower() for w in re.split(r'[/._\-\s]+|(?<=[a-z0-9])(?=[A-Z])', path) if w}
BUILD = ('package.json', 'package-lock.json', 'npm-shrinkwrap.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb',
         'requirements*.txt', 'constraints*.txt', 'pyproject.toml', 'setup.py', 'setup.cfg', 'pipfile', 'pipfile.lock',
         'poetry.lock', 'uv.lock', 'go.mod', 'go.sum', 'cargo.toml', 'cargo.lock', 'gemfile', 'gemfile.lock',
         'cmakelists.txt', 'makefile', 'dockerfile', '*.gradle', 'pom.xml', '.gitignore', '.gitattributes',
         '.npmrc', 'tsconfig*.json', 'vite.config.*', 'vitest.config.*', 'jest.config.*', '.env*')
TESTS = ('test/*', 'tests/*', '*/test/*', '*/tests/*', '*/testing/*', 'testing/*', '__tests__/*', '*/__tests__/*',
         'test_*.py', '*/test_*.py', '*_test.py', '*_test.go', '*.test.*', '*.spec.*', '*.bats')
# Changed lines that touch access control or secret handling send the run to
# full mode whatever their size: a two-line guard removal is the riskiest change
# there is. Whole words, case-insensitive; deliberately broad.
RISKY = re.compile(r'(?i)(?<![a-z])(?:auth\w*|authori[sz]\w*|admin\w*|roles?|permissions?|privileges?|is_?(?:admin|staff|owner|superuser)'
                   r'|password\w*|passwd|secrets?|credentials?|csrf|cors|acl|rbac|sudo|setuid|chmod|verify_?signature|signature'
                   r'|encrypt\w*|decrypt\w*|sanitiz\w*|escape_?html|allow_?list|deny_?list|whitelist|blacklist)(?![a-z])')
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
        records, generated, allowed = [], [], ['documentation-only']
        policy = subprocess.run(['git', '-C', repo, 'show', f'{head}:docs/autopilot-policy.json'], capture_output=True)
        if policy.returncode == 0:
            try:
                committed = json.loads(policy.stdout)
                records = [v.strip('/') for v in committed.get('record_paths', {}).values() if v]
                generated = [v.strip('/') for v in committed.get('generated_paths', []) if isinstance(v, str) and v.strip('/')]
                allowed = committed.get('lite', ['documentation-only'])
            except (ValueError, AttributeError):
                records, generated = [], []
        # The human opts in, per risk class, in the committed policy.
        if not isinstance(allowed, list) or risk not in allowed:
            print(f'lite refused: the committed policy does not allow risk {risk!r} (policy "lite": {allowed!r})')
            return 1

        def recorded(path):
            return any(path == r or path.startswith(r + '/') for r in records)

        def built(path):
            return any(path.startswith(g + '/') for g in generated)
        status = {}
        raw = git('diff', '--no-ext-diff', '--no-renames', '--name-status', '-z', base, head).split(b'\0')
        for kind, name in zip(raw[0::2], raw[1::2]):
            status[name.decode('utf-8')] = kind.decode()
        delta = git('diff', '--no-ext-diff', '--no-renames', '--numstat', '-z', base, head)
        code = total = skipped_generated = 0
        files = []
        for row in filter(None, delta.split(b'\0')):
            added, removed, name = row.split(b'\t', 2)
            path = name.decode('utf-8')
            if recorded(path):
                continue
            if built(path):
                skipped_generated += 1
                continue
            lower = path.lower()
            leaf = pathlib.PurePosixPath(lower).name
            if added == b'-' or removed == b'-':
                print('lite refused: binary changes')
                return 1
            if SENSITIVE & words(path) or lower.startswith(SENSITIVE_PREFIXES):
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
        modes = git('diff', '--no-ext-diff', '--no-renames', '--raw', base, head).decode()
        for line in modes.splitlines():
            meta, _, path = line.partition('\t')
            if recorded(path) or built(path):
                continue
            old, new = meta.lstrip(':').split()[:2]
            # Symlinks and submodules never; an executable bit only when it
            # changes (or arrives with a new file). Editing a script that was
            # already executable is fine (issue #8: false refusal).
            if {old, new} & {'120000', '160000'}:
                print(f'lite refused: symlink or submodule change: {path}')
                return 1
            if '100755' in (old, new) and (old != new or risk == 'documentation-only'):
                print(f'lite refused: executable bit change: {path}')
                return 1
        if risk == 'small-change':
            code_paths = [p for p in files if not any(fnmatch.fnmatch(p.lower(), t) for t in TESTS)]
            if code_paths:
                hunks = git('diff', '--no-ext-diff', '--no-renames', '-U0', base, head, '--', *code_paths).decode('utf-8', 'replace')
                current = None
                for line in hunks.splitlines():
                    if line.startswith('+++ '):
                        current = line[6:] if line.startswith('+++ b/') else line[4:]
                    elif line.startswith(('+', '-')) and not line.startswith(('---', '+++')):
                        match = RISKY.search(line[1:])
                        if match:
                            print(f'lite refused: a changed line touches access control or secrets ({match[0]!r} in {current}); use full mode')
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
    if skipped_generated:
        detail += f'; {skipped_generated} generated file(s) under {", ".join(generated)} not counted (a gate must prove them fresh)'
    reason = '' if eligible else (' — needs one stage, no network, no publishing' if not scope_ok else ' — over the limits')
    print(f'lite {"eligible" if eligible else "refused"} ({risk}): {detail}{reason}; landing audit remains mandatory')
    return 0 if eligible else 1


if __name__ == '__main__':
    sys.exit(main())
