# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-21, evening)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the
  `ssheleg` organisation on 2026-10-19; GitHub redirects the old address, release downloads included).
- `main` = upstream `v0.8.184` (merge `66bfeedd2`; before it `v0.8.181` merge `2fb047c8a`, `v0.8.180` merge `8595a06f6`)
  - the running-markers sweep (`cbe3ca66a`) + `fork/`; `upstream` mirrors HeyGen's `main` (pushed to `0716670fa`).
- Latest release `fork-v0.8.184-sshlg.1` (sha256 `0787016464639fd9a0dd69d0ed5d11bb18e987230f789a48be315c3c971aa597`);
  checks run by `fork/release.sh`: the patch's 3 tests passed, the smoke install printed `0.8.184+sshlg.1` and swept a
  dead marker, the re-downloaded asset matched its sha256. Earlier releases (`0.8.181`, `0.8.180`, `0.8.174`, `0.8.170`)
  stay published.
- Door audit v0.8.181..v0.8.184 (for consumers that deny engine doors): no new CLI command. Since `v0.8.51` the CLI
  installs `onnxruntime-node` and `@google/genai` from npm on first use (and `sharp` since `v0.8.182`) into
  `~/.cache/hyperframes/optional` (`packages/cli/src/utils/optionalPackages.ts`); `v0.8.182` added
  `HYPERFRAMES_NO_OPTIONAL_INSTALL` (`1` turns every such install off). Other new env names belong to `aws-lambda`,
  tests, or `PRODUCER_HEADLESS_SHELL_PATH` (now also read by the CLI's browser manager); new child processes run `node`
  itself (capture's public-network DNS guard, the warm check).
- The private consumer that pins this line moved to `fork-v0.8.184-sshlg.1` on 2026-10-22 in its own repository, with the
  first-use installs pinned off (`HYPERFRAMES_NO_OPTIONAL_INSTALL=1`) and the skills re-vendored at `v0.8.184`; its gate
  passed and its release on that engine runs (`hyperframes --version` `0.8.184+sshlg.1`).
- The sixteen inherited workflows are disabled (repository settings).
- Upstream PR heygen-com/hyperframes#5790 (the same sweep) is open, no reviews; its head `3878df714` still merges
  cleanly onto upstream `main` (`git merge-tree`, 2026-10-20). We do not wait for it.

## Next task

1. Upstream releases after `v0.8.184`: run `git fetch upstream --tags`, read the new tags' commits and take the latest
   (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish`, run `fork/door-audit.sh v0.8.184 v<new>` and update this file. The
   pinning consumer moves its pin in its own repository (its handoff names the steps); post the audit's findings to it on
   the project board.

Before acting on this section, check it against Git: a tag it names as future may already exist.
