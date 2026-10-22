# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-22)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the
  `ssheleg` organisation on 2026-10-19; GitHub redirects the old address, release downloads included).
- `main` = upstream `v0.8.185` (merge `b0bd45480`; before it `v0.8.184` merge `66bfeedd2`, `v0.8.181` merge `2fb047c8a`,
  `v0.8.180` merge `8595a06f6`) + the running-markers sweep (`cbe3ca66a`) + `fork/`; `upstream` mirrors HeyGen's `main`.
- Latest release `fork-v0.8.185-sshlg.1` (sha256 `9ac5379a40900436d8ef19525086ee6b16f583a58185e32282fd07591f747be5`);
  checks run by `fork/release.sh`: the patch's 3 tests passed, the smoke install printed `0.8.185+sshlg.1` and swept a
  dead marker, the re-downloaded asset matched its sha256. Earlier releases stay published.
- `fork/door-audit.sh v0.8.184 v0.8.185`: no new CLI command (`snapshotReview.ts` serves `snapshot`), no new environment
  variable, child process or run-time install. **`v0.8.185` retires the workflow skills** (upstream #5651): `skills/` goes
  from 21 to 7 (`hyperframes`, `hyperframes-cli`, `hyperframes-registry`, `media-use`, `figma`, `slideshow`,
  `remotion-to-hyperframes`), the domain skills become guides under `hyperframes/` and `media-use/`, and
  `skills update` removes the retired ones. A consumer that vendors workflow skills keeps an older tag's copy until it
  redesigns; the engine itself reads none of them.
- Door audit v0.8.181..v0.8.184: the CLI installs `onnxruntime-node` and `@google/genai` from npm on first use since
  `v0.8.51` and `sharp` since `v0.8.182`; `HYPERFRAMES_NO_OPTIONAL_INSTALL=1` (since `v0.8.182`) turns that off.
- The private consumer that pins this line moves to each release in its own repository; its move to `0.8.185` (with
  its skills kept at `v0.8.184`) is in progress there.
- The sixteen inherited workflows are disabled (repository settings).
- Upstream PR heygen-com/hyperframes#5790 (the same sweep) is open, no reviews; its head `3878df714` still merges
  cleanly onto upstream `main` (`git merge-tree`, 2026-10-20). We do not wait for it.

## Next task

1. Upstream releases after `v0.8.185`: run `git fetch upstream --tags`, read the new tags' commits and take the latest
   (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish`, run `fork/door-audit.sh v0.8.185 v<new>` and update this file. The
   pinning consumer moves its pin in its own repository (its handoff names the steps); post the audit's findings to it on
   the project board.

Before acting on this section, check it against Git: a tag it names as future may already exist.
