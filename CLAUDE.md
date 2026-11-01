## Context

Provisioning scripts for Claude Code in Docker Sandboxes (`sbx`). Goal: smooth workflow, tight
security. See @README.md.

## Sandbox blocks

Don't try to work around a sandbox block. Read the 403 body once, then ask the user to run on
the host:

- network: `sbx policy log <sandbox-name>`, then `sbx policy allow network <domain>`
- Claude Code permissions: user edits `claude/settings.json` (source of truth) or uses `/sandbox`

## Communication & documentation style

Telegraphic prose. Drop articles, filler, pleasantries, hedging. Keep technical details exact
(code, error strings, symbols).

Lead with the answer. State uncertainty once, in 5 words or fewer. Bullets over prose.
Hard cap: 5 lines unless asked to expand.

## Development workflow

`sbx` only exists on the host, not inside the sandbox.

**Human runs:** `start.sh`, `verify.sh`, any `sbx` command; edits to config and settings files.

**Claude runs:** `bash -n *.sh`, `shellcheck *.sh`, `shfmt -d -i 2 *.sh`.

## Open

- update setup with `tasks/provisioning-changes.md` and `tasks/sandbox-and-network.md`
- [later] install bun in `setup.sh`
- [later] Codeberg token support in `start.sh`: see `tasks/codeberg-token.md`
