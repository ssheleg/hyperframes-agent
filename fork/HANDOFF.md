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
- Consumers still pin `fork-v0.8.170-sshlg.1` on their default branches; each moves its pin after measuring the
  render against it.
- The sixteen inherited workflows are disabled (repository settings).
- Upstream PR heygen-com/hyperframes#5790 (the same sweep) is open; we do not wait for it.

## Next task

Read upstream `v0.8.175` (released after `v0.8.174`) and decide whether to take it (fork/README.md, "Taking an
upstream release"). If it is taken: `fork/release.sh 1 --publish` for `fork-v0.8.175-sshlg.1` and update this file.
Before acting on this section, check it against Git: a tag it names as future may already exist.
