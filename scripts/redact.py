#!/usr/bin/env python3
"""The only path from command output to evidence. Buffer before releasing text."""
import os
import re
import sys


# A switch value (TOKENMETER_NO_KEYCHAIN=1, KEY_ROTATION=off) is never a secret.
FLAG = r'(?!["\']?(?:0|1|true|false|yes|no|on|off)["\']?(?:[\s,;]|$))'


class Withheld(Exception):
    """Deliberately withheld input (not UTF-8): a redaction outcome, not a failure."""


def redact(data):
    try:
        text = data.decode('utf-8', errors='strict')
    except UnicodeDecodeError as error:
        raise Withheld from error
    text = re.sub(r'\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))', '', text)
    text = ''.join(c for c in text if c in '\n\t' or ord(c) >= 32)
    patterns = [
        r'\bsk-[A-Za-z0-9_-]+',
        r'\b(?:gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+)',
        r'\bxox[baprs]-[A-Za-z0-9-]+',
        r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b',
        r'\beyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
        r'(?<=://)[^\s/@:]+:[^\s/@]+@',
        r'''(?im)\b[A-Z_][A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD)[A-Z0-9_]*\s*[=:]\s*''' + FLAG + r'''(?:"[^"\n]*"|'[^'\n]*'|[^\s,;]+)''',
        r'(?i)\b(?:key|token|secret|password)\s*[=:]\s*' + FLAG + r'[^\s,;]+',
        r'(?i)\b(?:authorization\s*:\s*bearer|bearer)\s+[^\s]+',
        r'(?s)-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----',
    ]
    if os.environ.get('REDACT_REGEX'):
        patterns.append(os.environ['REDACT_REGEX'])
    # Compile all rules before emitting any input. Invalid custom rules, binary
    # data, or processing failures suppress the entire block.
    compiled = [re.compile(p) for p in patterns]
    # Preserve escaped separators (especially valid JSON) while preventing an
    # assignment from consuming the next credential's marker. PEMs are handled
    # across the entire block before splitting.
    text = compiled[-1 if not os.environ.get('REDACT_REGEX') else -2].sub('<redacted>', text)
    chunks = re.split(r'(\\[nrt])', text)
    for index in range(0, len(chunks), 2):
        for pattern in compiled:
            chunks[index] = pattern.sub('<redacted>', chunks[index])
    text = ''.join(chunks)
    return '\n'.join(line.rstrip() for line in text.splitlines()) + '\n'


if __name__ == '__main__':
    # Fail closed: a processing error (bad custom rule, internal error) prints
    # nothing and exits non-zero, so no caller can publish unredacted or hollow
    # text as if redaction had succeeded. Only non-UTF-8 input is a deliberate,
    # successful outcome: the whole block is withheld.
    try:
        result = redact(sys.stdin.buffer.read())
    except Withheld:
        result = '<non-UTF-8 output withheld>\n'
    except Exception as error:  # noqa: BLE001 - every failure must fail closed
        print(f'redaction failed: {type(error).__name__}', file=sys.stderr)
        sys.exit(1)
    sys.stdout.write(result)
