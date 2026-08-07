#!/usr/bin/env bash
# setup.sh — runs once inside the sandbox to get it ready.
# start.sh copies this in and runs it; you don't call it yourself.
#
# Each step checks for its own tool, so a tool that already ships in the base
# image never blocks the others from installing.
set -euo pipefail

PROVISION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 1. Neutral name on any changes Claude saves.
# ---------------------------------------------------------------------------
git config --global user.name  "dev"
git config --global user.email "dev@localhost"
git config --global init.defaultBranch main

# ---------------------------------------------------------------------------
# 2. Command line tools. Checked one by one, then installed in a single pass.
# ---------------------------------------------------------------------------
missing=()
command -v rg   >/dev/null 2>&1 || missing+=(ripgrep)
command -v fzf  >/dev/null 2>&1 || missing+=(fzf)
command -v jq   >/dev/null 2>&1 || missing+=(jq)

if [ ${#missing[@]} -gt 0 ]; then
  echo "installing: ${missing[*]}"
  sudo apt-get update -qq
  sudo apt-get install -y "${missing[@]}"
fi

# ---------------------------------------------------------------------------
# 3. pnpm. corepack writes its shim into a system folder, so enabling needs
#    sudo, but preparing must run as you so the download lands in your cache.
# ---------------------------------------------------------------------------
if ! command -v pnpm >/dev/null 2>&1; then
  if command -v corepack >/dev/null 2>&1; then
    sudo corepack enable
    corepack prepare pnpm@latest --activate
  else
    sudo npm install -g pnpm
  fi
fi

# ---------------------------------------------------------------------------
# 4. Your personal Claude config. The sandbox does not see ~/.claude from your
#    Mac, so anything you want globally has to be placed here.
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.claude"

for f in settings.json CLAUDE.md; do
  if [ -f "$PROVISION_DIR/claude/$f" ]; then
    cp "$PROVISION_DIR/claude/$f" "$HOME/.claude/$f"
    echo "installed ~/.claude/$f"
  fi
done

# ---------------------------------------------------------------------------
# 5. Claude plugins, read from claude/plugins.txt.
#    Failures here are reported but don't abort the rest of the setup, since
#    plugin installs depend on network access and sometimes on being logged in.
# ---------------------------------------------------------------------------
PLUGINS_FILE="$PROVISION_DIR/claude/plugins.txt"

if [ -f "$PLUGINS_FILE" ] && command -v claude >/dev/null 2>&1; then
  while read -r marketplace plugin || [ -n "${marketplace:-}" ]; do
    case "$marketplace" in ''|\#*) continue ;; esac
    [ -n "${plugin:-}" ] || continue

    echo "adding marketplace: $marketplace"
    claude plugin marketplace add "$marketplace" || echo "  (already added, or add failed)"

    echo "installing plugin: $plugin"
    claude plugin install "$plugin" || echo "  could not install $plugin, install it by hand with /plugin"
  done < "$PLUGINS_FILE"
fi

touch "$HOME/.setup-done"
echo
echo "All set."
