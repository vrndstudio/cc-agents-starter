#!/usr/bin/env bash
# setup.sh — runs once inside the space to get it ready.
# You don't run this yourself; start.sh runs it for you.
set -euo pipefail

# The name attached to any changes Claude saves. Kept generic on purpose,
# so your real name and email don't end up in the project's history.
git config --global user.name  "dev"
git config --global user.email "dev@localhost"
git config --global init.defaultBranch main

# A few handy search tools, if they aren't already here.
if ! command -v rg >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y ripgrep fzf jq
fi

# Turn on pnpm. corepack writes its shim into a system folder, so it needs sudo.
if ! command -v pnpm >/dev/null 2>&1; then
  if command -v corepack >/dev/null 2>&1; then
    sudo corepack enable
    corepack prepare pnpm@latest --activate
  else
    sudo npm install -g pnpm
  fi
fi

touch "$HOME/.setup-done"
echo "All set."
