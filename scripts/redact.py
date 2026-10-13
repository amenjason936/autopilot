#!/usr/bin/env python3
"""The only path from command output to evidence. Buffer before releasing text."""
import os
import re
import sys


# A switch value (TOKENMETER_NO_KEYCHAIN=1, KEY_ROTATION=off) is never a secret.
FLAG = r'(?!["\']?(?:0|1|true|false|yes|no|on|off)["\']?(?:[\s,;]|$))'


def redact(data):
    text = data.decode('utf-8', errors='strict')
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
    try:
        result = redact(sys.stdin.buffer.read())
    except Exception:
        result = '<redacted>\n'
    sys.stdout.write(result)
