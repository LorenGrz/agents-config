# PR screenshots (before/after)

Read when: a PR changes something visible on screen and needs before/after screenshots.

GitHub has no API to upload images: drag-and-drop goes to `user-attachments`, which only the web
UI can reach (not `gh`, not the connector). The scripts in this skill's `scripts/` do it with Playwright;
run them from that directory (first time: `pnpm run setup`).

1. Run both versions of the app: base in a worktree (`git worktree add ../<repo>-base origin/<base>`)
   on another port, branch on the usual one.
2. Capture: `node pr-screenshots.mjs --before http://localhost:<base-port> --after http://localhost:<port>
   --path /<route> [--path ...] --out <scratchpad>/shots [--viewport 1440x900 --viewport 390x844]
   [--setup login.mjs] [--steps scenario.mjs]`.
   If the app needs login, once: `node pr-screenshots.mjs --login --url <login-url>` (the user logs in
   by hand), or a `--setup` module that logs in by API once per side. `--steps` reproduces the
   scenario (clicks, forms) the same way on both sides. Shots run in parallel (`--concurrency 4`); a
   step that throws or exceeds `--step-timeout` (20 s) is still captured and reported as `error` in
   the JSON, so fix that scenario instead of rerunning everything.
3. Upload: `node gh-upload-images.mjs --repo <owner/name> --pr <n> <shots>/*.png` prints the URL and
   markdown per file; nothing is posted. It sends all files in one batch and falls back to one by one.
   First time: `node gh-upload-images.mjs --login` (the user logs in to GitHub by hand, 2FA included).
   URLs inherit the repo's visibility.
4. Put the images in the PR body's screenshots section as a before/after table, via `gh pr edit
   --body-file`.

If a script fails on GitHub's markup, fix `SELECTORES` in `gh-upload-images.mjs` instead of falling back
to asking the user to drag the files.
