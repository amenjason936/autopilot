#!/usr/bin/env bats
load test_helper

@test "redaction covers commands output and configured secret patterns" {
  export REDACT_REGEX='project-private-[0-9]+'
  secret='sk-testsecret123 ghp_example123 xoxb-123-abc AKIA1234567890ABCDEF eyJhbGciOi.xpayload.signature https://user:pass@example.invalid API_KEY=abcdef DB_PASSWORD="secret value" project-private-789'
  run gate redact "printf '%s\n' '$secret'"
  [ "$status" -eq 0 ]
  for value in sk-testsecret123 ghp_example123 xoxb-123-abc AKIA1234567890ABCDEF eyJhbGciOi user:pass abcdef 'secret value' project-private-789; do
    ! grep -Fq "$value" "$EVID/redact.md"
    [[ "$output" != *"$value"* ]]
  done
  grep -q '<redacted>' "$EVID/redact.md"
}

@test "invalid custom regex and invalid UTF8 suppress the entire block" {
  export REDACT_REGEX='['
  run bash -c 'printf "private-value" | bash -c '\''source "$1/scripts/lib.sh"; clean_output'\'' _ "$SKILL"'
  [ "$status" -eq 0 ]
  [ "$output" = '<redacted>' ]
  unset REDACT_REGEX
  run bash -c 'printf "private-value\377" | python3 "$SKILL/scripts/redact.py"'
  [ "$output" = '<redacted>' ]
}

@test "multiline private key is redacted before output truncation" {
  export GATE_TAIL_LINES=2
  run gate private "printf '%s\n' '-----BEGIN PRIVATE KEY-----' 'private-key-body' '-----END PRIVATE KEY-----'"
  [ "$status" -eq 0 ]
  ! grep -q private-key-body "$EVID/private.md"
}

@test "escaped line separators do not hide a second credential marker" {
  run bash -c 'printf "%s" '\''API_TOKEN=SYNTHETIC_A\nBearer SYNTHETIC_B'\'' | python3 "$SKILL/scripts/redact.py"'
  [ "$status" -eq 0 ]
  [[ "$output" != *SYNTHETIC_A* && "$output" != *SYNTHETIC_B* ]]
}

@test "redaction preserves escaped JSON strings in reviewer findings" {
  run bash -c 'printf "%s" '\''{"summary":"first\nsecond","limits":"tab\there"}'\'' | python3 "$SKILL/scripts/redact.py" | python3 -c '\''import json,sys; print(json.load(sys.stdin)["summary"])'\'''
  [ "$status" -eq 0 ]
  [ "$output" = $'first\nsecond' ]
}
