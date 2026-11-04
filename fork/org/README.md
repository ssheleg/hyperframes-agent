# HyperFrames Agent: the team copy

This repository is the team's copy of the HyperFrames Agent line, a line of the HyperFrames engine
(`heygen-com/hyperframes`, Apache-2.0, see [`../NOTICE`](../NOTICE)) that takes upstream releases and carries a few
patches. It exists so that team agents can install the engine from the organisation.

## How the copy is refreshed

The line itself is maintained outside this organisation. After each of its releases its export script writes the
whole tree here as one new commit on `main` (author `Робот <r@e.com>`), fast-forward only; `main` is never rewritten.
The export leaves out:

- upstream's Git history and the line's own maintenance notes;
- `.github/workflows` (they target HeyGen's infrastructure);
- files kept in Git LFS upstream: the `packages/producer/tests` regression fixtures and two demo assets of the
  `changelog-video` skill. The producer regression suite therefore cannot run here; the CLI does not use them.
  `.gitattributes` carries no LFS rules here, so nothing in this repository goes to an LFS store.

Make a change in the line, not here. The export refuses to run while this repository has a commit by anyone but the
export's author since the last export, or an open pull request, so a change made here is never overwritten in silence:
it waits until the line has taken it and named it in a `Backports: <sha>` line. Take a fix to the line's maintainers on the project board. Each export commit names the line commit it
was built from in a `Source-Revision:` line.

[`line.env`](line.env) names the upstream release this tree is (`LINE_BASE`), the test files of the patches
(`LINE_TESTS`) and the patches (`LINE_PATCHES`); `release.sh` reads it.

## Versions, tags and assets

| What        | Form                                                         | Example                               |
| ----------- | ------------------------------------------------------------ | ------------------------------------- |
| CLI version | `<base>+appvillis.<n>` (what `hyperframes --version` prints) | `0.8.221+appvillis.1`                 |
| Tag         | `fork-v<base>-appvillis.<n>`                                 | `fork-v0.8.221-appvillis.1`           |
| Asset       | `hyperframes-<base>-appvillis.<n>.tgz` and its `.sha256`     | `hyperframes-0.8.221-appvillis.1.tgz` |

The version uses semver build metadata (`+appvillis.<n>`), so it compares equal to `<base>` for registry
`minCliVersion` gates and update checks. `<n>` counts releases of one base from 1.

## Releasing

From a clean `main` of a clone of this repository:

```sh
fork/release.sh 1            # install, build, test the patches, pack, smoke-install; leaves fork/out/
fork/release.sh 1 --publish  # also tags, pushes and creates the GitHub Release, then downloads it back and checks sha256
```

After its push the release runs `fork/workflows-guard.sh`, which disables any active workflow of this repository
(the export carries no workflow files, so it finds none unless one is added here). `--skip-deps` reuses the built
workspace packages. The release needs `bun`, `node`, `npm` and an authenticated `gh`.

## Installing

The repository is private, so an anonymous download is refused. Download with an authenticated `gh` and install
the file:

```sh
gh release download fork-v<base>-appvillis.<n> --repo appvillis-com/hyperframes-agent --pattern 'hyperframes-*.tgz'
npm install ./hyperframes-<base>-appvillis.<n>.tgz
```
