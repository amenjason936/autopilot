#!/usr/bin/env bats
load test_helper

@test "alternate policy controls review dispatch and frozen request identity" {
  mkdir "$REPO/docs" "$CASE/bin"
  printf '{"version":1,"sandbox":"env-clean"}' >"$REPO/docs/autopilot-policy.json"
  printf '{"version":1,"deny_network":true}' >"$REPO/docs/strict.json"
  printf 'record\n' >"$REPO/record.md"
  commit_fixture
  printf '#!/bin/sh\nprintf called > "%s"\nexit 42\n' "$CASE/called" >"$CASE/bin/codex"
  chmod +x "$CASE/bin/codex"
  export PATH="$CASE/bin:$PATH" GATE_POLICY=docs/strict.json
  run bash "$SKILL/scripts/codex-review.sh" "$REPO" HEAD "$REPO/record.md" "$CASE/blocked.json"
  [ "$status" -eq 77 ]
  [ ! -e "$CASE/called" ]
  run bash "$SKILL/scripts/codex-review.sh" --prompt-only "$REPO" HEAD "$REPO/record.md" "$CASE/request.json"
  [ "$status" -eq 0 ]
  run jq -r .inputs.execution_policy.path "$CASE/request.json.request.json"
  [ "$output" = docs/strict.json ]
  printf '{"verdict":"approve","summary":"ok","findings":[],"limits":"synthetic"}' >"$CASE/request.json"
  python3 "$SKILL/scripts/review_identity.py" seal "$CASE/request.json" "$CASE/request.json.request.json"
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/request.json" "$CASE/request.json.request.json" "$REPO" HEAD HEAD record.md landing
  [ "$status" -eq 0 ]
  export GATE_POLICY=docs/autopilot-policy.json
  run bash "$SKILL/scripts/validate-findings.sh" "$CASE/request.json" "$CASE/request.json.request.json" "$REPO" HEAD HEAD record.md landing
  [ "$status" -eq 70 ]
  # The opposite combination must use the selected permissive policy too.
  printf '{"version":1,"deny_network":true}' >"$REPO/docs/autopilot-policy.json"
  printf '{"version":1,"sandbox":"env-clean"}' >"$REPO/docs/allowed.json"
  commit_fixture
  export GATE_POLICY=docs/allowed.json
  run bash "$SKILL/scripts/codex-review.sh" "$REPO" HEAD "$REPO/record.md" "$CASE/allowed.json"
  [ "$status" -eq 42 ]
  [ -f "$CASE/called" ]
}

@test "failed git status with empty output cannot prove clean source" {
  mkdir "$CASE/bin"
  real_git="$(command -v git)"
  canonical_repo="$(cd "$REPO" && pwd -P)"
  cat >"$CASE/bin/git" <<EOF
#!/bin/bash
case "\$*" in *status*--porcelain*)
  if [ -e '$CASE/status-fault' ] && [ "\$PWD" = '$canonical_repo' ]; then echo SYNTHETIC_GIT_IO_ERROR >&2; exit 74; fi ;;
esac
exec '$real_git' "\$@"
EOF
  chmod +x "$CASE/bin/git"
  export PATH="$CASE/bin:$PATH"
  run gate statusfault "touch '$CASE/status-fault'"
  [ "$status" -eq 1 ]
  grep -q 'FAILED: HEAD or code changed' "$EVID/statusfault.md"
}

@test "failed output filters cannot publish a successful gate" {
  mkdir "$CASE/bin"
  printf '#!/bin/sh\necho SYNTHETIC_TAIL_IO_ERROR >&2\nexit 74\n' >"$CASE/bin/tail"
  chmod +x "$CASE/bin/tail"
  run env PATH="$CASE/bin:$PATH" bash "$SKILL/scripts/run-gate.sh" "$REPO" "$EVID/filter.md" filter 'echo OUTPUT_MARKER'
  [ "$status" -eq 70 ]
  [ ! -e "$EVID/filter.md" ]
  [ ! -e "$EVID/MANIFEST" ]
  [ -f "$EVID/filter.md.partial" ]
  run gate filterpositive 'echo OUTPUT_MARKER'
  [ "$status" -eq 0 ]
  grep -q '^OUTPUT_MARKER$' "$EVID/filterpositive.md"
}

