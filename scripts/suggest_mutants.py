#!/usr/bin/env python3
"""Small mechanical candidates, never an assertion of semantic equivalence.

Python tokens let us avoid modifying quoted strings or comments. Other source
languages mask string literals and line comments on the changed line, so only
code outside them is mutated; candidates still need review.
"""
import difflib
import fnmatch
import io
import json
import pathlib
import re
import subprocess
import sys
import tokenize


C_LIKE = ('.js', '.mjs', '.cjs', '.ts', '.tsx', '.c', '.cpp', '.go', '.rs')


def code_mask(line, suffix):
    """True for each character outside string literals and line comments."""
    mask = [True] * len(line)
    quotes = '"\'' + ('`' if suffix in ('.js', '.mjs', '.cjs', '.ts', '.tsx', '.go') else '')
    comment = '#' if suffix == '.sh' else '//'
    index, quote = 0, None
    while index < len(line):
        char = line[index]
        if quote:
            mask[index] = False
            if char == '\\' and quote != "'" * (suffix == '.sh'):
                if index + 1 < len(line):
                    mask[index + 1] = False
                index += 2
                continue
            if char == quote:
                quote = None
        elif char in quotes:
            quote = char
            mask[index] = False
        elif line.startswith(comment, index) and (comment != '#' or index == 0 or line[index - 1].isspace()):
            for rest in range(index, len(line)):
                mask[rest] = False
            break
        index += 1
    if quote:  # a literal continues past this line: mutate nothing on it
        return [False] * len(line)
    return mask


def condition_span(line, mask, start):
    """(open, close) of the parenthesised condition after an `if` at start."""
    open_at = line.find('(', start)
    if open_at < 0 or not mask[open_at] or line[start + 2:open_at].strip():
        return None
    depth = 0
    for index in range(open_at, len(line)):
        if not mask[index]:
            continue
        depth += {'(': 1, ')': -1}.get(line[index], 0)
        if depth == 0:
            return open_at, index
    return None


def variants(line, python, suffix=''):
    if python:
        try:
            tokens = list(tokenize.generate_tokens(io.StringIO(line.lstrip()).readline))
        except (tokenize.TokenError, IndentationError):
            tokens = []
        offset = len(line) - len(line.lstrip())
        regions = [(t.start[1] + offset, t.end[1] + offset, t.string) for t in tokens
                   if t.type in (tokenize.OP, tokenize.NUMBER) and t.start[0] == 1]
    else:
        if line.lstrip().startswith(('*', '/*')):
            return
        mask = code_mask(line, suffix)
        pattern = r'===|!==|<=|>=|==|!=|&&|\|\||<|>|\btrue\b|\bfalse\b|\b\d+\b'
        regions = [(m.start(), m.end(), m[0]) for m in re.finditer(pattern, line)
                   if all(mask[m.start():m.end()])
                   # Arrows, shifts and generics are not comparisons.
                   and not (m[0] in '<>' and (line[m.start() - 1:m.start()] in '=-<>' or line[m.end():m.end() + 1] in '=<>'))]
    flips = {'<': '>=', '>': '<=', '<=': '>', '>=': '<', '==': '!=', '!=': '==',
             '===': '!==', '!==': '===', '&&': '||', '||': '&&', 'true': 'false', 'false': 'true'}
    for start, end, token in regions:
        if token in flips:
            yield 'comparison', line[:start] + flips[token] + line[end:]
        elif re.fullmatch(r'\d+', token):
            for delta in (-1, 1):
                # x[0] -> x[-1] is equivalent on a one-element sequence; x[1] remains.
                if delta == -1 and token == '0' and line[:start].rstrip().endswith('['):
                    continue
                yield f'constant{delta:+}', line[:start] + str(int(token) + delta) + line[end:]
    # Disable a guard at its condition, preserving syntax and body indentation.
    if python:
        guard = re.match(r'(\s*)if\s+(.+):\s*(?:#.*)?\n?$', line)
        if guard:
            yield 'disable-guard', guard[1] + 'if False:\n'
        # `return None` -> `return` is equivalent; skip both variants for it.
        if re.match(r'\s+return\s+.+', line) and not re.match(r'\s+return\s+None\s*(?:#.*)?$', line):
            yield 'return-empty', re.match(r'\s*', line)[0] + 'return\n'
        # A return inserted on the same changed line exercises an early exit
        # without modifying any unchanged line. Only indented statements qualify.
        if re.match(r'\s+(?:if\s|return\s)', line) and not re.match(r'\s+return\s+None\s*(?:#.*)?$', line):
            yield 'early-return', re.match(r'\s*', line)[0] + 'return None  # mechanical early exit\n'
    elif suffix in C_LIKE:
        guard = re.search(r'\bif\b', line)
        if guard and mask[guard.start()]:
            span = condition_span(line, mask, guard.start())
            if span:
                never = '0' if suffix in ('.c', '.cpp') else 'false'
                yield 'disable-guard', line[:span[0] + 1] + never + line[span[1]:]
        value = re.match(r'(\s+)return\s+[^;]*;\s*(?://.*)?\n?$', line)
        if value and suffix in ('.js', '.mjs', '.cjs', '.ts', '.tsx') and all(mask[len(value[1]):len(value[1]) + 6]):
            yield 'return-empty', value[1] + 'return;\n'


