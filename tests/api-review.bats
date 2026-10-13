#!/usr/bin/env bats
load test_helper

# A local stand-in for an OpenAI-compatible endpoint: it records the request
# and answers with the canned reply in $CASE/reply.json.
start_stub() {
  cat >"$CASE/stub.py" <<'PY'
import http.server, json, pathlib, sys
case = pathlib.Path(sys.argv[1])
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers['Content-Length']))
        (case / 'request.json').write_bytes(body)
        (case / 'auth.txt').write_text(self.headers.get('Authorization', ''))
        content = (case / 'reply.json').read_text()
        reply = json.dumps({'model': 'stub', 'usage': {'total_tokens': 1},
                            'choices': [{'finish_reason': (case / 'finish').read_text() if (case / 'finish').exists() else 'stop',
                                         'message': {'content': content}}]}).encode()
        self.send_response(200); self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(reply))); self.end_headers(); self.wfile.write(reply)
    def log_message(self, *a): pass
class Server(http.server.HTTPServer):
    def server_bind(self):  # skip getfqdn: a slow reverse lookup on macOS runners
        http.server.socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = '127.0.0.1', self.server_address[1]
server = Server(('127.0.0.1', 0), H)
(case / 'port').write_text(str(server.server_port))
server.serve_forever()
PY
  python3 "$CASE/stub.py" "$CASE" &
  STUB_PID=$!
  for _ in $(seq 300); do [ -s "$CASE/port" ] && break; sleep 0.1; done
  [ -s "$CASE/port" ]
  export REVIEW_API_BASE="http://127.0.0.1:$(cat "$CASE/port")"
}

teardown() { [ -z "${STUB_PID:-}" ] || kill "$STUB_PID" 2>/dev/null || true; }

review_fixture() {
  mkdir -p "$REPO/docs"
  printf 'record\n' >"$REPO/docs/run.md"
  printf 'changed\n' >"$REPO/value"
  printf 'AWS_SECRET_ACCESS_KEY=abcdefghijklmnopqrstuvwxyz0123456789ABCD\n' >"$REPO/config.env"
  commit_fixture
  export REVIEW_API_KEY_ENV=FAKE_REVIEW_KEY FAKE_REVIEW_KEY=sk-test-not-real REVIEW_API_UPLOAD=approved
}

@test "api review sends a redacted snapshot and seals valid findings" {
  review_fixture
  printf '%s' '{"verdict":"approve","summary":"targets: C1 value guard","findings":[],"limits":"snapshot-only; no command reproduction; no OS sandbox; reviewer: stub via API"}' >"$CASE/reply.json"
  start_stub
  run python3 "$SKILL/scripts/api-review.py" --scope landing "$REPO" HEAD~1 "$REPO/docs/run.md" "$CASE/out/r1.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'verdict: approve (0 findings)'* ]]
  [ -f "$CASE/out/r1.json.receipt.json" ]
  run python3 "$SKILL/scripts/review_identity.py" verify "$CASE/out/r1.json" "$CASE/out/r1.json.request.json" "$REPO" HEAD~1 HEAD docs/run.md landing "$SKILL"
  [ "$status" -eq 0 ]
  grep -q '+changed' "$CASE/request.json"
  ! grep -q 'abcdefghijklmnopqrstuvwxyz0123456789ABCD' "$CASE/request.json"
  [ "$(cat "$CASE/auth.txt")" = 'Bearer sk-test-not-real' ]
  ! grep -rq 'sk-test-not-real' "$CASE/out"
  grep -q 'value' "$CASE/out/r1.supplied.txt"
  [ -f "$CASE/out/r1.log.txt" ]
  [ -z "$(find "$CASE/out" -type f -perm -g=r)" ]
}

@test "api review keeps an invalid reply out of the findings path" {
  review_fixture
  printf '%s' '{"verdict":"approve","findings":[]}' >"$CASE/reply.json"
  start_stub
  run python3 "$SKILL/scripts/api-review.py" "$REPO" HEAD~1 "$REPO/docs/run.md" "$CASE/out/r2.json"
  [ "$status" -eq 70 ]
  [ -f "$CASE/out/r2.json.invalid" ]
  [ ! -e "$CASE/out/r2.json" ]
  [ ! -e "$CASE/out/r2.json.receipt.json" ]
}

@test "api review refuses to upload without contract approval" {
  review_fixture
  unset REVIEW_API_UPLOAD
  run python3 "$SKILL/scripts/api-review.py" "$REPO" HEAD~1 "$REPO/docs/run.md" "$CASE/out/r3.json"
  [ "$status" -eq 77 ]
  [ ! -e "$CASE/out" ]
}

evidence_fixture() {
  mkdir -p "$REPO/docs/ev"
  printf '{"version":1,"sandbox":"env-clean","record_paths":{"evidence_dir":"docs/ev","run_record":"docs/run.md"}}\n' >"$REPO/docs/autopilot-policy.json"
  printf 'EVIDENCE-CITED\n' >"$REPO/docs/ev/gate-s1.md"
  printf 'EVIDENCE-STALE\n' >"$REPO/docs/ev/mutant-old.md"
  (cd "$REPO/docs/ev" && sha256sum gate-s1.md mutant-old.md >MANIFEST 2>/dev/null || shasum -a 256 gate-s1.md mutant-old.md >MANIFEST)
  printf 'record cites gate-s1\n' >"$REPO/docs/run.md"
  commit_fixture
}

@test "api review sends evidence once, cited files only, and keeps the code diff free of record paths" {
  review_fixture
  evidence_fixture
  printf '%s' '{"verdict":"approve","summary":"ok","findings":[],"limits":"snapshot-only; no command reproduction; no OS sandbox; reviewer: stub via API"}' >"$CASE/reply.json"
  start_stub
  run python3 "$SKILL/scripts/api-review.py" --evidence docs/ev "$REPO" HEAD~2 "$REPO/docs/run.md" "$CASE/out/r4.json"
  [ "$status" -eq 0 ]
  python3 - "$CASE/request.json" <<'PY'
import json, sys
prompt = json.load(open(sys.argv[1]))['messages'][0]['content']
assert prompt.count('EVIDENCE-CITED') == 1, 'ASSERT_CITED_ONCE'
assert 'EVIDENCE-STALE' not in prompt, 'ASSERT_UNCITED_OMITTED'
assert 'mutant-old.md' in prompt, 'ASSERT_UNCITED_LISTED'
assert 'runs every gate under the OS sandbox' in prompt, 'ASSERT_POLICY_EXPLAINED'
PY
}

@test "api review over the size cap writes nothing and keeps the name free" {
  review_fixture
  export REVIEW_API_MAX_CHARS=1000
  run python3 "$SKILL/scripts/api-review.py" "$REPO" HEAD~1 "$REPO/docs/run.md" "$CASE/out/r5.json"
  [ "$status" -eq 64 ]
  [[ "$output" == *'nothing was written'* ]]
  [ -z "$(ls -A "$CASE/out" 2>/dev/null)" ]
}

@test "api review names a reply cut off at the output limit" {
  review_fixture
  printf '' >"$CASE/reply.json"
  printf 'length' >"$CASE/finish"
  start_stub
  run python3 "$SKILL/scripts/api-review.py" "$REPO" HEAD~1 "$REPO/docs/run.md" "$CASE/out/r6.json"
  [ "$status" -eq 70 ]
  [[ "$output" == *'cut off at the output limit'* ]]
  [ ! -e "$CASE/out/r6.json" ]
  grep -q '"max_tokens": 131072' "$CASE/request.json"
}