@test "grep I/O errors fail while no matching retained lines remain valid" {
  mkdir "$CASE/bin"
  printf '#!/bin/sh\nexit 2\n' >"$CASE/bin/grep"
  chmod +x "$CASE/bin/grep"
  # Permit the empty-input regex check, then fail during actual collection.
  printf '#!/bin/sh\nif [ "$#" -eq 3 ]; then exit 1; fi\nexit 2\n' >"$CASE/bin/grep"
  export GATE_KEEP_REGEX='not-present'
  run env PATH="$CASE/bin:$PATH" bash "$SKILL/scripts/run-gate.sh" "$REPO" "$EVID/grep.md" grep 'echo OUTPUT_MARKER'
  [ "$status" -eq 70 ]
  [ ! -e "$EVID/grep.md" ]
  run gate nomatch 'echo OUTPUT_MARKER'
  [ "$status" -eq 0 ]
}

@test "lite refuses dependency build executable and mode-only changes" {
  printf '{"stages":1,"network":false,"publish":false,"risk":"documentation-only"}' >"$CASE/run.json"
  for name in requirements.txt CMakeLists.txt task.txt executable.md; do
    base="$(git -C "$REPO" rev-parse HEAD)"
    printf 'synthetic\n' >"$REPO/$name"
    case "$name" in task.txt|executable.md) chmod +x "$REPO/$name" ;; esac
    commit_fixture
    run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
    [ "$status" -eq 1 ]
  done
  printf 'documentation\n' >"$REPO/guide.md"
  commit_fixture
  base="$(git -C "$REPO" rev-parse HEAD)"
  chmod +x "$REPO/guide.md"
  commit_fixture
  run bash "$SKILL/scripts/check-lite.sh" "$REPO" "$base" HEAD "$CASE/run.json"
  [ "$status" -eq 1 ]
}

@test "record inventory rejects HTML and JSON source but admits registered reports" {
  mkdir "$REPO/docs" "$REPO/web"
  printf '{"version":1,"record_paths":{"evidence_dir":"web"}}' >"$REPO/docs/autopilot-policy.json"
  printf '<script>application()</script>\n' >"$REPO/web/index.html"
  printf '{"runtime":"configuration"}\n' >"$REPO/web/config.json"
  commit_fixture
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$REPO/web/check.md" check true
  [ "$status" -eq 64 ]
  # A valid live manifest cannot retrospectively authorize pinned source files.
  python3 - "$REPO/web" <<'PYTEST'
import pathlib, hashlib, sys
p = pathlib.Path(sys.argv[1])
(p/'MANIFEST').write_text(''.join(hashlib.sha256((p/name).read_bytes()).hexdigest()+'  '+name+'\n' for name in ('index.html', 'config.json')))
PYTEST
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$REPO/web/live.md" live true
  [ "$status" -eq 64 ]
  mkdir "$REPO/proof"
  printf '{"version":1,"record_paths":{"evidence_dir":"proof"}}' >"$REPO/docs/autopilot-policy.json"
  printf '<p>registered report</p>\n' >"$REPO/proof/report.html"
  python3 - "$REPO/proof" <<'PY'
import pathlib,hashlib,sys
p=pathlib.Path(sys.argv[1]);data=(p/'report.html').read_bytes()
(p/'MANIFEST').write_text(hashlib.sha256(data).hexdigest()+'  report.html\n')
PY
  commit_fixture
  run bash "$SKILL/scripts/run-gate.sh" "$REPO" "$REPO/proof/check.md" check true
  [ "$status" -eq 0 ]
  printf 'unregistered source\n' >"$REPO/proof/new.html"
  run bash "$SKILL/scripts/run-gate.sh" --dry-run "$REPO" "$REPO/proof/again.md" again true
  [ "$status" -eq 64 ]
}

@test "source write and restore is prevented in env-clean and strict modes" {
  require_os_sandbox
  for mode in plain strict; do
    if [ "$mode" = strict ]; then
      mkdir "$REPO/docs"
      printf '{"version":1,"deny_network":true}' >"$REPO/docs/autopilot-policy.json"
      commit_fixture
    fi
    run gate "$mode" 'cp value "$TMPDIR/before"; if printf changed > value; then cp "$TMPDIR/before" value; echo ASSERT_SOURCE_WRITABLE; exit 1; fi; test "$(cat value)" = safe && printf artifact > "$AUTOPILOT_OUTPUT/result"'
    [ "$status" -eq 0 ]
    grep -q 'source guard: PASS' "$EVID/$mode.md"
  done
}

