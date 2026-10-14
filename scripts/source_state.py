#!/usr/bin/env python3
"""Freeze the actual source bytes, including a mutant's applied patch."""
import hashlib
import json
import os
import pathlib
import stat
import sys


def snapshot(tree, writes):
    rows = []
    for root, directories, files in os.walk(tree, followlinks=False):
        parent = pathlib.Path(root)
        for name in sorted(directories + files):
            path = parent/name
            relative = path.relative_to(tree).as_posix()
            if any(relative == p or relative.startswith(p + '/') for p in writes):
                if name in directories:
                    directories.remove(name)
                continue
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                value = ['link', os.readlink(path)]
                if name in directories:
                    directories.remove(name)
            elif stat.S_ISREG(mode):
                value = ['file', stat.S_IMODE(mode), hashlib.sha256(path.read_bytes()).hexdigest()]
            elif stat.S_ISDIR(mode):
                value = ['directory', stat.S_IMODE(mode)]
            else:
                raise ValueError('nonregular source input')
            rows.append([relative, value])
    return sorted(rows)


def checkout_digest(top, excluded):
    """Every file of the original checkout, ignored ones included (name, size, mtime)."""
    import hashlib
    rows = []
    skip = {os.path.normpath(e) for e in excluded}
    for directory, dirs, names in os.walk(top):
        dirs[:] = sorted(d for d in dirs if d != '.git' and os.path.normpath(os.path.join(directory, d)) not in skip)
        for name in sorted(names):
            path = os.path.join(directory, name)
            if os.path.normpath(path) in skip:
                continue
            try:
                info = os.lstat(path)
            except FileNotFoundError:
                continue
            rows.append(f'{os.path.relpath(path, top)}\0{info.st_size}\0{info.st_mtime_ns}')
    return hashlib.sha256('\n'.join(rows).encode()).hexdigest()


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == 'checkout':
        print(checkout_digest(sys.argv[2], sys.argv[3:]))
        return 0
    mode, root, policy_file, state_file = sys.argv[1:]
    tree = pathlib.Path(root)
    writes = json.loads(pathlib.Path(policy_file).read_text())['write_dirs']
    if mode == 'prepare':
        for item in writes:
            target = tree/item
            if target.exists() or target.is_symlink():
                raise ValueError('output directory already exists in committed source')
            # No writable ancestor can contain source, Git metadata or symlinks.
            for parent in target.parents:
                if parent == tree:
                    break
                if parent.is_symlink():
                    raise ValueError('symlink output ancestor')
            target.mkdir(parents=True)
        return 0
    actual = snapshot(tree, writes)
    target = pathlib.Path(state_file)
    if mode == 'freeze':
        target.write_text(json.dumps(actual, separators=(',', ':')) + '\n')
    elif mode == 'verify':
        if actual != json.loads(target.read_text()):
            return 1
    else:
        return 64
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError):
        print('source snapshot validation failed', file=sys.stderr)
        sys.exit(1)
