# Claude Code sandbox provisioning

Scripts that create a VM for Claude Code to work in, set it up the same way every time, and drop you into a session.

Built for [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`).

---

## The mental model

Three separate things. Getting these straight makes everything else obvious.

| | What it is | How many |
|---|---|---|
| `<provisioning-repo>` | This repo. Scripts and config. | One, shared by all projects |
| `<project>` | A codebase you work on | Many |
| `<sandbox-name>` | The VM Claude runs in | One per project |

**A sandbox is bound to one project folder.** That binding is made once, by
`sbx create`, and never changes.

**Every other `sbx` command finds the sandbox by name, not by folder.** So
`sbx cp`, `sbx exec`, `sbx run` and `sbx secret set` all work from any
directory on your Mac. Your current directory is irrelevant to them.

Running `./start.sh <project>` from inside `<provisioning-repo>`
does not make the sandbox work on the provisioning repo. The script reads its
own location only to find `setup.sh` and `claude/` to copy in. 

**This repo is never mounted into a sandbox.** Its files are copied in once,
to `/tmp`, and run. Only `<project>` is mounted, and it's mounted live: edits
on either side appear on the other immediately.

---

## What's here

```
<provisioning-repo>/
├── start.sh          create or reopen a sandbox for a project, then attach
├── setup.sh          runs inside the sandbox, once (start.sh calls it)
├── verify.sh         check what actually got installed
└── claude/
    ├── settings.json   copied to ~/.claude/settings.json in the sandbox
    ├── CLAUDE.md       copied to ~/.claude/CLAUDE.md in the sandbox
    └── plugins.txt     plugins to install
```

---

## First time setup

1. Install `sbx` and sign in:

   ```bash
   sbx login
   ```

2. Clone this repo somewhere **outside** any project folder:

   ```bash
   git clone <this-repo> <provisioning-repo>
   chmod +x <provisioning-repo>/*.sh
   ```


4. Mint a **fine-grained** GitHub token at
   Settings → Developer settings → Personal access tokens → Fine-grained.
   Scope it to only the repos Claude will touch, with Contents read/write,
   Pull requests read/write, Metadata read. Short expiry. Set it per sandbox,
   not globally: see [Credentials](#credentials).

---

## Daily use

Provision a new sandbox, or reopen an existing one, then check it:

```bash
cd <provisioning-repo>
bash ./start.sh <project>                             # name = project folder name
SBX_NAME=<sandbox-name> ./start.sh <project>          # or pick the name yourself
bash ./verify.sh <sandbox-name>
```

- `<project>`: path to the project folder, e.g. `/opt/<workspace-dir>/my-app`
  or `.` for the current folder.
- `<sandbox-name>`: what `sbx ls` shows. Defaults to the project folder name.

Run it again on the same project and it reopens the same sandbox instead of
making a new one. Setup only runs the first time.

On the first run it offers to take the GitHub token from your clipboard, so
copy it before you start.

The first time you're inside Claude, type `/login` and pick **Claude account
with subscription**. That uses the Claude plan you already pay for, at no
extra cost.

Inside a session, `/sbxstat` prints a quick isolation check (user, home,
`~/.ssh`, `/Users`).

---

## Network blocks

Outbound traffic is default-deny. A blocked request returns HTTP 403 with the
reason in the body. To see and allow, on your Mac:

```bash
sbx policy log <sandbox-name>               # what got blocked, and why
sbx policy allow network <domain>[,<domain>]
sbx policy ls                               # active rules
```

If the reason says `corporate policy` or `system policy`, `sbx policy allow`
won't help; that block is set above you.

MCP servers connect at session start, so after allowing a domain, reconnect
with `/mcp` or restart the session. Prefer claude.ai connectors (e.g. Context7)
over plugin MCP servers that need their own domains allowed.

---

## Working alongside it in VS Code

The project folder is shared live, so open it in VS Code on your Mac as
normal. No remote extension needed.

Add these terminal profiles to your **user** settings to get the sandbox one
click away in the terminal dropdown. `${workspaceFolderBasename}` resolves to
the sandbox name, so one profile works for every project:

```json
{
  "terminal.integrated.profiles.osx": {
    "sandbox shell": {
      "path": "sbx",
      "args": ["exec", "-it", "${workspaceFolderBasename}", "bash"],
      "icon": "vm"
    },
    "claude (sandbox)": {
      "path": "sbx",
      "args": ["run", "--name", "${workspaceFolderBasename}"],
      "icon": "hubot"
    }
  }
}
```

**Don't** install the Claude Code VS Code extension and assume you're still
sandboxed. That runs Claude as a host process with your full user session,
which is exactly what this setup prevents.

---

## Provisioning a sandbox you already made

If you created a sandbox by hand and want this setup applied to it, point
`start.sh` at it by name:

```bash
cd <provisioning-repo>
SBX_NAME=<sandbox-name> ./start.sh <project>
```

The sandbox exists, so `sbx create` is skipped and its project binding is
untouched. Setup runs if it hasn't run there before, then you're attached.

---

## Credentials

Tokens are scoped to a single sandbox with `--sandbox`. The sandbox must
exist first:

```bash
pbpaste | sbx secret set github --sandbox <sandbox-name>
sbx secret ls                                  # confirm the scope column
```

Rotating an expiring token needs no rebuild:

```bash
sbx secret rm github --sandbox <sandbox-name>
pbpaste | sbx secret set github --sandbox <sandbox-name>
```

Restart the Claude session afterwards. If it still sees the old value,
`sbx stop <sandbox-name>` then `sbx run --name <sandbox-name>`.

Older `sbx` versions used the positional form `sbx secret set <sandbox-name>
github`. Check `sbx secret set --help` if the flag errors.

**Avoid global secrets.** Bare `sbx secret set github`, without
`--sandbox`, is global. Global secrets are injected into every sandbox at
creation, including throwaways for untrusted repos. The credential proxy hides
a token's value from the agent but not its capability, so one global token
means any compromised sandbox can act as you on every repo it covers.

Global secrets also only inject at creation, so rotating one means destroying
and recreating the sandbox. Scoped secrets can be replaced on a running one.

---

## Untrusted code

Default (direct) mode shares your project folder read-write. For repos you
don't trust, use clone mode: your files become read-only to the sandbox and
Claude works on a private copy, which it exposes back as a git remote.

```bash
sbx create --clone --name <sandbox-name> claude <project>
sbx run --name <sandbox-name>
```

Give that sandbox a read-only token, or none.

Clone mode stops the sandbox **writing** to your files. It doesn't stop it
**reading** them, so keep `.env` files and keys out of the project tree either
way.

---

## Security notes

What the sandbox does and doesn't protect:

- **Contained:** the rest of your Mac. Only the project folder crosses the
  boundary. Your home directory, SSH keys and other projects aren't visible.
  Run `./verify.sh <sandbox-name>` to confirm this yourself rather than taking
  it on trust.
- **Contained:** raw token values. Credentials are injected by a host-side
  proxy, so the agent can make authenticated calls but can't read the token.
- **Contained:** inbound network. Nothing reaches a service inside unless you
  publish a port.
- **Not contained:** the project folder itself. A `.env` in the repo is fully
  readable by the agent.
- **Not contained:** token capability. The agent can use a token within its
  scope. Least privilege and short expiry are what bound this.
- **Not absolute:** the VM boundary is a hypervisor, stronger than a container
  but still software. Keep `sbx` updated.

Watch what a sandbox reaches for while it runs:

```bash
sbx           # dashboard; Tab switches to the live network panel
sbx policy log <sandbox-name>
```

---

## Housekeeping

```bash
sbx ls                      # what exists
sbx stop <sandbox-name>     # pause; state and secrets survive
sbx rm  <sandbox-name>      # destroy; setup.sh rebuilds it in a minute
```

Installed packages and plugins live and die with the sandbox. That's fine, and
intentional: this repo is the source of truth, not anything inside the VM. For
projects that stall, stop the sandbox; when you pick the work back up, prefer
rebuilding over nursing a months-old VM with a stale token in it.

---

## Notes and caveats

- **Plugin strings need capturing, not guessing.** Each line of
  `claude/plugins.txt` is `<marketplace-repo>  <plugin-name>@<marketplace-name>`.
  Get the exact strings from `claude plugin marketplace list` and
  `claude plugin list` on a machine where the plugins already work.
- **Never let the agent edit its own permissions file.** This repo is the
  source of truth for `~/.claude/settings.json`. If the agent rewrites it,
  re-run setup rather than accepting the diff.
- **Column parsing is version-dependent.** `start.sh` parses `sbx ls`
  (name in column 1) and `sbx secret ls` (`SCOPE TYPE NAME SECRET`). If either
  layout changes, adjust the `awk` in `start.sh`.
- **sbx is Early Access.** Commands and flags move. Check
  `sbx <command> --help` when something behaves unexpectedly.

## Sources

- [Docker Sandboxes docs](https://docs.docker.com/ai/sandboxes/)
- [sbx CLI reference](https://docs.docker.com/reference/cli/sbx/)
- [sbx security model](https://docs.docker.com/ai/sandboxes/security/)
- [Claude Code permissions](https://code.claude.com/docs/en/permissions)
- [Claude Code plugins](https://code.claude.com/docs/en/discover-plugins)