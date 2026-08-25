#!/usr/bin/env bash
# Install the dsh-code-security bundle (single package since 0.2.0):
#   1. agent preset  -> ~/.dsh/.agent-presets/dsh-security (skills + scan tools)
#   2. bundle        -> `dsh plugin --profile web add <this directory>`; the
#      package declares `dsh.bundle.patch`, so `dsh plugin add` activates it as
#      a profile bundle layer automatically (gate panel + batch tools mount;
#      no manual cordis.patch.yml row needed).
# Run this script FROM A PROJECT CHECKOUT - it installs the LOCAL files.
# Idempotent: re-running replaces the previous copies and migrates installs of
# the two legacy packages (dsh-security-gate / dsh-security-tools) away.
set -euo pipefail

profile_name="${DSH_PROFILE:-web}"

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ ! -f "$src/preset/agent.cordis.yml" ] || [ ! -f "$src/index.js" ]; then
  echo "install.sh must be run from the project checkout (it installs the LOCAL files)." >&2
  echo "Example: git clone https://github.com/ihuajiu/dsh-code-security && cd dsh-code-security && ./install.sh" >&2
  exit 1
fi

dsh="${DSH_HOME:-$HOME/.dsh}"

# Issue #1 finding-3 style guard: never let an unvalidated install root reach
# rm -rf below. Refuse empty/root/bare-dot forms; canonicalize through
# symlinks; require an absolute, non-root path.
case "${dsh%/}" in
  ''|/|.|..) printf 'install: refusing unsafe DSH_HOME "%s"\n' "$dsh" >&2; exit 1 ;;
esac
if resolved=$(cd -- "$dsh" 2>/dev/null && pwd -P); then dsh=$resolved; fi
case "$dsh" in
  /*) [ "${dsh%/}" != "/" ] || { printf 'install: refusing root "/"\n' >&2; exit 1; } ;;
  *) printf 'install: DSH_HOME "%s" is not an absolute path\n' "$dsh" >&2; exit 1 ;;
esac

# ── 1. agent preset ─────────────────────────────────────────────────────────
preset_dest="$dsh/.agent-presets/dsh-security"
echo "Installing dsh-security preset to $preset_dest"
rm -rf "$preset_dest"
mkdir -p "$preset_dest"
cp -R "$src/preset/." "$preset_dest/"

# ── 2. the bundle into the profile ──────────────────────────────────────────
profile_dir="$dsh/profiles/$profile_name"
if [ -f "$profile_dir/package.json" ]; then
  # Migrate legacy two-package installs out of the way first (best effort).
  for legacy in dsh-security-gate dsh-security-tools; do
    ( cd "$profile_dir" && dsh plugin --profile "$profile_name" remove "$legacy" ) >/dev/null 2>&1 || true
  done
  echo "Installing dsh-code-security bundle into profile $profile_name"
  ( cd "$profile_dir" && dsh plugin --profile "$profile_name" add "$src" ) || {
    echo "dsh plugin add failed" >&2; exit 1;
  }
else
  echo "profile '$profile_name' not found — skip bundle install (preset installed only)."
fi

echo
echo 'Done. Next steps:'
echo "  1. Restart dsh $profile_name so the gate loads (composition changes apply at boot)."
echo '  2. New DSH session -> pick the "安全审计模式" preset (id: dsh-security).'
echo '  3. The gate auto-audits newly installed plugins with the harness model; watch <DSH_HOME>/dsh-security/summary.json.'
