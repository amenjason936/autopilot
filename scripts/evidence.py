#!/usr/bin/env python3
"""Hash manifests are checked before evidence is interpreted; no shell evaluation."""
import hashlib
import pathlib
import re
import sys


def digest(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError('evidence must be a regular, non-symlink file')
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entries(directory):
    manifest = directory / 'MANIFEST'
    if manifest.is_symlink():
        raise ValueError('symlink manifest refused')
    result = {}
    for line in manifest.read_text().splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  ([A-Za-z0-9][A-Za-z0-9._-]*)', line)
        if not match or match[2] in ('.', '..', 'MANIFEST') or '.partial' in match[2]:
            raise ValueError('invalid manifest entry')
        if match[2] in result:
            raise ValueError('duplicate manifest entry')
        result[match[2]] = match[1]
    if not result:
        raise ValueError('empty manifest')
    return result


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ('add', 'verify'):
        return 64
    mode, directory = sys.argv[1], pathlib.Path(sys.argv[2])
    if not directory.is_dir():
        return 66
    # macOS system aliases are fixed host paths, not repository-controlled links.
    system_aliases = {pathlib.Path('/tmp'), pathlib.Path('/var'), pathlib.Path('/etc')}
    absolute = directory.absolute()
    if any(p.is_symlink() for p in (absolute, *absolute.parents) if p not in system_aliases):
        raise ValueError('symlink evidence directory refused')
    manifest = directory / 'MANIFEST'
    known = entries(directory) if manifest.exists() or manifest.is_symlink() else {}
    if mode == 'add':
        # Caller must own the directory lock throughout finalize + append.
        if len(sys.argv) != 4 or not (directory / '.autopilot.lock').is_dir():
            return 64
        name = sys.argv[3]
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', name) or '.partial' in name or name == 'MANIFEST':
            return 64
        if name in known:
            raise ValueError('manifest already contains this evidence')
        with manifest.open('a', encoding='utf-8') as handle:
            handle.write(f'{digest(directory / name)}  {name}\n')
            handle.flush()
            import os
            os.fsync(handle.fileno())
    else:
        if not known:
            raise ValueError('missing or empty manifest')
        wanted = sys.argv[3:] or list(known)
        for name in wanted:
            if name not in known or digest(directory / name) != known[name]:
                raise ValueError('missing evidence or SHA-256 mismatch')
        print(f'verified: {len(wanted)} evidence file(s)')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, UnicodeError):
        print('evidence integrity check failed', file=sys.stderr)
        sys.exit(1)
