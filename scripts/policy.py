#!/usr/bin/env python3
"""Normalize a frozen JSON policy. Never source a contract as shell code."""
import json
import os
import pathlib
import platform
import re
import sys

SYSTEM_READS = ['/usr', '/bin', '/sbin', '/lib', '/lib64', '/System/Library',
                '/Library/Apple', '/private/var/db/dyld', '/private/etc', '/etc', '/dev']
RESERVED = {'HOME', 'PATH', 'TMPDIR', 'TMP', 'TEMP', 'BASH_ENV', 'ENV', 'SHELLOPTS',
            'BASHOPTS', 'CDPATH', 'IFS', 'PYTHONPATH', 'PYTHONHOME', 'PERL5OPT',
            'PERL5LIB', 'RUBYOPT', 'NODE_OPTIONS', 'GIT_CONFIG', 'GIT_CONFIG_COUNT',
            'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM', 'GIT_DIR', 'GIT_WORK_TREE'}


def paths(values, aliases=False):
    if not isinstance(values, list) or any(not isinstance(p, str) or not p.startswith('/') or
                                         any(ord(c) < 32 for c in p) for p in values):
        raise ValueError('paths must be arrays of absolute paths without control characters')
    normalized = []
    for p in values:
        normalized.append(os.path.realpath(p))
        if aliases:
            normalized.append(os.path.normpath(p))
    return list(dict.fromkeys(normalized))


def normalize():
    supplied = json.load(sys.stdin)
    allowed = {'version', 'sandbox', 'deny_network', 'deny_paths', 'read_paths', 'env'}
    if not isinstance(supplied, dict) or set(supplied) - allowed or supplied.get('version', 1) != 1:
        raise ValueError('unsupported policy schema')
    network = supplied.get('deny_network', False)
    if not isinstance(network, bool):
        raise ValueError('deny_network must be a boolean')
    denied = paths(supplied.get('deny_paths', []))
    reads = paths(SYSTEM_READS + supplied.get('read_paths', []), aliases=True)
    names = supplied.get('env', [])
    if not isinstance(names, list) or any(not isinstance(n, str) for n in names):
        raise ValueError('env must be an array of variable names')
    names = list(dict.fromkeys(names + os.environ.get('GATE_ENV', '').split()))
    for name in names:
        upper = name.upper()
        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name) or re.search(r'KEY|TOKEN|SECRET|PASSWORD', upper):
            raise ValueError('secret or invalid environment variable name refused')
        if upper in RESERVED or upper.startswith(('LD_', 'DYLD_', 'GIT_', 'BASH_FUNC_')):
            raise ValueError('runtime injection environment variable refused')
    sandbox = os.environ.get('GATE_SANDBOX') or supplied.get('sandbox', 'env-clean')
    if supplied.get('sandbox') in ('sandbox-exec', 'bwrap') and sandbox == 'env-clean':
        sandbox = supplied['sandbox']
    if sandbox not in ('env-clean', 'sandbox-exec', 'bwrap'):
        raise ValueError('unknown sandbox')
    if (network or denied) and sandbox == 'env-clean':
        sandbox = 'sandbox-exec' if platform.system() == 'Darwin' else 'bwrap'
    return dict(version=1, sandbox=sandbox, deny_network=network, deny_paths=denied,
                read_paths=reads, env=names)


def profile(policy, tree, home, temporary, gitdir):
    quote = json.dumps
    lines = ['(version 1)', '(deny default)', '(allow process*)',
             '(allow signal (target self))', '(allow sysctl-read)', '(allow mach-lookup)',
             '(allow file-read-metadata)', '(allow file-read* (literal "/"))']
    for p in policy['read_paths'] + [tree, home, temporary, gitdir]:
        lines.append(f'(allow file-read* file-map-executable (subpath {quote(p)}))')
    for p in [tree, home, temporary]:
        lines.append(f'(allow file-write* (subpath {quote(p)}))')
    lines.append('(allow file-write* (literal "/dev/null") (literal "/dev/tty"))')
    for p in policy['deny_paths']:
        lines.append(f'(deny file-read* file-write* file-map-executable (subpath {quote(p)}))')
    # No network rule is allowed: strict modes are always offline.
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    try:
        if len(sys.argv) == 1:
            print(json.dumps(normalize()))
        elif len(sys.argv) == 6 and sys.argv[1] == 'profile':
            print(profile(json.load(sys.stdin), *sys.argv[2:]), end='')
        else:
            sys.exit(64)
    except (ValueError, TypeError, OSError):
        print('invalid gate policy (check schema, paths, environment allowlist)', file=sys.stderr)
        sys.exit(64)
