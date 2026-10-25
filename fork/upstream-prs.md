# Fixes offered to upstream

Our patches that `heygen-com/hyperframes` should carry. A PR there is sent only on the operator's explicit
instruction for that act; nothing below has been sent unless it says so.

`heygen-com/hyperframes` requires signed commits, and our local commits are authored `Робот <r@e.com>`, which no
GitHub account verifies. So a fix goes upstream as a branch made by [`signed-branch.py`](signed-branch.py): one commit
created through the GitHub API, which GitHub signs (`web-flow`) and attributes to the operator's account. Its files
match `main` byte for byte when it is made, so `main`'s tests and each release's `fork/release.sh` cover them.

## Waiting for the operator's send instruction

| Fix                                                                                | Signed branch                              | Built on upstream `main` |
| ---------------------------------------------------------------------------------- | ------------------------------------------ | ------------------------ |
| `fix(cli): speech works from a sandboxed run and says why kokoro-onnx cannot load` | `pr/tts-sandbox-safe-signed` (`5fdb537f8`) | `dd1cba49d` (2026-10-24) |
| `fix(cli): ignore the project folder's own FSEvents change; Node 26 test fixes`    | `pr/node26-macos-signed` (`5d6735d6b`)     | `dd1cba49d` (2026-10-24) |

Checked on 2026-10-25 against upstream `main` `0289d96ac` (22 commits past `v0.8.193`): upstream has changed none
of either branch's files since `dd1cba49d` (`git diff --stat dd1cba49d upstream/main -- <the branch's files>` prints
nothing), so both still apply as built.

To send one:

1. If upstream `main` moved since the branch was built, build it again on the current one under a new name, so
   the PR starts from a clean base: `git fetch upstream`, then
   `DRY=1 python3 -I fork/signed-branch.py <new-branch> "<headline>" <body-file> <diff-spec>...` (every file must say
   `matches main`), then the same without `DRY`. The speech fix is the diff of `118a29e52`; the Node 26 fix is
   `cca5e193c`, `a707fb95b` and `fb4cb29f2`. The body is the commit message's body.
2. `gh pr create -R heygen-com/hyperframes --head ssheleg:<branch> --fill`.
3. Watch its checks: CodeQL and the signed-commit rule must pass; `Studio and player captures` applies only to changes
   under `packages/studio` or `packages/player` (`scripts/check-pr-captures.mjs`).

## Done

- **#5790, running markers**: merged 2026-10-24 (merge `24965372d`), in `v0.8.193`; the line no longer carries it.
  Approved by a maintainer on condition of signed commits and a green CodeQL. CodeQL's finding (high, "Potential file
  system race condition", `runningCli.test.ts:75`: the test checked `existsSync(silent)` and then wrote the same path)
  was fixed in `d5959004e` by comparing the folder's listing. On the operator's word the PR's branch was moved from the
  unsigned `3878df714` to the signed `d6a3ff5b7` with `--force-with-lease`; `runningCli.ts` stayed byte-identical to the
  reviewed commit. The maintainer was told in
  https://github.com/heygen-com/hyperframes/pull/5790#issuecomment-6385121928 ; every check went green (53 pass, 15
  skipped) and it merged nine minutes later. Its branches were deleted on 2026-10-25.
