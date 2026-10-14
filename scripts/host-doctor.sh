#!/bin/bash
# host-doctor.sh [--fix] [<repo>]
# Probes this host for what the runner needs and prints one recommendation for
# the repository's committed policy (docs/autopilot-policy.json at HEAD):
#   strict    the OS sandbox launches; run the policy as written
#   install   it can launch after the listed host changes (--fix applies them
#             when sudo works without a password; only with the human's or the
#             contract's authorization, since they change the host)
#   env-clean the policy is unrestricted; the runner uses env-clean and
#             discloses the weaker boundary (no host change needed)
#   degraded  restrictive policy, no usable backend, and the policy approves
#             "fallback": "env-clean": gates run with red lines NOT OS-enforced
#   park      restrictive policy, no usable backend, no approved fallback
# Exit: 0 strict/env-clean/degraded; 1 install (not applied); 2 park;
# 64 usage; 69 a required tool is missing.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
FIX=0
if [ "${1:-}" = --fix ]; then FIX=1; shift; fi
[ $# -le 1 ] || { echo 'usage: host-doctor.sh [--fix] [<repo>]' >&2; exit 64; }
REPO="${1:-.}"

missing=()
for tool in git perl python3 jq; do command -v "$tool" >/dev/null 2>&1 || missing+=("$tool"); done
printf 'required tools: %s\n' "$([ ${#missing[@]} -eq 0 ] && echo ok || echo "MISSING ${missing[*]}")"
for tool in codex bats shellcheck; do
  printf 'optional %s: %s\n' "$tool" "$(command -v "$tool" >/dev/null 2>&1 && echo found || echo absent)"
done

OS="$(uname -s)"
backend_ok() {
  if [ "$OS" = Darwin ]; then
    command -v sandbox-exec >/dev/null 2>&1 && sandbox-exec -p '(version 1)(allow default)' /usr/bin/true >/dev/null 2>&1
  else
    command -v bwrap >/dev/null 2>&1 &&
      bwrap --die-with-parent --unshare-user --unshare-pid --unshare-net --ro-bind / / --proc /proc --dev /dev /bin/true >/dev/null 2>&1
  fi
}

SUDO=no
if [ "$(id -u)" -eq 0 ]; then SUDO=root; elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then SUDO=yes; fi
PKG=
for manager in apt-get dnf yum pacman apk zypper brew; do
  if command -v "$manager" >/dev/null 2>&1; then PKG="$manager"; break; fi
done
as_root() { if [ "$SUDO" = root ]; then "$@"; else sudo -n "$@"; fi; }

FIXES=()
REASON=
if backend_ok; then
  BACKEND=usable
elif [ "$OS" = Darwin ]; then
  BACKEND=unusable
  REASON='sandbox-exec cannot launch; macOS offers no supported replacement'
else
  BACKEND=unusable
  if ! command -v bwrap >/dev/null 2>&1; then
    REASON='bwrap is not installed'
    case "$PKG" in
      apt-get) FIXES+=('apt-get install -y bubblewrap') ;;
      dnf|yum) FIXES+=("$PKG install -y bubblewrap") ;;
      pacman) FIXES+=('pacman -S --noconfirm bubblewrap') ;;
      apk) FIXES+=('apk add bubblewrap') ;;
      zypper) FIXES+=('zypper --non-interactive install bubblewrap') ;;
    esac
  fi
  if [ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" = 1 ] && [ ! -f /etc/apparmor.d/bwrap ]; then
    REASON="${REASON:+$REASON; }AppArmor restricts unprivileged user namespaces and has no bwrap profile"
    FIXES+=("sh -c 'printf \"abi <abi/4.0>,\\ninclude <tunables/global>\\nprofile bwrap /usr/bin/bwrap flags=(unconfined) {\\n  userns,\\n  include if exists <local/bwrap>\\n}\\n\" > /etc/apparmor.d/bwrap && apparmor_parser -r /etc/apparmor.d/bwrap'")
  fi
  if [ "$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null)" = 0 ]; then
    REASON="${REASON:+$REASON; }unprivileged user namespaces are disabled (kernel.unprivileged_userns_clone=0)"
    FIXES+=('sysctl -w kernel.unprivileged_userns_clone=1')
  fi
  if [ -f /.dockerenv ] || grep -qaE 'docker|containerd|kubepods' /proc/1/cgroup 2>/dev/null; then
    REASON="${REASON:+$REASON; }running in a container, which usually forbids nested namespaces"
  fi
  [ -n "$REASON" ] || REASON='bwrap is installed but cannot create namespaces'
fi
printf 'OS sandbox (%s): %s%s\n' "$([ "$OS" = Darwin ] && echo sandbox-exec || echo bwrap)" "$BACKEND" "${REASON:+ — $REASON}"
printf 'privilege: sudo without password: %s; package manager: %s\n' "$SUDO" "${PKG:-none}"

if [ "$BACKEND" = unusable ] && [ "$FIX" -eq 1 ] && [ ${#FIXES[@]} -gt 0 ] && [ "$SUDO" != no ]; then
  for fix in "${FIXES[@]}"; do
    printf 'applying: %s\n' "$fix"
    # shellcheck disable=SC2086
    as_root sh -c "$fix" || printf 'failed: %s\n' "$fix"
  done
  if backend_ok; then BACKEND=usable; REASON=; FIXES=(); printf 'OS sandbox after --fix: usable\n'; else printf 'OS sandbox after --fix: still unusable\n'; fi
fi

RESTRICTIVE=unknown
FALLBACK=park
if POLICY="$(python3 "$SCRIPT_DIR/policy.py" select "$REPO" HEAD 2>/dev/null)"; then
  RESTRICTIVE="$(printf '%s' "$POLICY" | jq -r '.effective | if .deny_network or (.deny_paths | length > 0) then "yes" else "no" end')"
  FALLBACK="$(printf '%s' "$POLICY" | jq -r '.effective.fallback // "park"')"
  printf 'policy: %s (restrictive: %s; fallback: %s)\n' "$(printf '%s' "$POLICY" | jq -r '.path // "none (defaults)"')" "$RESTRICTIVE" "$FALLBACK"
elif git -C "$REPO" cat-file -e HEAD:docs/autopilot.md 2>/dev/null; then
  printf 'policy: contract present but no valid committed docs/autopilot-policy.json at HEAD — gates will refuse; commit the policy, then run host-doctor again\n'
  RESTRICTIVE=yes
else
  printf 'policy: none at %s HEAD (no contract yet); recommendation assumes a restrictive one\n' "$REPO"
  RESTRICTIVE=yes
fi

[ ${#missing[@]} -eq 0 ] || { printf 'recommendation: install the required tools first\n'; exit 69; }
if [ "$BACKEND" = usable ]; then
  printf 'recommendation: strict — the OS sandbox launches; run the policy as written\n'; exit 0
fi
if [ "$RESTRICTIVE" = no ]; then
  printf 'recommendation: env-clean — unrestricted policy; gates run without OS source protection and say so\n'; exit 0
fi
if [ ${#FIXES[@]} -gt 0 ] && [ "$SUDO" != no ]; then
  printf 'recommendation: install — needs host changes (authorization required; host-doctor.sh --fix applies them):\n'
  printf '  %s\n' "${FIXES[@]}"
  exit 1
fi
if [ "$FALLBACK" = env-clean ]; then
  printf 'recommendation: degraded — the policy approves fallback env-clean: gates run, red lines NOT OS-enforced (disclosed in every evidence file)\n'
  [ ${#FIXES[@]} -eq 0 ] || printf '  an administrator could restore strict mode with:\n%s\n' "$(printf '    %s\n' "${FIXES[@]}")"
  exit 0
fi
printf 'recommendation: park — restrictive policy, no usable OS sandbox, no approved fallback. Ask the human to either\n'
[ ${#FIXES[@]} -eq 0 ] || printf '  - run as an administrator:\n%s\n' "$(printf '      %s\n' "${FIXES[@]}")"
printf '  - or approve "fallback": "env-clean" in the committed policy (red lines then NOT OS-enforced)\n'
exit 2
