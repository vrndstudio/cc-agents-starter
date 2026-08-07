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

3. go to workspace dir and allow permissions? 

   ```bash
   sudo mkdir -p /opt/<your-workspace-dir>
   sudo chown "$(whoami)" /opt/<your-workspace-dir>
   ```

OR creating a new sandown with custom name from project folder:
```
SBX_NAME=<name> bash ./start.sh .
```

4. Mint a **fine-grained** GitHub token at
   Settings → Developer settings → Personal access tokens → Fine-grained.
   Scope it to only the repos Claude will touch, with Contents read/write,
   Pull requests read/write, Metadata read. Short expiry.
   <!-- here how should we setups the global github token vs. the sanbox-scoped one? -->

---

## Daily use

```bash
cd <provisioning-repo>
./start.sh <project>
```

Run it again on the same project and it reopens the same sandbox instead of
making a new one. Setup only runs the first time.

On the first run it offers to take the GitHub token from your clipboard, so
copy it before you start.

The first time you're inside Claude, type `/login` and pick **Claude account
with subscription**. That uses the Claude plan you already pay for, at no
extra cost.

Check the result any time:

```bash
./verify.sh <sandbox-name>
```

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

If you created a sandbox by hand and want this setup applied to it:

```bash
cd <provisioning-repo>
tar czf /tmp/provision.tgz setup.sh claude
sbx cp /tmp/provision.tgz <sandbox-name>:/tmp/provision.tgz
sbx exec -it <sandbox-name> bash -lc '
  mkdir -p /tmp/provision
  tar xzf /tmp/provision.tgz -C /tmp/provision
  bash /tmp/provision/setup.sh
'
rm /tmp/provision.tgz
```

Its existing project binding is untouched.

To have `start.sh` reuse a sandbox whose name doesn't match the project folder:

```bash
SBX_NAME=<sandbox-name> ./start.sh <project>
```

---

## Credentials

Tokens are scoped to a single sandbox. Scope is a positional argument, not a
flag:

```bash
pbpaste | sbx secret set <sandbox-name> github
```

Rotating an expiring token needs no rebuild:

```bash
sbx secret rm <sandbox-name> github
pbpaste | sbx secret set <sandbox-name> github
```

Restart the Claude session afterwards.

**Avoid global (`-g`) secrets.** They're injected into every sandbox at
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

- **Plugin strings need capturing, not guessing.** `claude/plugins.txt` ships
  with a placeholder entry. Run `claude plugin list` and
  `claude plugin marketplace list` on a machine where your plugins already
  work, and paste the exact strings in.
- **Never let the agent edit its own permissions file.** This repo is the
  source of truth for `~/.claude/settings.json`. If the agent rewrites it,
  re-run setup rather than accepting the diff.
- **Column parsing is a guess.** `start.sh` greps `sbx ls` and
  `sbx secret ls` output. Run both once and adjust the `awk`/`grep` if the
  layout differs on your version.
- **sbx is Early Access.** Commands and flags move. Check
  `sbx <command> --help` when something behaves unexpectedly.

## Sources

- [Docker Sandboxes docs](https://docs.docker.com/ai/sandboxes/)
- [sbx CLI reference](https://docs.docker.com/reference/cli/sbx/)
- [sbx security model](https://docs.docker.com/ai/sandboxes/security/)
- [Claude Code permissions](https://code.claude.com/docs/en/permissions)
- [Claude Code plugins](https://code.claude.com/docs/en/discover-plugins)