@test "new declared output directories are writable without exposing source" {
  require_os_sandbox
  mkdir "$REPO/docs"
  printf '{"version":1,"write_dirs":["out"]}' >"$REPO/docs/autopilot-policy.json"
  commit_fixture
  run gate build 'printf artifact >out/file; test "$(cat out/file)" = artifact; ! printf changed >value'
  [ "$status" -eq 0 ]
  printf '{"version":1,"write_dirs":["docs"]}' >"$REPO/docs/autopilot-policy.json"
  commit_fixture
  run gate sourcealias true
  [ "$status" -eq 64 ]
}

@test "applied mutant snapshot rejects extra edits and patch reversal" {
  # The OS guard blocks detector writes; separately fault the saved-state
  # comparator with author-side writes to test defense in depth deterministically.
  printf '{"write_dirs":[]}' >"$CASE/policy.json"
  python3 "$SKILL/scripts/source_state.py" freeze "$REPO" "$CASE/policy.json" "$CASE/state.json"
  printf changed >"$REPO/value"
  run python3 "$SKILL/scripts/source_state.py" verify "$REPO" "$CASE/policy.json" "$CASE/state.json"
  [ "$status" -eq 1 ]
  printf broken >"$REPO/value"
  python3 "$SKILL/scripts/source_state.py" freeze "$REPO" "$CASE/policy.json" "$CASE/state.json"
  printf safe >"$REPO/value"
  run python3 "$SKILL/scripts/source_state.py" verify "$REPO" "$CASE/policy.json" "$CASE/state.json"
  [ "$status" -eq 1 ]
}

@test "mutant cannot rewrite its source and retains the registered patch" {
  require_os_sandbox
  patch_value
  export MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$'
  run mutant immutability 'if test "$(cat value)" = broken; then if printf unrelated >value; then echo UNREGISTERED_SOURCE_WRITE; exit 2; fi; test "$(cat value)" = broken || exit 2; echo ASSERT_VALUE_SAFE; exit 1; fi'
  [ "$status" -eq 0 ]
  grep -q '^KILLED\|^- result: KILLED' "$EVID/immutability.md"
}

@test "skip-only and zero-test TAP detectors are inconclusive rather than survived" {
  patch_value
  export MUTANT_FAILURE_REGEX='^ASSERT_VALUE_SAFE$'
  run mutant skip 'printf "1..1\nok 1 platform test # skip unavailable\n"'
  [ "$status" -eq 2 ]
  run mutant empty 'printf "1..0\n"'
  [ "$status" -eq 2 ]
  run mutant patchedskip 'if test "$(cat value)" = safe; then printf "1..1\nok 1 actual baseline\n"; else printf "1..1\nok 1 platform test # skip unavailable\n"; fi'
  [ "$status" -eq 2 ]
}

@test "readonly source cannot be rewritten through a hardlink alias" {
  require_os_sandbox
  run gate alias 'if ln value "$HOME/source-alias"; then ! printf changed >"$HOME/source-alias"; fi; test "$(cat value)" = safe'
  [ "$status" -eq 0 ]
}

@test "commands cannot rewrite runner controls helpers or evidence" {
  require_os_sandbox
  isolate_runner
  run gate controls 'for p in "$(dirname "$TMPDIR")/profile.sb" "$(dirname "$TMPDIR")/policy.json" "$(dirname "$TMPDIR")/tree-source.json"; do ! printf corrupted > "$p" || exit 1; done' "! printf corrupted > '$SKILL/scripts/source_state.py'" "! printf forged > '$EVID/controls.md.partial'" 'test "$(cat value)" = safe'
  [ "$status" -eq 0 ]
  run bash "$SKILL/scripts/verify-evidence.sh" "$EVID"
  [ "$status" -eq 0 ]
}

@test "valid unnumbered TAP cases count as active tests" {
  run gate unnumbered 'printf "TAP version 13\n1..1\nok - actual test\n"'
  [ "$status" -eq 0 ]
  run gate bare 'printf "1..1\nok\n"'
  [ "$status" -eq 0 ]
  run gate skipped 'printf "1..1\nok - unavailable # SKIP optional\n"'
  [ "$status" -eq 1 ]
}

@test "skip-only TAP without a plan is inconclusive" {
  run gate noplan 'printf "TAP version 13\nok 1 - unavailable # SKIP optional\n"'
  [ "$status" -eq 1 ]
  patch_value
  run mutant noplanmutant 'if test "$(cat value)" = safe; then printf "1..1\nok - active\n"; else printf "TAP version 13\nok 1 - unavailable # SKIP optional\n"; fi'
  [ "$status" -eq 2 ]
}
