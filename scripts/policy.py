#!/usr/bin/env python3
"""Normalize a frozen JSON policy. Never source a contract as shell code."""
import json
import os
import pathlib
import platform
import re
import sys
import subprocess
import hashlib

SYSTEM_READS = ['/usr', '/bin', '/sbin', '/lib', '/lib64', '/System/Library',
                '/Library/Apple', '/private/var/db/dyld', '/private/etc', '/etc', '/dev']
RESERVED = {'HOME', 'PATH', 'TMPDIR', 'TMP', 'TEMP', 'BASH_ENV', 'ENV', 'SHELLOPTS',
            'BASHOPTS', 'CDPATH', 'IFS', 'PYTHONPATH', 'PYTHONHOME', 'PERL5OPT',
            'PERL5LIB', 'RUBYOPT', 'NODE_OPTIONS', 'GIT_CONFIG', 'GIT_CONFIG_COUNT',
            'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM', 'GIT_DIR', 'GIT_WORK_TREE', 'AUTOPILOT_OUTPUT'}


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


def normalize(supplied=None):
    if supplied is None:
        supplied = json.load(sys.stdin)
    allowed = {'version', 'sandbox', 'deny_network', 'deny_paths', 'read_paths', 'env', 'record_paths', 'write_dirs'}
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
    records = supplied.get('record_paths', {})
    if not isinstance(records, dict) or set(records) - {'evidence_dir', 'run_record'}:
        raise ValueError('invalid record paths')
    for value in records.values():
        if (not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_./-]+', value)
                or value.startswith('/') or any(x in ('', '.', '..') for x in value.split('/'))):
            raise ValueError('record paths must be relative and dedicated')
    writes = supplied.get('write_dirs', [])
    if not isinstance(writes, list):
        raise ValueError('write_dirs must be an array')
    for value in writes:
        if (not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_./-]+', value)
                or value.startswith('/') or any(x in ('', '.', '..', '.git') for x in value.split('/'))):
            raise ValueError('write_dirs must be dedicated repository-relative output directories')
    return dict(record_paths=records, write_dirs=list(dict.fromkeys(writes)), version=1, sandbox=sandbox, deny_network=network, deny_paths=denied,
                read_paths=reads, env=names)


def selected_policy(repo, head):
    """One selection rule for gates, reviewer dispatch and resume identity."""
    path = os.environ.get('GATE_POLICY', 'docs/autopilot-policy.json')
    if (not re.fullmatch(r'[A-Za-z0-9_./-]+', path) or path.startswith('/')
            or any(part in ('', '.', '..') for part in path.split('/'))):
        raise ValueError('policy path must be repository relative')
    proc = subprocess.run(['git', '-C', repo, 'show', head + ':' + path], capture_output=True)
    if proc.returncode:
        contract = subprocess.run(['git', '-C', repo, 'cat-file', '-e', head + ':docs/autopilot.md'],
                                  capture_output=True)
        if 'GATE_POLICY' in os.environ or contract.returncode == 0:
            raise ValueError('missing committed policy')
        raw, supplied = None, {}
    else:
        raw = proc.stdout
        supplied = json.loads(raw)
    return dict(path=path, sha256=hashlib.sha256(raw).hexdigest() if raw is not None else None,
                effective=normalize(supplied))


def profile(policy, tree, home, temporary, gitdir, source, output):
    quote = json.dumps
    writable = [home, temporary, output] + [str(pathlib.Path(tree)/p) for p in policy['write_dirs']]
    if policy['sandbox'] == 'env-clean':
        # Environment-only mode still pins execution inputs. It retains host
        # access outside the protected source/Git roots; it is not full isolation.
        lines = ['(version 1)', '(allow default)']
        for root in (tree, source, gitdir):
            exceptions = ''.join(f' (require-not (subpath {quote(p)}))' for p in writable if p.startswith(root + '/'))
            lines.append(f'(deny file-write* (require-all (subpath {quote(root)}){exceptions}))')
        return '\n'.join(lines) + '\n'
    lines = ['(version 1)', '(deny default)', '(allow process*)',
             '(allow signal (target self))', '(allow sysctl-read)', '(allow mach-lookup)',
             '(allow file-read-metadata)', '(allow file-read* (literal "/"))']
    for p in policy['read_paths'] + [tree, home, temporary, gitdir, output]:
        lines.append(f'(allow file-read* file-map-executable (subpath {quote(p)}))')
    for p in writable:
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
        elif len(sys.argv) == 4 and sys.argv[1] == 'select':
            print(json.dumps(selected_policy(*sys.argv[2:])))
        elif len(sys.argv) == 8 and sys.argv[1] == 'profile':
            print(profile(json.load(sys.stdin), *sys.argv[2:]), end='')
        else:
            sys.exit(64)
    except (ValueError, TypeError, OSError):
        print('invalid gate policy (check schema, paths, environment allowlist)', file=sys.stderr)
        sys.exit(64)
