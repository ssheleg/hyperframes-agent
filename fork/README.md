# The fork line

`main` of this repository mirrors `heygen-com/hyperframes` `main` and only ever fast-forwards to it.
`fork/main` is the fork line: an upstream release tag plus patches that upstream has not released
yet. Its packages ship as tarballs on GitHub Releases of this repository, never on npm.

## Versions and tags

| Item        | Form                                                     | Example                           |
| ----------- | -------------------------------------------------------- | --------------------------------- |
| Base        | an upstream release tag                                  | `v0.8.170`                        |
| CLI version | `<base>+sshlg.<n>` (what `hyperframes --version` prints) | `0.8.170+sshlg.1`                 |
| Tag         | `fork-v<base>-sshlg.<n>`                                 | `fork-v0.8.170-sshlg.1`           |
| Asset       | `hyperframes-<base>-sshlg.<n>.tgz` and its `.sha256`     | `hyperframes-0.8.170-sshlg.1.tgz` |

The tag starts with `fork-` because upstream's `publish.yml` fires on tags matching `v*-*` and would
try to publish to npm. No workflow of this repository fires on `fork/main` or on `fork-*` tags; the
checks run locally in `fork/release.sh`.

The CLI version uses semver build metadata (`+sshlg.<n>`), not a prerelease (`-sshlg.<n>`): a prerelease
sorts below its base, so the CLI would refuse registry items whose `minCliVersion` is the base. Build
metadata compares equal to the base, and `hyperframes --version` still names the line. Two effects of
keeping the base's semantics: `hyperframes init` pins new projects to `hyperframes@<base>+sshlg.<n>`,
which npm resolves to upstream's `<base>`, and Docker renders (`--docker`) cannot use the version as an
image tag (`+` is not allowed there); use upstream's CLI for those.

The packed `package.json` carries `"hyperframesFork": { "repository", "base", "release", "commit" }`,
so a consumer can tell the fork's build from npm's and name the commit it came from.

## Patches on the line

| Patch                                                                   | Upstream                           | Drop when                      |
| ----------------------------------------------------------------------- | ---------------------------------- | ------------------------------ |
| `fix(cli): each start sweeps the running markers of CLIs that are gone` | heygen-com/hyperframes#5790 (open) | an upstream release carries it |

## Release

```sh
fork/release.sh <n>             # build, run the patches' tests, pack, smoke-install the tarball
fork/release.sh <n> --publish   # also tag, push fork/main and the tag, create the release, re-download and check the sha256
```

The smoke step installs the tarball into an empty directory, checks that `hyperframes --version`
prints the line's version, and that a start removes the marker of a dead pid.

## Moving to a new upstream release

The line moves by merging, so `fork/main` is never rewritten and never force-pushed.

1. `git fetch upstream --tags && git switch fork/main && git merge --no-ff v<new>`
2. A patch the new release already carries merges as identical text, or conflicts on lines that now
   say the same thing: take upstream's side, then remove the patch's row from the table above.
3. `git log --no-merges v<new>..fork/main -- . ':!fork'` lists exactly the patches still carried.
4. `fork/release.sh 1` builds on the new base (it finds the base with `git describe`), then `--publish`.
