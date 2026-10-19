# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-19)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the
  `ssheleg` organisation on 2026-10-19; GitHub redirects the old address, release downloads included).
- `main` = upstream `v0.8.170` + the running-markers sweep (`cbe3ca66a`) + `fork/`; `upstream` mirrors HeyGen's `main`.
- Latest release `fork-v0.8.170-sshlg.1` (sha256 `1ea79c72244907cf21375360a9570b9364cba105184320661b3f18d9dc6e67db`).
- The sixteen inherited workflows are disabled (repository settings).
- Upstream PR heygen-com/hyperframes#5790 (the same sweep) is open; we do not wait for it.

## Next task

Take upstream `v0.8.174` (fork/README.md, "Taking an upstream release"): it fixes `check` hanging and
`capture` failing inside a macOS agent sandbox (#5836, #5840), 29.97 fps export (#5849), colour tags (#5742)
and an unfinishable codec stopping before capture (#5831). Then `fork/release.sh 1 --publish` for
`fork-v0.8.174-sshlg.1`, and consumers move their pin after measuring the render against 0.8.170.
