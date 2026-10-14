#!/usr/bin/env python3
"""Hash manifests are checked before evidence is interpreted; no shell evaluation."""
import hashlib
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True  # never write __pycache__ into scripts/ (issue #2)
from redact import redact  # noqa: E402


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


def safe_path(path):
    # Preserve fixed macOS aliases, reject repository/user-controlled redirects.
    system_aliases = {pathlib.Path('/tmp'), pathlib.Path('/var'), pathlib.Path('/etc')}
    absolute = path.absolute()
    if any(p.is_symlink() for p in (absolute, *absolute.parents) if p not in system_aliases):
        raise ValueError('symlink evidence path refused')


def ignored(directory, name):
    """True when Git would skip DIRECTORY/NAME: a MANIFEST must never list an untracked file."""
    result = subprocess.run(['git', '-C', str(directory), 'check-ignore', '-q', '--no-index', '--', name],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0


def register(directory, source, name):
    """Redact SOURCE into DIRECTORY/NAME and append it to MANIFEST under the lock."""
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', name) or '.partial' in name or name == 'MANIFEST':
        raise ValueError('invalid evidence name')
    if ignored(directory, name):
        print(f'{name} would be skipped by .gitignore; register it under another name (e.g. {name}.txt)', file=sys.stderr)
        raise ValueError('ignored evidence name')
    if source.is_symlink() or not source.is_file():
        raise ValueError('source must be a regular, non-symlink file')
    lock = directory / '.autopilot.lock'
    for _ in range(50):
        try:
            lock.mkdir()
            break
        except FileExistsError:
            time.sleep(0.2)
    else:
        raise ValueError('evidence directory locked; inspect its owner before recovering a stale lock')
    try:
        (lock / 'owner').write_text(f'pid={os.getpid()}\nlabel={name}\nstarted=register\n')
        target = directory / name
        if target.exists() or target.is_symlink():
            raise ValueError('evidence exists; choose a new name')
        if name in (entries(directory) if (directory / 'MANIFEST').exists() else {}):
            raise ValueError('manifest already contains this evidence')
        staging = directory / (name + '.register-tmp')
        staging.write_text(redact(source.read_bytes()), encoding='utf-8')
        with staging.open('rb') as handle:
            os.fsync(handle.fileno())
        staging.rename(target)
        with (directory / 'MANIFEST').open('a', encoding='utf-8') as handle:
            handle.write(f'{digest(target)}  {name}\n')
            handle.flush()
            os.fsync(handle.fileno())
    finally:
        shutil.rmtree(lock, ignore_errors=True)
    print(f'registered: {name}')


def main():
    if len(sys.argv) in (4, 5) and sys.argv[1] == 'register':
        directory, source = pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
        if not directory.is_dir():
            return 66
        safe_path(directory)
        register(directory, source, sys.argv[4] if len(sys.argv) == 5 else source.name)
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == 'path':
        safe_path(pathlib.Path(sys.argv[2]))
        return 0
    if len(sys.argv) == 4 and sys.argv[1] == 'complete':
        path = pathlib.Path(sys.argv[2])
        digest(path)  # regular file, no leaf symlink
        content = path.read_text(encoding='utf-8')
        if (not content.startswith('# ') or not re.search(r'^- tested commit: [0-9a-f]{40,64}$', content, re.M)
                or not content.endswith('- result: ' + sys.argv[3] + '\n')
                or '\n## ' not in content and 'preflight' not in sys.argv[3]):
            raise ValueError('incomplete runner evidence')
        with path.open('rb') as handle:
            os.fsync(handle.fileno())
        return 0
    if len(sys.argv) < 3 or sys.argv[1] not in ('add', 'verify'):
        return 64
    mode, directory = sys.argv[1], pathlib.Path(sys.argv[2])
    if not directory.is_dir():
        return 66
    safe_path(directory)
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
            os.fsync(handle.fileno())
    else:
        if not known:
            raise ValueError('missing or empty manifest')
        wanted = sys.argv[3:] or list(known)
        # Naming files checks them; MANIFEST still has to be complete on disk.
        missing = sorted(name for name in known if not (directory / name).is_file())
        if missing:
            print(f'MANIFEST lists missing files: {", ".join(missing)}', file=sys.stderr)
            raise ValueError('incomplete evidence directory')
        for name in wanted:
            if '/' in name:
                print(f'name evidence files relative to the directory: {name!r} -> {pathlib.Path(name).name!r}', file=sys.stderr)
                return 64
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
