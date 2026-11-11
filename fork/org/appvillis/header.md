# Appvillis HyperFrames Agent (this repository)

This is `appvillis-com/appvillis-hyperframes-agent`, the team's copy of the HyperFrames Agent line: the HyperFrames engine
(`heygen-com/hyperframes`, Apache-2.0) at one upstream release plus a few patches. Read
[`fork/README.md`](fork/README.md) before any change to versions or releases, and [`fork/HANDOFF.md`](fork/HANDOFF.md)
for the current state.

- This repository is an export. Each commit on `main` is the whole tree of the line at one upstream release, written
  by the line's export script; there is no upstream history here. A change made here directly is replaced by the next
  export: take it to the line's maintainers instead.
- Releases: `fork/release.sh <n> [--publish]`, tag `fork-v<base>-appvillis.<n>`, a tarball on this repository's GitHub
  Releases, never npm.
- No GitHub workflow runs here: upstream's workflows target HeyGen's infrastructure and are not exported.
- Add, never replace (the operator's rule, 2026-11-11): what went out is never changed or deleted. A shipped
  composition recipe (`fork/recipes/`) and a published release asset stay as they are; a change ships beside them
  under a new name or release number, and a recipe taken out of use is marked retired with its date and reason in
  `fork/shipped.lock.json` (`fork/check-add-only.mjs`, run by `fork/release.sh`). Take only an improvement with its
  proof, recorded with its reason by the line's maintainers.
