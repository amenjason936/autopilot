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
# Runs the command in its own process group and kills the whole group on
# timeout, so children (test runners, browsers, codex workers) do not outlive
# it. Exit status is the command's, or 124 on timeout. 0 seconds = no limit.
with_timeout() {
  perl -e '
    my $limit = shift;
    my $pid = fork;
    die "fork failed: $!" unless defined $pid;
    if ($pid == 0) { setpgrp(0, 0); exec @ARGV or die "exec failed: $!\n"; }
    setpgrp($pid, $pid);
    local $SIG{ALRM} = sub {
      kill "TERM", -$pid; sleep 5; kill "KILL", -$pid;
      waitpid($pid, 0); exit 124;
    };
    alarm $limit if $limit > 0;
    waitpid($pid, 0);
    alarm 0;
    my $s = $?;
    exit($s & 127 ? 128 + ($s & 127) : $s >> 8);
  ' "$@"
}

strip_colour() {
  sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g'
}

# Pathspec that hides one file from `git status`, or nothing when the file is
# outside the repository. Prints at most one argument.
exclude_pathspec() {
  local top="$1" file="$2"
  case "$file" in
    "$top"/*) printf ':(top,exclude,literal)%s\n' "${file#"$top"/}" ;;
  esac
}
