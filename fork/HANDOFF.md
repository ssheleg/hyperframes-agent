# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-20)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the
  `ssheleg` organisation on 2026-10-19; GitHub redirects the old address, release downloads included).
- `main` = upstream `v0.8.180` (merge `8595a06f6`) + the running-markers sweep (`cbe3ca66a`) + `fork/`; `upstream`
  mirrors HeyGen's `main` (pushed to `c77061e3a`, three commits after `v0.8.180`).
- Latest release `fork-v0.8.180-sshlg.1` (sha256 `72d5b034513b0a41c160aeca57f796f9929c2dd8b9a615282bf439dbcd8103e4`);
  checks run by `fork/release.sh`: the patch's 3 tests passed, the smoke install printed `0.8.180+sshlg.1` and swept a
  dead marker, the re-downloaded asset matched its sha256. `fork-v0.8.174-sshlg.1` and `fork-v0.8.170-sshlg.1` stay
  published.
- Frame Agent's `main` still pins `fork-v0.8.174-sshlg.1` (its BL-166). The request to move it to
  `fork-v0.8.180-sshlg.1` waits for the Fabric board: on 2026-10-20 Fabric was running but its hub was not published
  (lifecycle broker reason `hub_not_published`), so `com.submit` could not be sent. Later that day the hub answered,
  but neither `hyperframes-agent` nor `frame-agent` is a Project in Fabric's directory (34 Projects, read from the
  `fabric-workspace` session); adding a folder as a Project is the person's step in Fabric (+ Project, Open a project).
- The sixteen inherited workflows are disabled (repository settings).
- Upstream PR heygen-com/hyperframes#5790 (the same sweep) is open, no reviews; its head `3878df714` still merges
  cleanly onto upstream `main` (`git merge-tree`, 2026-10-20). We do not wait for it.
- Cleaned on 2026-10-20: the stale `bot/catalog-publish` branch (left by the disabled catalog workflow at
  `v0.8.168`) was deleted from `origin`.

## Next task

1. When `frame-agent` is a Project on the Fabric board (`com.directory`), submit to it: move its pin to
   `fork-v0.8.180-sshlg.1` (URL and sha256 above).
2. Upstream releases after `v0.8.180`: run `git fetch upstream --tags`, read the new tags' commits and take the latest
   (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish` and update this file.

Before acting on this section, check it against Git: a tag it names as future may already exist.
