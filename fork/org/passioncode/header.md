# Working in PassionCode HyperFrames Agent

## Read first

1. The organization's
   [roadmap](https://github.com/passioncode-ai/fabric-workspace/blob/main/knowledge/roadmap.md):
   every major feature and release across PassionCode.ai as `RM-*` tracks with owner, phase and
   state. It is the entry point: a task here that serves a track names it, and the track's status
   is edited only in the roadmap.
2. The PassionCode.ai knowledge base, `fabric-workspace/knowledge/` in your clone (org-index
   `scripts/clone_all.sh` makes it) or https://wiki.passioncode.ai/knowledge: at least its
   [README](https://github.com/passioncode-ai/fabric-workspace/blob/main/knowledge/README.md),
   vision, principles and how-to-work.
3. This file, then the organization's
   [CONTRIBUTING.md](https://github.com/passioncode-ai/.github/blob/main/CONTRIBUTING.md).

## What this repository is

PassionCode HyperFrames Agent: the organization's copy of the HyperFrames Agent line, the HyperFrames render engine
(`heygen-com/hyperframes`, Apache-2.0) at one upstream release plus a few patches, released as tarballs that the
organization's Frame Agent pins. Read [`fork/README.md`](fork/README.md) before any change to versions or releases,
and [`fork/HANDOFF.md`](fork/HANDOFF.md) for the current state.

- This repository is an export. Each commit on `main` is the whole tree of the line at one upstream release, written
  by the line's export script; there is no upstream history here. A change made here directly is replaced by the next
  export: take it to the line's maintainers on the project board instead.
- No GitHub workflow runs here: upstream's workflows target HeyGen's infrastructure and are not exported.

## Commands

| What                                                                                                                  | Command                                                                                                      |
| --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Install                                                                                                               | `bun install`                                                                                                |
| Test (the gate)                                                                                                       | `fork/release.sh <n>`: build, the patches' tests, pack, smoke install                                        |
| Build                                                                                                                 | `bun run build`                                                                                              |
| Release                                                                                                               | `fork/release.sh <n> --publish`, tag `fork-v<base>-passioncode.<n>`, a tarball on GitHub Releases, never npm |
| Clean old builds ([LC-15](https://github.com/passioncode-ai/fabric-workspace/blob/main/knowledge/lifecycle.md#lc-15)) | `rm -rf fork/out` after a release is published; the release assets stay on GitHub                            |
| MCP (register + proving call)                                                                                         | none: the engine is a CLI (`hyperframes`); Frame Agent is its MCP surface                                    |

## Local rules

- The repository is an export of the line: change the line, not this copy (see [`fork/README.md`](fork/README.md)).
- The code is HeyGen's under Apache-2.0 and keeps that licence (knowledge base `licensing.md`, third-party code).

## Lifecycle

Ships no process. The `hyperframes` CLI it builds starts its own short-lived children (Chrome, ffmpeg) for the
command that runs them; Frame Agent decides when.

## Backlog ownership

Read [the common backlog contract](https://github.com/passioncode-ai/fabric-workspace/blob/main/knowledge/backlog.md). This copy declares its handoff as context in `docs/backlog-sources.json`; its tasks are the line's and live in the line.

## Report delivery

Follow the [shared report-delivery recommendation](https://github.com/passioncode-ai/fabric-workspace/blob/main/knowledge/how-to-work.md#delivering-reports-to-people).

## After work

In the same run: update this repository's docs with the change; if a cross-repository fact changed
(a product, a version, a plan row, a principle), update the page in `fabric-workspace/knowledge/`
that owns it; land both; publish (`node scripts/workspace.mjs sync` from a Fabric checkout) or
leave it to the scheduled sync. Leave a handoff with the exact next task.

## Upstream's instructions

The text below is upstream's own and applies to the engine's code.
