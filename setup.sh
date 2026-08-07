#!/usr/bin/env bash
# setup.sh — runs INSIDE the sandbox, once. start.sh copies it in and runs it.
#
# You can also run it directly against an existing sandbox: see the README,
# "Provisioning a sandbox you already made".
#
# Every step checks for its own tool, so something already present in the base
# image never blocks the rest from installing.
set -euo pipefail

PROVISION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 1. Neutral git identity.
#    Set globally inside the sandbox so the agent's commits are labelled 'dev'
#    without rewriting your project's own .git/config on the host.
# ---------------------------------------------------------------------------
git config --global user.name  "dev"
git config --global user.email "dev@localhost"
git config --global init.defaultBranch main

# ---------------------------------------------------------------------------
# 2. Command line tools. Checked individually, installed in one pass.
#    ripgrep and jq usually ship in the base image; fzf usually doesn't.
# ---------------------------------------------------------------------------
missing=()
command -v rg  >/dev/null 2>&1 || missing+=(ripgrep)
command -v fzf >/dev/null 2>&1 || missing+=(fzf)
command -v jq  >/dev/null 2>&1 || missing+=(jq)

if [ ${#missing[@]} -gt 0 ]; then
  echo "installing: ${missing[*]}"
  sudo apt-get update -qq
  sudo apt-get install -y "${missing[@]}"
fi

# ---------------------------------------------------------------------------
# 3. pnpm. 'corepack enable' writes a shim into a system folder so it needs
#    sudo; 'corepack prepare' must run as you so the download lands in your
#    own cache rather than root's.
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
# 4. Your personal Claude config.
#    The sandbox cannot see ~/.claude from your Mac, so anything you want at
#    user level has to be placed here.
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.claude"

for f in settings.json CLAUDE.md; do
  if [ -f "$PROVISION_DIR/claude/$f" ]; then
    cp "$PROVISION_DIR/claude/$f" "$HOME/.claude/$f"
    echo "installed ~/.claude/$f"
  fi
done

# ---------------------------------------------------------------------------
# 5. Claude plugins, from claude/plugins.txt.
#    Failures are reported but don't abort the rest: plugin installs need
#    network access and sometimes need you to be logged in first.
# ---------------------------------------------------------------------------
PLUGINS_FILE="$PROVISION_DIR/claude/plugins.txt"

if [ -f "$PLUGINS_FILE" ] && command -v claude >/dev/null 2>&1; then
  while read -r marketplace plugin || [ -n "${marketplace:-}" ]; do
    case "$marketplace" in ''|\#*) continue ;; esac
    [ -n "${plugin:-}" ] || continue

    echo "adding marketplace: $marketplace"
    claude plugin marketplace add "$marketplace" || echo "  (already added, or add failed)"

    echo "installing plugin: $plugin"
    claude plugin install "$plugin" || echo "  could not install $plugin, add it by hand with /plugin"
  done < "$PLUGINS_FILE"
fi

touch "$HOME/.setup-done"
echo
echo "Setup complete."