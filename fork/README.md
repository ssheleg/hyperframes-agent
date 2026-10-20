# HyperFrames Agent

`ssheleg/hyperframes-agent` is our own line of the HyperFrames engine (write HTML, render video). It
started as a fork of `heygen-com/hyperframes` and is developed here: upstream releases are merged in when
we want them, and our patches ship without waiting for upstream review.

The CLI and package names stay `hyperframes`, so every skill and composition that calls
`npx hyperframes` or imports `@hyperframes/*` works unchanged.

## Branches

| Branch     | What it is                                                 | How it moves                                                            |
| ---------- | ---------------------------------------------------------- | ----------------------------------------------------------------------- |
| `main`     | our line: an upstream release plus our patches and tooling | commits and merges; never rewritten, never force-pushed                 |
| `upstream` | a mirror of `heygen-com/hyperframes` `main`                | `git push origin upstream/main:refs/heads/upstream` (fast-forward only) |

No GitHub workflow of this repository runs: the sixteen inherited from upstream (npm publish, catalog
publish, ClawHub sync, CI, regression and the rest) are disabled in the repository settings, because they
target HeyGen's infrastructure. The checks of a release run locally in `fork/release.sh`.

## Versions and tags

| Item        | Form                                                     | Example                           |
| ----------- | -------------------------------------------------------- | --------------------------------- |
| Base        | an upstream release tag                                  | `v0.8.170`                        |
| CLI version | `<base>+sshlg.<n>` (what `hyperframes --version` prints) | `0.8.170+sshlg.1`                 |
| Tag         | `fork-v<base>-sshlg.<n>`                                 | `fork-v0.8.170-sshlg.1`           |
| Asset       | `hyperframes-<base>-sshlg.<n>.tgz` and its `.sha256`     | `hyperframes-0.8.170-sshlg.1.tgz` |

Releases are GitHub Releases of this repository, never npm. The tag keeps the `fork-` prefix: upstream's
`publish.yml` (disabled here) matches `v*-*`, and the prefix keeps any re-enabled copy from firing.

The CLI version uses semver build metadata (`+sshlg.<n>`), not a prerelease (`-sshlg.<n>`): a prerelease
sorts below its base, so the CLI would refuse registry items whose `minCliVersion` is the base. Build
metadata compares equal to the base, and `hyperframes --version` still names the line. Two effects of
keeping the base's semantics: `hyperframes init` pins new projects to `hyperframes@<base>+sshlg.<n>`,
which npm resolves to upstream's `<base>`, and Docker renders (`--docker`) cannot use the version as an
image tag (`+` is not allowed there).

The packed `package.json` carries `"hyperframesFork": { "repository", "base", "release", "commit" }`,
so a consumer can tell this line's build from npm's and name the commit it came from.

## Using it

Pin the release tarball, not npm:

```json
"hyperframes": "https://github.com/ssheleg/hyperframes-agent/releases/download/fork-v0.8.180-sshlg.1/hyperframes-0.8.180-sshlg.1.tgz"
```

The lockfile then holds the tarball's sha512. The other engine packages (`@hyperframes/core`, `lint`,
`producer`, `engine`, `parsers`, `studio-server`) come from npm at the same base version until a patch of
ours touches them. Releases made before the rename (2026-10-19) name `sshlg/heygen-hyperframes-vr` in their
`hyperframesFork.repository`; GitHub redirects that address here.

## Patches on the line

| Patch                                                                   | Upstream                           | Drop when                      |
| ----------------------------------------------------------------------- | ---------------------------------- | ------------------------------ |
| `fix(cli): each start sweeps the running markers of CLIs that are gone` | heygen-com/hyperframes#5790 (open) | an upstream release carries it |

## Release

```sh
fork/release.sh <n>             # build, run the patches' tests, pack, smoke-install the tarball
fork/release.sh <n> --publish   # also tag, push main and the tag, create the release, re-download and check the sha256
```

The smoke step installs the tarball into an empty directory, checks that `hyperframes --version`
prints the line's version, and that a start removes the marker of a dead pid.

## Taking an upstream release

1. `git fetch upstream --tags && git push origin upstream/main:refs/heads/upstream`
2. `git switch main && git merge --no-ff v<new>`
3. A patch the new release already carries merges as identical text, or conflicts on lines that now say
   the same thing: take upstream's side, then remove the patch's row from the table above.
4. `git log --no-merges v<new>..main -- . ':!fork'` lists exactly the patches still carried.
5. `fork/release.sh 1` builds on the new base (it finds the base with `git describe`), then `--publish`.
