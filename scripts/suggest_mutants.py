#!/usr/bin/env python3
"""Small mechanical candidates, never an assertion of semantic equivalence.

Python tokens let us avoid modifying quoted strings or comments. Other source
languages use a conservative line filter and are explicitly marked for review.
"""
import difflib
import io
import json
import pathlib
import re
import subprocess
import sys
import tokenize


def variants(line, python):
    if python:
        try:
            tokens = list(tokenize.generate_tokens(io.StringIO(line.lstrip()).readline))
        except (tokenize.TokenError, IndentationError):
            tokens = []
        offset = len(line) - len(line.lstrip())
        regions = [(t.start[1] + offset, t.end[1] + offset, t.string) for t in tokens
                   if t.type in (tokenize.OP, tokenize.NUMBER) and t.start[0] == 1]
    else:
        if line.lstrip().startswith(('#', '//', '*', '/*')) or any(c in line for c in ('"', "'", '`')):
            return
        regions = [(m.start(), m.end(), m[0]) for m in re.finditer(r'<=|>=|==|!=|<|>|\b\d+\b', line)]
    flips = {'<': '>=', '>': '<=', '<=': '>', '>=': '<', '==': '!=', '!=': '=='}
    for start, end, token in regions:
        if token in flips:
            yield 'comparison', line[:start] + flips[token] + line[end:]
        elif re.fullmatch(r'\d+', token):
            for delta in (-1, 1):
                yield f'constant{delta:+}', line[:start] + str(int(token) + delta) + line[end:]
    # Disable a guard at its condition, preserving syntax and body indentation.
    if python:
        guard = re.match(r'(\s*)if\s+(.+):\s*(?:#.*)?\n?$', line)
        if guard:
            yield 'disable-guard', guard[1] + 'if False:\n'
        if re.match(r'\s+return\s+.+', line):
            yield 'return-empty', re.match(r'\s*', line)[0] + 'return\n'
        # A return inserted on the same changed line exercises an early exit
        # without modifying any unchanged line. Only indented statements qualify.
        if re.match(r'\s+(?:if\s|return\s)', line):
            yield 'early-return', re.match(r'\s*', line)[0] + 'return None  # mechanical early exit\n'


def main():
    repo, base, head, out = sys.argv[1:]
    directory = pathlib.Path(out)
    if directory.exists() or directory.is_symlink():
        return 73
    def git(*args):
        return subprocess.check_output(['git', '-C', repo, *args], stderr=subprocess.DEVNULL)
    try:
        base = git('rev-parse', '--verify', base + '^{commit}').decode().strip()
        head = git('rev-parse', '--verify', head + '^{commit}').decode().strip()
        files = git('diff', '--no-ext-diff', '--no-renames', '--name-only', '-z', '--diff-filter=AM', base, head).split(b'\0')
        candidates = []
        for name in filter(None, files):
            file = name.decode('utf-8')
            if not re.fullmatch(r'[A-Za-z0-9_./-]+', file) or pathlib.Path(file).suffix not in ('.py', '.sh', '.js', '.ts', '.tsx', '.c', '.cpp', '.go', '.rs'):
                continue
            mode = git('ls-tree', head, '--', file).split()[0]
            if mode not in (b'100644', b'100755'):
                continue
            lines = git('show', f'{head}:{file}').decode('utf-8').splitlines(keepends=True)
            diff = git('diff', '--no-ext-diff', '--no-renames', '--unified=0', base, head, '--', file).decode('utf-8')
            touched = set()
            current = None
            for line in diff.splitlines():
                hunk = re.match(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@', line)
                if hunk:
                    current = int(hunk[1])
                elif current is not None and line.startswith('+'):
                    touched.add(current)
                    current += 1
                elif current is not None and line.startswith(' '):
                    current += 1
            for number in sorted(touched):
                for kind, replacement in variants(lines[number - 1], file.endswith('.py')):
                    mutant = lines.copy()
                    mutant[number - 1] = replacement
                    # Syntactically broken Python is not a useful candidate.
                    if file.endswith('.py'):
                        try:
                            compile(''.join(mutant), file, 'exec')
                        except (SyntaxError, ValueError):
                            continue
                    patch = ''.join(difflib.unified_diff(lines, mutant, fromfile='a/' + file, tofile='b/' + file))
                    if patch:
                        candidates.append((file, number, kind, patch))
    except (subprocess.CalledProcessError, UnicodeError, ValueError, IndexError):
        return 65
    directory.mkdir(parents=True)
    manifest = []
    for index, (file, number, kind, patch) in enumerate(candidates, 1):
        name = f'mutant-{index:03d}.patch'
        (directory / name).write_text(patch)
        manifest.append(dict(patch=name, file=file, line=number, kind=kind,
                             head=head, selected_by=None, criterion=None))
    (directory / 'candidates.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'{len(candidates)} candidates; adversary must select a substantive target for each criterion')
    return 0


if __name__ == '__main__':
    sys.exit(main())
