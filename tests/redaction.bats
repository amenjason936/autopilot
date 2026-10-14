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

@test "a redactor error fails closed while non-UTF-8 output is withheld" {
  export REDACT_REGEX='['
  run bash -c 'printf "private-value" | bash -c '\''source "$1/scripts/lib.sh"; clean_output'\'' _ "$SKILL"'
  [ "$status" -ne 0 ]
  [[ "$output" != *private-value* ]]
  [ -z "$output" ]
  run gate badrule 'echo private-value'
  [ "$status" -eq 64 ]
  [[ "$output" == *'invalid REDACT_REGEX'* ]]
  [[ "$output" != *private-value* ]]
  [ ! -e "$EVID/badrule.md" ]
  unset REDACT_REGEX
  run bash -c 'printf "private-value\377" | python3 "$SKILL/scripts/redact.py"'
  [ "$status" -eq 0 ]
  [ "$output" = '<non-UTF-8 output withheld>' ]
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
