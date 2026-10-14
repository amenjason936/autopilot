#!/usr/bin/env python3
"""Snapshot runner inputs; the runner executes a preloaded copy with Python -I -S.

Expected digests and this code live in the parent shell, not writable work files.
Endpoint comparison detects persistent changes, not transient writes or races.
"""
import hashlib
import json
import os
import pathlib
import stat
import sys


def snapshot(path):
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return ['absent']
    if stat.S_ISLNK(mode):
        raise ValueError('symlink integrity input')
    if stat.S_ISDIR(mode):
        return ['directory', stat.S_IMODE(mode),
                [[child.name, snapshot(child)] for child in sorted(path.iterdir())]]
    if not stat.S_ISREG(mode):
        raise ValueError('nonregular integrity input')
    # Avoid blocking on a substituted FIFO or following a substituted leaf link.
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        current = os.fstat(stream.fileno()).st_mode
        if not stat.S_ISREG(current):
            raise ValueError('nonregular integrity input')
        value = hashlib.sha256()
        for chunk in iter(lambda: stream.read(65536), b''):
            value.update(chunk)
    return ['file', stat.S_IMODE(current), value.hexdigest()]


def main():
    # Key each input by its last path component, not the path it was reached
    # by: a skill shared through a symlinked directory must pin identically (#9).
    rows = [[pathlib.Path(name).name, snapshot(pathlib.Path(name))] for name in sys.argv[1:]]
    print(hashlib.sha256(json.dumps(rows, separators=(',', ':')).encode()).hexdigest())


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RecursionError):
        print('runner integrity input unreadable', file=sys.stderr)
        sys.exit(1)
