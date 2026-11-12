#!/usr/bin/env bats
load test_helper
# check-record.py turns the record's state rules into a machine check, so a
# skipped or misordered step is caught when it happens, not at the landing audit.

setup_record_repo() {
  EVID="$REPO/evidence"; export EVID
  export AUTOPILOT_RECORD="$REPO/run.md"
  mkdir -p "$REPO/docs"
  printf '{"version":1,"record_paths":{"evidence_dir":"evidence","run_record":"run.md"}}\n' >"$REPO/docs/autopilot-policy.json"
  commit_fixture
  BASE="$(git -C "$REPO" rev-parse HEAD)"
  PIN="$AUTOPILOT_HELPER_PIN"
}

# write_record STATUS CURRENT C1-STATUS C1-EVIDENCE [FINDING-STATUS]
write_record() {
  cat >"$REPO/run.md" <<RECORD
# fixture run

- status: $1 <!-- planned → flying → landed -->
- base: $BASE
- tested commit: $BASE
- mode: ${MODE:-full}
- helper pin: $PIN
- current: $2 <!-- comment -->

## Acceptance criteria

| id | criterion | proven by | status | evidence |
|---|---|---|---|---|
| C1 | value stays safe | \`cat value\` | $3 | $4 |

### Independent mutation targets

| criterion | selected by | source condition / failure | patch | baseline | result / evidence |
|---|---|---|---|---|---|
${TARGETS:-}

## Ledger

### Review findings

| id | round | reviewer | finding | status | note |
|---|---|---|---|---|---|
${5:+| R1 | 1 | codex | something | $5 | ${NOTE:-} |}

### Parked

| id | needs | exact action | unblocks | verify afterward |
|---|---|---|---|---|
${PARKED:-}

### Not verified

${NOT_VERIFIED:-none}
RECORD
  git -C "$REPO" add run.md; [ ! -d "$EVID" ] || git -C "$REPO" add evidence
  git -C "$REPO" commit -qm 'autopilot: record'
}
check() { run python3 -B "$SKILL/scripts/check-record.py" "$@"; }

@test "record check accepts a consistent flying record and names the state it read" {
  setup_record_repo
  gate gate-base 'grep -q safe value'
  write_record flying 'stage 1 gate gate-s1' proven '`gate-base.md`'
  check "$REPO" run.md
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  [[ "$output" == *'record check: OK'*'stage 1 gate gate-s1'* ]]
}

@test "record check refuses an unknown current step and a status that contradicts it" {
  setup_record_repo
  write_record flying 'somewhere over stage 2' open ''
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'current: "somewhere over stage 2" is not a step'* ]] || false
  write_record landed 'stage 1 build' open ''
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'status landed needs current: landed'* ]]
}

@test "record check refuses a proven criterion without registered passing evidence" {
  setup_record_repo
  write_record flying 'stage 1 record' proven ''
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'C1 is proven but cites no evidence'* ]] || false
  write_record flying 'stage 1 record' proven '`gate-never-ran.md`'
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'gate-never-ran.md is not in MANIFEST'* ]] || false
  run gate gate-red 'grep -q broken value'
  write_record flying 'stage 1 record' proven '`gate-red.md`'
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'gate-red.md result is FAILED'* ]]
}

@test "record check reads the committed record and reports an uncommitted one" {
  setup_record_repo
  write_record flying 'stage 1 build' open ''
  printf '\nlocal edit\n' >>"$REPO/run.md"
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'uncommitted changes'* ]]
}

@test "record check holds a landing to closed criteria, settled findings and current evidence" {
  setup_record_repo
  gate gate-base 'grep -q safe value'
  write_record flying 'landing review r1' open ''
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'C1 is still open at landing'* ]] || false
  write_record flying 'landing review r1' proven '`gate-base.md`' blocking-open
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'R1 is blocking-open at landing'* ]] || false
  write_record flying 'landing review r1' proven '`gate-base.md`' approve
  check "$REPO" run.md
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  printf 'changed\n' >"$REPO/value"; git -C "$REPO" commit -qam 'code after the gate'
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'gate-base.md is stale'* ]] || false
  NOT_VERIFIED='gate-base.md predates the last change; not rerun' write_record flying 'landing review r1' proven '`gate-base.md`' approve
  check "$REPO" run.md
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "record check requires an adversary-selected KILLED target in full mode and one target per criterion in lite" {
  setup_record_repo
  gate gate-base 'grep -q safe value'
  patch_value
  MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$' mutant mutant-c1 'test "$(cat value)" = safe || { echo ASSERT_VALUE_SAFE; exit 1; }'
  TARGETS='| C1 | author | guard | p | green | `mutant-c1.md` |' write_record flying 'stage 1 record' proven '`gate-base.md`'
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'C1 has no KILLED mutation target selected by an independent adversary'* ]] || false
  TARGETS='| C1 | codex | guard | p | green | `mutant-c1.md` |' write_record flying 'stage 1 record' proven '`gate-base.md`'
  check "$REPO" run.md
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  TARGETS='| C1 | codex | guard | p | green | `gate-base.md` |' write_record flying 'stage 1 record' proven '`gate-base.md`'
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'C1 has no KILLED mutation target selected by an independent adversary'* ]] || false
  MODE='lite (small-change)' TARGETS='' write_record flying 'stage 1 record' proven '`gate-base.md`'
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'C1 has no KILLED mutant'* ]] || false
  MODE='lite (small-change)' TARGETS='| C1 | author (lite) | guard | p | green | `mutant-c1.md` |' write_record flying 'stage 1 record' proven '`gate-base.md`'
  check "$REPO" run.md
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "record check validates ledger statuses and parked ids named by current" {
  setup_record_repo
  write_record flying 'stage 1 build' open '' looks-fine
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'R1 has unknown status "looks-fine"'* ]] || false
  write_record flying 'stage 1 build' open '' blocking-fixed
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'R1 is blocking-fixed but its note names no commit'* ]] || false
  write_record landed 'landed — parked P2' failed ''
  check "$REPO" run.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'current names P2, which is not in Parked'* ]] || false
  PARKED='| P2 | credentials | `psql` | C1 | count |' write_record landed 'landed — parked P2' failed ''
  check "$REPO" run.md
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "record check fails closed on a missing record and bad usage" {
  setup_record_repo
  check "$REPO" absent.md
  [ "$status" -eq 66 ]
  check "$REPO"
  [ "$status" -eq 64 ]
}
