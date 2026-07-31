# Claude Code sandbox

A small set of files that opens a Claude Code sandbox. You run one command and it's ready.

## What's here

- `start.sh` — opens the space for a project and drops you into Claude. Run this.
- `setup.sh` — gets the space ready the first time. It runs on its own; you
  don't call it directly.
- `templates/` — a starter notes file and settings file to copy into a project.

## Before the first time (one-off)

1. Install the sandbox tool and sign in with your Docker account.
2. If you want Claude to work with GitHub, save a token once:

   ```bash
   echo "$(gh auth token)" | sbx secret set -g github
   ```

   Keep this token narrow: give it access to only the repositories you want
   Claude to touch, and only the actions it needs. That way, even in the rare
   case something goes wrong, the damage is limited.
   
## How to use it

```bash
./start.sh /opt/sbx/my-project
```

Run it again later with the same folder and it reopens the same space instead of
making a new one.

## How Claude signs in

You have two ways, and the first is usually best.

1. **Use your Claude plan (recommended).** This uses the Claude subscription you
   already pay for, at no extra cost. The first time the space opens, type
   `/login` inside Claude, choose "Claude account with subscription", copy the
   web address it shows into your browser, sign in with your normal Claude
   account, and paste the code back. You only do this once per space.

2. **Pay as you go.** If you'd rather pay per use from a separate billing
   account, save a key before you start:

   ```bash
   echo "$YOUR_KEY" | sbx secret set -g anthropic
   ```

   Pick only one. If you save a pay-as-you-go key, Claude uses that and skips
   your plan.

## Telling Claude about your project

Copy the starter files from `templates/` into your project:

- `CLAUDE.md` in the project folder — notes Claude reads every time.
- `settings.json` into a `.claude` folder in the project, if you want to add
  settings later.

## Working on code you don't fully trust

By default the space can change the files in your project folder. For code you
don't trust, open it in a stricter mode where the space can only read your
files and Claude works on a private copy instead:

```bash
sbx create --clone --name my-project claude /opt/sbx/my-project
sbx run --name my-project
```

For this kind of work, use a read-only GitHub token, or none at all.

## What it can reach online

The space starts locked down and can reach the usual coding sites. If a setup
step fails because it couldn't reach a site, see which one and allow it:

```bash
sbx policy log my-project
sbx policy allow network archive.ubuntu.com
```

## Good to know

- The space keeps whatever you install until you delete it, so the one-time
  setup only runs once.
- Your everyday shell settings and your personal Claude settings from your Mac
  don't carry into the space. Anything you want in there lives in the project's
  own files (like `CLAUDE.md`), which come along automatically.
