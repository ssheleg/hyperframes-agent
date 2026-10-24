# Fixes offered to upstream

Our patches that `heygen-com/hyperframes` should carry. A PR there is sent only on the operator's explicit
instruction for that act; everything below is ready to send and nothing here has been sent unless it says so.

`heygen-com/hyperframes` requires signed commits. Each branch below is one commit created through the GitHub API, so
GitHub signs it (`web-flow`, verified) and its author is the operator's account. Its files match `main` byte for byte
when it was made, so `main`'s tests and each release's `fork/release.sh` cover them.

| Fix                                                                                | Ready branch (signed commit)               | Upstream state                            |
| ---------------------------------------------------------------------------------- | ------------------------------------------ | ----------------------------------------- |
| `fix(cli): each start sweeps the running markers of CLIs that are gone`            | `pr/running-markers-signed` (`d6a3ff5b7`)  | #5790 head replaced 2026-10-24, see below |
| `fix(cli): speech works from a sandboxed run and says why kokoro-onnx cannot load` | `pr/tts-sandbox-safe-signed` (`5fdb537f8`) | not sent                                  |
| `fix(cli): ignore the project folder's own FSEvents change; Node 26 test fixes`    | `pr/node26-macos-signed` (`5d6735d6b`)     | not sent                                  |

The unsigned predecessors (`pr/tts-sandbox-safe`, `pr/node26-macos`, and `3878df714` that #5790 carried before) carry commits
authored `Робот <r@e.com>`, which no GitHub account verifies; do not send them.

## #5790: running markers

Approved on 2026-10-24 by a maintainer, who queues it once two checks are green: every commit signed, and CodeQL. The
third item they named, `Studio and player captures`, already passes: it applies only to changes under
`packages/studio` or `packages/player` (`scripts/check-pr-captures.mjs`, `WATCHED_PREFIXES`).

- CodeQL (high, "Potential file system race condition", `runningCli.test.ts:75`): the test checked `existsSync(silent)`
  and then wrote the same path. Fixed in `d5959004e` on `main` and in the signed branch: the test compares the folder's
  listing instead.
- Signing: done 2026-10-24 on the operator's word ("давай дальше форс пуш"). `fix/cli-running-markers-prune` was moved
  from `3878df714` to the signed `d6a3ff5b7` with `--force-with-lease` against that exact head; the PR now has one
  commit. `runningCli.ts` is byte-identical to the reviewed `3878df714`. The maintainer was told in
  https://github.com/heygen-com/hyperframes/pull/5790#issuecomment-6385121928 . At 2026-10-24 15:22 UTC every check on
  `d6a3ff5b7` was green (53 pass, 15 skipped, CodeQL included) and the PR read `CLEAN`, `APPROVED`. Nothing more is owed
  from our side; the maintainer queues it.

## The other two

Send each with `gh pr create -R heygen-com/hyperframes --head ssheleg:<branch> --fill` (the commit message is the PR
body), then check that CodeQL and the signed-commit rule pass.
