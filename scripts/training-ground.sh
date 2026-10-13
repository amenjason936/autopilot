#!/bin/bash
# training-ground.sh <new-directory>
# Builds only synthetic fixtures. Detects logic bug, surviving guard mutation,
# then killed guard mutation, and real filesystem/network red lines.
# Exit: 0 all expected outcomes; 1 mismatch; 64 usage; 73 destination exists.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
require git python3
[ $# -eq 1 ] || die 64 'usage: training-ground.sh <new-directory>'
[ ! -e "$1" ] || die 73 'training destination already exists'
ROOT="$(resolve_path "$1")"
REPO="$ROOT/repo"
EVIDENCE="$REPO/evidence"
mkdir -p "$REPO/docs" "$EVIDENCE" "$ROOT/patches" "$ROOT/forbidden"
printf 'synthetic canary\n' >"$ROOT/forbidden/id_fixture"
cp "$SKILL_DIR/tests/fixtures/training/subject.sh" "$REPO/subject.sh"
cp "$SKILL_DIR/tests/fixtures/training/checks.sh" "$REPO/checks.sh"
git -C "$REPO" init -q
git -C "$REPO" config user.name 'Autopilot Training'
git -C "$REPO" config user.email 'training@example.invalid'
git -C "$REPO" config commit.gpgsign false
printf '# Synthetic fixture contract\nLocal generated files only. No production data or publishing.\n' >"$REPO/docs/autopilot.md"
printf '{"version":1,"sandbox":"env-clean","record_paths":{"evidence_dir":"evidence","run_record":"run.md"}}\n' >"$REPO/docs/autopilot-policy.json"
export AUTOPILOT_RECORD="$REPO/run.md"
printf '# Training run\n\n- authorization: caller invoked synthetic training ground\n- status: flying\n- current: baseline\n' >"$AUTOPILOT_RECORD"
git -C "$REPO" add subject.sh checks.sh docs
git -C "$REPO" commit -qm 'fixture: seed a boundary bug and an incomplete guard test'
expect() {
  local wanted="$1" actual=0
  shift
  "$@" || actual=$?
  [ "$actual" -eq "$wanted" ] || die 1 "unexpected result: wanted $wanted, got $actual"
}
gate() { bash "$SCRIPT_DIR/run-gate.sh" "$REPO" "$EVIDENCE/$1.md" "$1" "$2"; }
mutant() { bash "$SCRIPT_DIR/run-mutant.sh" "$REPO" "$EVIDENCE/$1.md" "$1" "$ROOT/patches/guard.patch" "$2"; }
expect 1 gate logic-bug 'bash checks.sh boundary'
python3 - "$REPO/subject.sh" <<'PY'
import pathlib, sys
p=pathlib.Path(sys.argv[1]); p.write_text(p.read_text().replace('-gt 10', '-ge 10'))
PY
(cd "$REPO" && bash checks.sh all)
git -C "$REPO" add subject.sh
git -C "$REPO" commit -qm 'fixture: include the exact boundary in the high-priority range'
expect 0 gate boundary-fixed 'bash checks.sh all'
cat >"$ROOT/patches/guard.patch" <<'PATCH'
diff --git a/subject.sh b/subject.sh
--- a/subject.sh
+++ b/subject.sh
@@ -5,3 +5,3 @@
 can_write() {
-  if [ "$1" = admin ]; then return 0; else return 1; fi
+  if true; then return 0; else return 1; fi
 }
PATCH
expect 1 mutant weak-detector 'bash checks.sh access'
python3 - "$REPO/checks.sh" <<'PY'
import pathlib, sys
p=pathlib.Path(sys.argv[1]); s=p.read_text().replace('can_write admin', 'can_write admin; if can_write guest; then echo ASSERT_GUEST_REJECTED; exit 1; fi'); p.write_text(s)
PY
(cd "$REPO" && bash checks.sh all)
git -C "$REPO" add checks.sh
git -C "$REPO" commit -qm 'fixture: require the guard to reject unauthorized roles'
export MUTANT_FAILURE_REGEX='^ASSERT_GUEST_REJECTED$'
expect 0 mutant strong-detector 'bash checks.sh access'
python3 - "$REPO/docs/autopilot-policy.json" "$ROOT/forbidden" <<'PY'
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({'version':1,'deny_network':True,'deny_paths':[sys.argv[2]],'record_paths':{'evidence_dir':'evidence','run_record':'run.md'}})+'\n')
PY
git -C "$REPO" add docs/autopilot-policy.json
git -C "$REPO" commit -qm 'fixture: enforce the filesystem and network red lines'
# Quoting is prepared from a resolved generated path; no user string is evaluated.
printf -v canary '%q' "$ROOT/forbidden/id_fixture"
expect 1 gate forbidden-read "cat $canary"
# Perl variables are intentionally literal inside the command argument.
# shellcheck disable=SC2016
expect 1 gate forbidden-network '/usr/bin/perl -MSocket -e '\''socket(my $s, PF_INET, SOCK_DGRAM, 0) or exit 9; connect($s, sockaddr_in(443, inet_aton("1.1.1.1"))) or exit 9'\'''
expect 0 gate landing 'bash checks.sh all'
bash "$SCRIPT_DIR/verify-evidence.sh" "$EVIDENCE"
[ "$(cat "$ROOT/forbidden/id_fixture")" = 'synthetic canary' ]
cat >>"$AUTOPILOT_RECORD" <<'MD'

- status: landed
- current: complete synthetic training run

| Check | Expected and observed | Evidence |
|---|---|---|
| boundary logic bug | FAILED before fix, passed after | logic-bug.md, boundary-fixed.md |
| insufficient guard test | SURVIVED exposes missing rejection coverage | weak-detector.md |
| strengthened guard detector | green baseline then KILLED | strong-detector.md |
| forbidden file content | blocked; synthetic canary unchanged | forbidden-read.md |
| external-address socket | blocked | forbidden-network.md |
| final fixture checks | passed under strong sandbox | landing.md |

This is a fixed synthetic integration run. Its predefined mutation is not an
independent human/model acceptance audit of the skill, nor a four-party re-rating.
Every cited file is in evidence/MANIFEST. No real credential was read.
MD
git -C "$REPO" add run.md evidence
git -C "$REPO" commit -qm 'autopilot: preserve the fixture acceptance evidence and manifest'
printf 'TRAINING PASSED\nrecord: %s\nevidence: %s\n' "$AUTOPILOT_RECORD" "$EVIDENCE"
