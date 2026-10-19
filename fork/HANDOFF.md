# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-19)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the
  `ssheleg` organisation on 2026-10-19; GitHub redirects the old address, release downloads included).
- `main` = upstream `v0.8.174` (merge `3146a2f73`) + the running-markers sweep (`cbe3ca66a`) + `fork/`; `upstream`
  mirrors HeyGen's `main`.
- Latest release `fork-v0.8.174-sshlg.1` (sha256 `7d53662e673cb3a63ce82239fe0c2804e9707d544386789553e67d89d16efafc`);
  the previous one, `fork-v0.8.170-sshlg.1`, stays published.
- Frame Agent's `main` pins `fork-v0.8.174-sshlg.1` (its BL-166).
- The sixteen inherited workflows are disabled (repository settings).
- Upstream PR heygen-com/hyperframes#5790 (the same sweep) is open; we do not wait for it.

## Next task

Read upstream `v0.8.175`..`v0.8.177` (16 commits after `v0.8.174`: whisper for non-English transcription, faster
`check`, graded video renders chunked within the worker limit, HLG reference white) and take `v0.8.177` (fork/README.md,
"Taking an upstream release"). Then `fork/release.sh 1 --publish` for `fork-v0.8.177-sshlg.1` and update this file.
Before acting on this section, check it against Git: a tag it names as future may already exist.
