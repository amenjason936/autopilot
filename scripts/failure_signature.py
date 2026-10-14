#!/usr/bin/env python3
"""Match a frozen assertion signature; unrelated nonzero exits are inconclusive."""
import pathlib
import re
import sys


# Match what the evidence shows: colour and cursor escapes are stripped there
# (vitest colours output even without a terminal), so signatures are written
# against plain text.
ANSI = re.compile(r'\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\r(?!\n)')


def plain(path):
    return ANSI.sub('', pathlib.Path(path).read_text(encoding='utf-8'))


def main():
    if len(sys.argv) == 3 and sys.argv[1] == 'activity':
        text = plain(sys.argv[2])
        plans = re.findall(r'^1\.\.([0-9]+)(?:\s.*)?$', text, re.M)
        cases = re.findall(r'^(?:not )?ok(?:[ \t]+[^\n]*)?$', text, re.M)
        active = [row for row in cases if not re.search(r'#\s*skip\b', row, re.I)]
        tap = bool(plans or cases or re.search(r'^TAP version [0-9]+$', text, re.M))
        return 2 if tap and (not active or any(int(p) == 0 for p in plans)) else 0
    mode, expression = sys.argv[1:3]
    pattern = re.compile(expression, re.M)
    if not expression or pattern.search(''):
        return 64
    expected = int(sys.argv[-1])
    if expected not in range(1, 126):
        return 64
    if mode == 'validate' and len(sys.argv) == 4:
        return 0
    if mode == 'match' and len(sys.argv) == 6:
        text = plain(sys.argv[3])
        return 0 if int(sys.argv[4]) == expected and pattern.search(text) else 1
    return 64


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, re.error):
        sys.exit(64)
