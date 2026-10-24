# Fixes offered to upstream

Our patches that `heygen-com/hyperframes` should carry. A PR there is sent only on the operator's explicit
instruction for that act; everything below is ready to send and nothing here has been sent unless it says so.

`heygen-com/hyperframes` requires signed commits. Each branch below is one commit created through the GitHub API, so
GitHub signs it (`web-flow`, verified) and its author is the operator's account. Its files match `main` byte for byte
when it was made, so `main`'s tests and each release's `fork/release.sh` cover them.

| Fix                                                                                | Ready branch (signed commit)               | Upstream state                                    |
| ---------------------------------------------------------------------------------- | ------------------------------------------ | ------------------------------------------------- |
| `fix(cli): each start sweeps the running markers of CLIs that are gone`            | `pr/running-markers-signed` (`d6a3ff5b7`)  | #5790 open, approved 2026-10-24, waits on 2 items |
| `fix(cli): speech works from a sandboxed run and says why kokoro-onnx cannot load` | `pr/tts-sandbox-safe-signed` (`5fdb537f8`) | not sent                                          |
| `fix(cli): ignore the project folder's own FSEvents change; Node 26 test fixes`    | `pr/node26-macos-signed` (`5d6735d6b`)     | not sent                                          |

The unsigned predecessors (`fix/cli-running-markers-prune`, `pr/tts-sandbox-safe`, `pr/node26-macos`) carry commits
authored `Робот <r@e.com>`, which no GitHub account verifies; do not send them.

## #5790: running markers

Approved on 2026-10-24 by a maintainer, who queues it once two checks are green: every commit signed, and CodeQL. The
third item they named, `Studio and player captures`, already passes: it applies only to changes under
`packages/studio` or `packages/player` (`scripts/check-pr-captures.mjs`, `WATCHED_PREFIXES`).

- CodeQL (high, "Potential file system race condition", `runningCli.test.ts:75`): the test checked `existsSync(silent)`
  and then wrote the same path. Fixed in `d5959004e` on `main` and in the signed branch: the test compares the folder's
  listing instead.
- Signing: the PR's head `3878df714` is unsigned. Its branch can only be given the signed commit by a force push, which
  our rules forbid without the operator's word. Two routes, the operator chooses:
  1. Recommended (keeps the approval and the thread): the operator allows one force update of the PR branch.
     `git push origin +d6a3ff5b7db3ac46fe0fc19ee561072602878b62:refs/heads/fix/cli-running-markers-prune`, then a comment
     on #5790: "Pushed d6a3ff5: one commit, signed, with the CodeQL finding fixed (the test reads the running folder's
     listing instead of checking each path before writing it). No other code change."
  2. Without a force push: a new PR from the signed branch, and #5790 closed with a link to it.
     `gh pr create -R heygen-com/hyperframes --head ssheleg:pr/running-markers-signed --title "fix(cli): each start sweeps the running markers of CLIs that are gone" --body-file <#5790's body with the Verification section updated>`

## The other two

Send each with `gh pr create -R heygen-com/hyperframes --head ssheleg:<branch> --fill` (the commit message is the PR
body), then check that CodeQL and the signed-commit rule pass.
