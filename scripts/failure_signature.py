#!/usr/bin/env python3
"""Match a frozen assertion signature; unrelated nonzero exits are inconclusive."""
import pathlib
import re
import sys


def main():
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
        text = pathlib.Path(sys.argv[3]).read_text(encoding='utf-8')
        return 0 if int(sys.argv[4]) == expected and pattern.search(text) else 1
    return 64


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, re.error):
        sys.exit(64)
