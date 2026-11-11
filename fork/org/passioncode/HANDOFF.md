# HANDOFF: PassionCode HyperFrames Agent, the organization copy

## State (@DATE@)

- `main` is the HyperFrames Agent line at upstream `@BASE@` with its patches, exported on @DATE@ (see
  [`line.env`](line.env) and [`README.md`](README.md)).
- Releases are on this repository's GitHub Releases; the first release of a base is `fork-v<base>-passioncode.1`.

## Patches on top of @BASE@

@PATCHES@

## Next task

When a new export lands on `main`, release it: `fork/release.sh 1 --publish` (a base already released takes the next
number), then tell the consumers on the project board which tag to pin.
