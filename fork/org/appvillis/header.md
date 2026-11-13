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
- North Star (PassionCode's organization model; the operator's rule, 2026-11-13): this line serves section 5 (service
  agents: the media engine a video agent calls, its source apart from each instance), section 10 (deployment: installed
  from a release tarball, rebuilt from a tag), section 11 (security and isolation: one copy per organization, a door audit
  for a consumer that confines the engine) and section 12 (an organization at work: the row "Content: media"). A release,
  or a gap closed or opened against them, is reported on the project board with its evidence. Before an agent built on
  this engine changes, the agents database's architect is consulted, and each release is audited by it.
