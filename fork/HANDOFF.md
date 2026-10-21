# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-21)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the
  `ssheleg` organisation on 2026-10-19; GitHub redirects the old address, release downloads included).
- `main` = upstream `v0.8.181` (merge `2fb047c8a`, on top of `v0.8.180` merge `8595a06f6`) + the running-markers
  sweep (`cbe3ca66a`) + `fork/`; `upstream` mirrors HeyGen's `main` (pushed to `908f2d095`, 31 commits after
  `v0.8.180`).
- Latest release `fork-v0.8.181-sshlg.1` (sha256 `3a61ad3809dedf9b70e9b9150518b9bb4d9fee5596408c5c40921b6b1b6e34ab`);
  checks run by `fork/release.sh`: the patch's 3 tests passed, the smoke install printed `0.8.181+sshlg.1` and swept a
  dead marker, the re-downloaded asset matched its sha256. Earlier releases stay published.
- The private consumer that pins this line moved to `fork-v0.8.181-sshlg.1` on 2026-10-21 (through `0.8.180` the day
  before), with door audits v0.8.174..v0.8.181 in its own pull requests: no new CLI command; the one new variable
  (`HYPERFRAMES_LAMBDA_HANDLER_URL`) is read only by `lambda deploy`, which that consumer denies. Its vendored skills
  are at `v0.8.180`, equal to `v0.8.181`'s.
- The sixteen inherited workflows are disabled (repository settings).
- Upstream PR heygen-com/hyperframes#5790 (the same sweep) is open, no reviews; its head `3878df714` still merges
  cleanly onto upstream `main` (`git merge-tree`, 2026-10-20). We do not wait for it.

## Next task

1. Upstream releases after `v0.8.181`: run `git fetch upstream --tags`, read the new tags' commits and take the latest
   (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish` and update this file. The pinning
   consumer moves its pin in its own repository (its handoff names the steps); tell it on the project board.

Before acting on this section, check it against Git: a tag it names as future may already exist.
