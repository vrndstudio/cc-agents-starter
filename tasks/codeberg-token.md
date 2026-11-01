# Codeberg access token in start.sh

Status: open. Next step: run the host tests below and paste the output.

## Question

ok now my tested sbx start and verify scripts are working as intended. now let's plan the scenario that my repo lived on codeberg, i need a codeberg acess token. tell me how we need to do it and add to our start script to include a personal access token in the similar mechanism as github

## Answer

`sbx` has no built-in `codeberg` service, so this uses `sbx secret set-custom` (from the Docker Sandboxes docs). It works differently from the `github` secret, and one step needs testing on a real sandbox before I add it to `start.sh`.

**How custom secrets work**
- The sandbox gets an env var such as `CODEBERG_TOKEN` holding a placeholder like `sbx-cs-<rand>`.
- The proxy swaps the placeholder for the real token only where it appears **literally in an HTTP header** going to `codeberg.org`.
- Normal `git` HTTPS auth base64-encodes `user:token`, which hides the placeholder from the proxy. So the usual credential helper won't work.
- The fix is to have git send the placeholder in a raw header:
  ```bash
  git config --global http.https://codeberg.org/.extraHeader "Authorization: token $CODEBERG_TOKEN"
  ```
  I'm not sure Forgejo accepts `Authorization: token …` for `git push`. It does for its API.

**Token, at codeberg.org → Settings → Applications**
- Scopes: `repository` read and write, `issue` read and write (Forgejo files pull requests under issues), `user` read.
- Forgejo may not limit a token to specific repos the way GitHub fine-grained tokens do. Check what the UI offers.
- Set a 90-day expiry, same reasoning as for GitHub.
- `gh` won't work with Codeberg. The CLI for Forgejo is `tea`, which could be installed in `setup.sh`.
- The sandbox network policy needs `codeberg.org` allowed.

**Test first, in a throwaway sandbox, on your Mac**
```bash
sbx secret set-custom --help        # does it read the value from stdin? what's the name flag?
sbx secret set-custom --sandbox <name> --host codeberg.org --env CODEBERG_TOKEN   # plus the value flag --help shows
sbx secret ls                       # how the custom secret row looks
sbx exec -it <name> bash -lc 'echo $CODEBERG_TOKEN; git -c http.https://codeberg.org/.extraHeader="Authorization: token $CODEBERG_TOKEN" ls-remote https://codeberg.org/<you>/<private-repo> HEAD'
```
Paste the output. It tells me whether the header works, whether the placeholder reaches an already-running sandbox, and which columns to parse.

**Then in `start.sh`:** read the project's `origin` remote. If it's `codeberg.org`, ask for the Codeberg token and set the custom secret instead of `github`. `setup.sh` would add the `extraHeader` and install `tea`.

Should `start.sh` detect Codeberg from the `origin` remote, or do you want an explicit `FORGE=codeberg ./start.sh` flag?
