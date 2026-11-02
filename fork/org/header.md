# HyperFrames Agent (this repository)

This is `appvillis-com/hyperframes-agent`, the team's copy of the HyperFrames Agent line: the HyperFrames engine
(`heygen-com/hyperframes`, Apache-2.0) at one upstream release plus a few patches. Read
[`fork/README.md`](fork/README.md) before any change to versions or releases, and [`fork/HANDOFF.md`](fork/HANDOFF.md)
for the current state.

- This repository is an export. Each commit on `main` is the whole tree of the line at one upstream release, written
  by the line's export script; there is no upstream history here. A change made here directly is replaced by the next
  export: take it to the line's maintainers instead.
- Releases: `fork/release.sh <n> [--publish]`, tag `fork-v<base>-appvillis.<n>`, a tarball on this repository's GitHub
  Releases, never npm.
- No GitHub workflow runs here: upstream's workflows target HeyGen's infrastructure and are not exported.
