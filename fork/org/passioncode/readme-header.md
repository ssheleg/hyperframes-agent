# PassionCode HyperFrames Agent

PassionCode HyperFrames Agent is the organization's copy of the HyperFrames Agent line: the HyperFrames render engine
(`heygen-com/hyperframes`, HTML in, video out) at one upstream release plus a few patches. The organization's Frame
Agent installs it from this repository's releases; the CLI is still `hyperframes`. Versions, releases and how the copy
is refreshed: [`fork/README.md`](fork/README.md); state: [`fork/HANDOFF.md`](fork/HANDOFF.md). Attribution:
[`NOTICE`](NOTICE).

## Quick start for a new teammate

**Install.** The repository is private: download a release with an authenticated `gh` and install the file.

```sh
gh release download fork-v<base>-passioncode.<n> --repo passioncode-ai/passioncode-hyperframes-agent --pattern 'hyperframes-*.tgz'
npm install ./hyperframes-<base>-passioncode.<n>.tgz
npx hyperframes --version   # prints <base>+passioncode.<n>
```

**Configure.** Nothing is required to render locally. Optional keys, by name only: `HEYGEN_API_KEY` or
`HYPERFRAMES_API_KEY` for HeyGen's paid media and sharing; `HYPERFRAMES_NO_TELEMETRY=1` turns telemetry off and
`HYPERFRAMES_NO_OPTIONAL_INSTALL=1` stops installs from npm on first use.

**MCP.** The engine has no MCP server of its own; the organization's Frame Agent is its MCP surface and pins a
release of this repository.

**Develop.** `bun install`, `bun run build`, then `fork/release.sh 1` builds, runs the patches' tests, packs and
smoke-installs the tarball (Bun and Node needed). Change the engine in the HyperFrames Agent line, not here: the next
export replaces a change made in this copy.

## License

The engine is HeyGen's HyperFrames under the [Apache License 2.0](LICENSE), and this copy keeps that licence: it is
third-party code, which keeps its own licence and notice under the organization's licensing rule
([knowledge base, licensing](https://github.com/passioncode-ai/fabric-workspace/blob/main/knowledge/licensing.md)).
The organization's AGPL-3.0 and commercial terms do not apply to it. Attribution and the list of modifications:
[`NOTICE`](NOTICE) and [`fork/line.env`](fork/line.env).

## Upstream README

The text below is upstream's.
