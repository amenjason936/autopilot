# Shared helpers for the autopilot scripts. Sourced, not run.
# Portable across GNU/Linux and macOS (bash 3.2, BSD userland).

die() {
  local status="$1"
  shift
  echo "$*" >&2
  exit "$status"
}

require() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || die 69 "required tool not found on PATH: $tool"
  done
}

# require_seconds <name> <value>: non-negative integer seconds, or exit 64.
require_seconds() {
  case "$2" in
    '' | *[!0-9]*) die 64 "$1 must be whole seconds, got: $2" ;;
  esac
}

# Portable temp file / dir: GNU mktemp rejects `-t name` without X's.
make_temp() {
  mktemp "${TMPDIR:-/tmp}/autopilot-$1.XXXXXX" || die 70 "mktemp failed"
}
make_temp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/autopilot-$1.XXXXXX" || die 70 "mktemp -d failed"
}

# Absolute, symlink-resolved path of a file whose directory may not exist yet.
abs_path() {
  local dir
  dir="$(dirname "$1")"
  mkdir -p "$dir" || die 70 "cannot create directory: $dir"
  printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$(basename "$1")"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -c1-16
  else
    shasum -a 256 "$1" | cut -c1-16
  fi
}

# with_timeout <seconds> <command...>
# Runs the command in a new session (no controlling terminal, so it cannot
# block on a TTY) and owns that whole process group: on timeout, on INT/TERM/
# HUP, and after a normal exit, every process left in it is killed. Returns
# the command's status (or 128+signal); sets TIMED_OUT=1 when the limit hit,
# so a command that itself exits 124 is not mistaken for a timeout.
# 0 seconds = no limit. Stdin is passed through.
TIMED_OUT=0
WT_PID=
WT_MARKER_FILE=
with_timeout() {
  local limit="$1" status
  shift
  WT_MARKER_FILE="$(make_temp timeout)" || return 70
  WT_MARKER="$WT_MARKER_FILE" perl -MPOSIX -e '
    my $limit = shift;
    my $pid = fork;
    die "fork failed: $!\n" unless defined $pid;
    if ($pid == 0) { POSIX::setsid(); exec @ARGV or die "exec failed: $!\n"; }
    my $stop = sub {
      my $code = shift;
      kill "TERM", -$pid;
      for (1 .. 50) {
        waitpid($pid, WNOHANG);
        last unless kill 0, -$pid;
        select(undef, undef, undef, 0.1);
      }
      kill "KILL", -$pid;
      waitpid($pid, 0);
      exit $code;
    };
    $SIG{ALRM} = sub {
      if (open my $fh, ">", $ENV{WT_MARKER}) { print $fh "timeout\n"; close $fh }
      $stop->(124);
    };
    $SIG{INT} = sub { $stop->(130) };
    $SIG{TERM} = sub { $stop->(143) };
    $SIG{HUP} = sub { $stop->(129) };
    alarm $limit if $limit > 0;
    waitpid($pid, 0);
    my $s = $?;
    alarm 0;
    kill "TERM", -$pid;    # stragglers the command left in the background
    exit($s & 127 ? 128 + ($s & 127) : $s >> 8);
  ' "$limit" "$@" <&0 &
  WT_PID=$!
  wait "$WT_PID"
  status=$?
  WT_PID=
  TIMED_OUT=0
  [ -s "$WT_MARKER_FILE" ] && TIMED_OUT=1
  rm -f "$WT_MARKER_FILE"
  WT_MARKER_FILE=
  return "$status"
}

# A signal to the script itself (Ctrl-C, kill <pid>) stops the running
# command's whole group before the script exits; EXIT traps then clean up.
on_signal() {
  if [ -n "${WT_PID:-}" ]; then
    kill -TERM "$WT_PID" 2>/dev/null
    wait "$WT_PID" 2>/dev/null
  fi
  [ -n "${WT_MARKER_FILE:-}" ] && rm -f "$WT_MARKER_FILE"
  exit "$1"
}
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
trap 'on_signal 129' HUP

strip_colour() {
  sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g'
}

# Plain-text output block body: no colour, no trailing spaces, and always
# newline-terminated so a closing fence lands on its own line.
clean_output() {
  tr -d '\000' | strip_colour | sed -E 's/[[:space:]]+$//' | awk 1
}

# record_specs <top> <path>...: sets RECORD_SPECS to pathspecs that hide the
# run's record paths (evidence directory, run record) from git. Paths outside
# the repository are ignored. A record path that is the repository top would
# hide everything, so it is refused.
RECORD_SPECS=()
record_specs() {
  local top="$1" path
  shift
  RECORD_SPECS=()
  for path in "$@"; do
    [ -n "$path" ] || continue
    case "$path" in
      "$top") die 64 "record path is the repository top: give evidence its own directory" ;;
      "$top"/*) RECORD_SPECS+=(":(top,exclude,literal)${path#"$top"/}") ;;
    esac
  done
}

# git_code <git args>: runs git with ':(top)' plus RECORD_SPECS appended as
# pathspecs, so it sees code only. Safe under set -u with an empty array.
git_code() {
  git "$@" -- ':(top)' ${RECORD_SPECS[@]+"${RECORD_SPECS[@]}"}
}

# tested_commit <top>: the latest commit at or before HEAD that changed code
# (anything outside the record paths). Record commits never move it.
tested_commit() {
  local sha
  sha="$(cd "$1" && git_code log -1 --format=%H HEAD)" || return 1
  [ -n "$sha" ] || sha="$(git -C "$1" rev-parse --verify HEAD)"
  printf '%s\n' "$sha"
}
