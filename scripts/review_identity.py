#!/usr/bin/env python3
"""Bind reviewer outputs to a runner-owned request and the expected Git inputs."""
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import uuid

# The runner hashes scripts/ before and after every command: importing a
# sibling helper must never write __pycache__ there (issue #2).
sys.dont_write_bytecode = True
from policy import selected_policy  # noqa: E402


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()


def inputs(repo, base, head, record, scope, skill):
    def git(*args):
        return subprocess.check_output(['git', '-C', repo, *args], stderr=subprocess.DEVNULL)
    base = git('rev-parse', '--verify', base + '^{commit}').decode().strip()
    head = git('rev-parse', '--verify', head + '^{commit}').decode().strip()
    policy = selected_policy(repo, head)
    files = {}
    for path in (record, 'docs/autopilot.md', policy['path']):
        exists = subprocess.call(['git', '-C', repo, 'cat-file', '-e', head + ':' + path],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0
        files[path] = digest(git('show', head + ':' + path)) if exists else None
    if files[record] is None:
        raise ValueError('missing pinned record')
    return dict(repository=str(pathlib.Path(repo).resolve()), base=base, head=head, scope=scope,
                record=record, files=files, execution_policy=policy,
                brief_sha256=digest((pathlib.Path(skill)/'CODEX-BRIEF.md').read_bytes()),
                schema_sha256=digest((pathlib.Path(skill)/'codex-findings.schema.json').read_bytes()))


def regular(path):
    value = pathlib.Path(path)
    if value.is_symlink() or not value.is_file():
        raise ValueError('regular file required')
    return value.read_bytes()


def write_new(path, value):
    with pathlib.Path(path).open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')


def main():
    mode = sys.argv[1]
    if mode == 'create' and len(sys.argv) == 9:
        repo, base, head, record, scope, skill, out = sys.argv[2:]
        context = inputs(repo, base, head, record, scope, skill)
        write_new(out, dict(version=1, job_id=uuid.uuid4().hex, inputs=context,
                            input_sha256=digest(encoded(context))))
    elif mode == 'seal' and len(sys.argv) == 4:
        findings, request = sys.argv[2:]
        raw = regular(request)
        job = json.loads(raw)
        write_new(findings+'.receipt.json', dict(version=1, job_id=job['job_id'],
                  request_sha256=digest(raw), findings_sha256=digest(regular(findings))))
    elif mode == 'verify' and len(sys.argv) == 10:
        findings, request, repo, base, head, record, scope, skill = sys.argv[2:]
        raw = regular(request)
        job = json.loads(raw)
        context = inputs(repo, base, head, record, scope, skill)
        receipt = json.loads(regular(findings+'.receipt.json'))
        if (job['version'] != 1 or job['inputs'] != context or job['input_sha256'] != digest(encoded(context))
                or receipt != dict(version=1, job_id=job['job_id'], request_sha256=digest(raw),
                                   findings_sha256=digest(regular(findings)))):
            return 70
    elif mode == 'dispatch' and len(sys.argv) == 5:
        repo, head, skill = sys.argv[2:]
        policy = selected_policy(repo, head)['effective']
        # The Codex CLI's own read-only sandbox can read any path on the host,
        # so a policy with deny_paths always parks dispatch. A network-only ban
        # constrains project commands, not the reviewer: the contract may
        # approve Codex dispatch explicitly (#9).
        if policy['deny_paths']:
            return 77
        restrictive = policy['sandbox'] != 'env-clean' or policy['deny_network']
        if restrictive and os.environ.get('CODEX_REVIEW_DISPATCH') != 'approved':
            return 77
    else:
        return 64
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError):
        print('review identity validation failed', file=sys.stderr)
        sys.exit(70)