TEST_PATTERNS = ('test/*', 'tests/*', '*/test/*', '*/tests/*', '*/Testing/*', 'Testing/*', '__tests__/*',
                 '*/__tests__/*', 'test_*.py', '*/test_*.py', '*_test.py', '*_test.go', '*.test.*', '*.spec.*', '*.bats')


def string_lines(source):
    """Line numbers inside multi-line Python strings (docstrings), after their first line."""
    lines = set()
    try:
        for token in tokenize.generate_tokens(io.StringIO(source).readline):
            if token.type == tokenize.STRING and token.end[0] > token.start[0]:
                lines.update(range(token.start[0] + 1, token.end[0] + 1))
    except (tokenize.TokenError, IndentationError, SyntaxError):
        pass
    return lines


def main():
    args = sys.argv[1:]
    include_tests = args[:1] == ['--include-tests']
    if include_tests:
        args = args[1:]
    repo, base, head, out = args
    directory = pathlib.Path(out)
    if directory.exists() or directory.is_symlink():
        print(f'output directory exists: {out}; choose a new one', file=sys.stderr)
        return 73
    def git(*args):
        return subprocess.check_output(['git', '-C', repo, *args], stderr=subprocess.DEVNULL)
    try:
        base = git('rev-parse', '--verify', base + '^{commit}').decode().strip()
        head = git('rev-parse', '--verify', head + '^{commit}').decode().strip()
        files = git('diff', '--no-ext-diff', '--no-renames', '--name-only', '-z', '--diff-filter=AM', base, head).split(b'\0')
        candidates = []
        skipped_tests = 0
        generated = ['*.min.js', '*.map', '*.d.ts']
        try:
            committed = json.loads(git('show', f'{head}:docs/autopilot-policy.json'))
            generated += [v.strip('/') + '/*' for v in committed.get('generated_paths', []) if isinstance(v, str)]
        except (subprocess.CalledProcessError, ValueError, AttributeError):
            pass
        for name in filter(None, files):
            file = name.decode('utf-8')
            if not re.fullmatch(r'[A-Za-z0-9_./-]+', file) or pathlib.Path(file).suffix not in ('.py', '.sh') + C_LIKE:
                continue
            # Build output is checked for freshness, not mutated: tests run the source.
            if any(fnmatch.fnmatch(file, p) for p in generated):
                continue
            # Mutating the detector itself rarely proves anything about the code.
            if not include_tests and any(fnmatch.fnmatch(file, p) for p in TEST_PATTERNS):
                skipped_tests += 1
                continue
            mode = git('ls-tree', head, '--', file).split()[0]
            if mode not in (b'100644', b'100755'):
                continue
            lines = git('show', f'{head}:{file}').decode('utf-8').splitlines(keepends=True)
            diff = git('diff', '--no-ext-diff', '--no-renames', '--unified=0', base, head, '--', file).decode('utf-8')
            touched = set()
            docstrings = string_lines(''.join(lines)) if file.endswith('.py') else set()
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
            for number in sorted(touched - docstrings):
                for kind, replacement in variants(lines[number - 1], file.endswith('.py'), pathlib.Path(file).suffix):
                    mutant = lines.copy()
                    mutant[number - 1] = replacement
                    # Syntactically broken Python is not a useful candidate.
                    if file.endswith('.py'):
                        try:
                            compile(''.join(mutant), file, 'exec')
                        except (SyntaxError, ValueError):
                            continue
                    delta = difflib.unified_diff(lines, mutant, fromfile='a/' + file, tofile='b/' + file)
                    patch = ''.join(line if line.endswith('\n') else line + '\n\\ No newline at end of file\n' for line in delta)
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
    note = f' ({skipped_tests} test file(s) skipped; --include-tests to mutate them)' if skipped_tests else ''
    print(f'{len(candidates)} candidates{note}; adversary must select a substantive target for each criterion')
    return 0


if __name__ == '__main__':
    sys.exit(main())
