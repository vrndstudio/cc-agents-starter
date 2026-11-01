---
allowed-tools: Bash(uname:*), Bash(whoami:*), Bash(ls:*), Bash(pwd:*)
description: Check docker sandbox
---

Sandbox check output:

- OS: !`uname -s`
- User: !`whoami`
- Working dir: !`pwd`
- Home: !`ls -a ~`
- SSH keys (should fail): !`ls ~/.ssh 2>&1`
- /Users (only the mounted project path expected): !`ls /Users 2>&1`

Report the output above as-is. No commentary unless something looks wrong.
