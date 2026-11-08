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

No GitHub workflow of this repository runs: every one inherited from upstream (npm publish, catalog
publish, ClawHub sync, CI, regression and the rest) is disabled in the repository settings, because they
target HeyGen's infrastructure. The checks of a release run locally in `fork/release.sh`. A workflow file an
upstream release adds arrives enabled and starts on the push of the merge: `fork/workflows-guard.sh` disables every
active workflow and cancels its runs, and `fork/release.sh --publish` runs it right after its push (the door audit
also names added workflow files). `fork/workflows-guard.sh --check` only reports, exiting 1 when one is active.

`fork/status.sh` reads both lines at once: the base of `main`, upstream releases not merged yet, the latest
release of the line and of the copy, the copy's base and any active workflow, and names the next step of this file
(exit 10 when one is due, 0 when nothing is).

## The team copy

`appvillis-com/appvillis-hyperframes-agent` (Appvillis HyperFrames Agent; named `hyperframes-agent` until 2026-11-04, when the operator asked every agent going to Appvillis to carry the prefix, board thread `0f7e45aa`) is a private copy of this line for the team (operator, 2026-10-30, project board
thread `7913a557`); this repository stays where it is. The copy is not a fork (a fork of a public repository cannot be
private) and carries no upstream history (upstream commit `24965372d` names a person's address). After each release
of this line:

1. `fork/export.sh <copy-checkout> --push` writes the line's tree into the copy as one commit on its `main`, with a
   `Source-Revision: line@<sha12>` line naming the line commit it was built from. It refuses while the copy has a commit
   by anyone but the export's author since the last export or an open pull request. A team change goes back to the line
   first, in a commit whose message carries `Backports: <copy-sha>`; then the export goes through. No
   workflows, no file an LFS rule covers, no maintenance notes of this line; `fork/org/` supplies the copy's README,
   HANDOFF, NOTICE, `.gitleaks.toml` and the headers of `CLAUDE.md`, `AGENTS.md` and `README.md`.
2. The export checks itself: with `ORG_TRANSFER_AUDIT` and `ORG_TRANSFER_MARKERS` naming the shared transfer audit and
   its marker file, it audits the exported tree (allow list `fork/org/audit-allow-literals.txt`) and runs gitleaks before
   it commits, and audits the copy with its history before `--push`; anything but `ready` refuses.
3. In the copy's checkout, `fork/release.sh <n> --publish` releases `fork-v<base>-appvillis.<n>` (it reads the base and
   the patch tests from the copy's `fork/line.env`).

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
"hyperframes": "https://github.com/ssheleg/hyperframes-agent/releases/download/fork-v0.8.198-sshlg.1/hyperframes-0.8.198-sshlg.1.tgz"
```

The lockfile then holds the tarball's sha512. The other engine packages (`@hyperframes/core`, `lint`,
`producer`, `engine`, `parsers`, `studio-server`) come from npm at the same base version until a patch of
ours touches them. Releases made before the rename (2026-10-19) name `sshlg/heygen-hyperframes-vr` in their
`hyperframesFork.repository`; GitHub redirects that address here.

## Patches on the line

| Patch                                                                              | Upstream                                | Drop when                      |
| ---------------------------------------------------------------------------------- | --------------------------------------- | ------------------------------ |
| `fix(cli): speech works from a sandboxed run and says why kokoro-onnx cannot load` | `pr/tts-sandbox-safe-signed` (not sent) | an upstream release carries it |
| `fix(cli): ignore the project folder's own FSEvents change; Node 26 test fixes`    | `pr/node26-macos-signed` (not sent)     | an upstream release carries it |

Their signed upstream branches and the steps to send them: [`upstream-prs.md`](upstream-prs.md). The running-markers
sweep (heygen-com/hyperframes#5790) was ours until `v0.8.193` carried it.

## Release

```sh
fork/release.sh <n>             # build, run the patches' tests, pack, smoke-install the tarball
fork/release.sh <n> --publish   # also tag, push main and the tag, create the release, re-download and check the sha256
```

`fork/test.sh` tests the line's own scripts (throwaway Git repositories, stubs for `gh` and `ssh`, about 20 s);
`fork/release.sh` runs it before it builds anything.

The smoke step installs the tarball into an empty directory, checks that `hyperframes --version`
prints the line's version, and that a start removes the marker of a dead pid.

A release build wants about 8 GB of free disk. On a machine short of it, build on another one over SSH and publish
from here; the other machine needs a clone of this repository, Bun and Node, and no GitHub CLI sign-in:

```sh
git push origin HEAD:main                                          # the other machine builds origin's main
FORK_REMOTE_DIR=<clone> fork/remote-build.sh <ssh-host> <n>        # build, test, pack, smoke there; the tarball comes back to fork/out/
fork/release.sh <n> --publish --prebuilt fork/out/<tarball>        # here: check it is this commit and version, smoke, publish
```

`--prebuilt` refuses a tarball whose name, `.sha256`, version or `hyperframesFork.commit` is not this release's.
On the second machine the personal space publishes too: its GitHub CLI is `~/.local/bin/gh`, a wrapper that reads the
token from the credential store (call it from a login shell). The copy builds in the organization's space there, from a
clone reached by its own read-only deploy key (`Host gh-appvillis-hyperframes-agent`).

## Taking an upstream release

1. `git fetch upstream --tags && git push origin upstream/main:refs/heads/upstream`
2. `git switch main && git merge --no-ff v<new>`
3. A patch the new release already carries merges as identical text, or conflicts on lines that now say
   the same thing: take upstream's side, then remove the patch's row from the table above. A merge committed by
   hand (after a conflict, or `--no-commit`) runs the pre-commit hook, whose `fallow audit --base origin/main` counts
   upstream's own findings in the new tag as ours. If every finding it names is present verbatim in the tag
   (`git show v<new>:<path>`), and `bun run build`, `bun run lint` and the hook's typecheck commands pass, commit the
   merge with `--no-verify` and say why in its message, as plain `git merge --no-ff` would have committed it.
4. `git diff --stat v<new> main -- . ':!fork'` shows exactly what the line still carries. `git log v<new>..main` is
   not that list: a patch upstream took under another commit (a squash merge) stays in the log but no longer
   changes anything.
5. `fork/release.sh 1` builds on the new base (the base is the newest `v*.*.*` tag merged into `HEAD`), then `--publish`. Its
   watcher tests run on the real file system and fail while `fseventsd` is busy, so before them it waits, checking
   every 30 s, until `fseventsd`'s CPU is under 60% (`FSEVENTSD_MAX_CPU`), and gives up after 30 minutes
   (`FSEVENTSD_WAIT_SECONDS`) ([`HANDOFF.md`](HANDOFF.md), "Watcher tests under load").
6. `fork/door-audit.sh v<old> v<new>` lists what a consumer that confines the engine must read before it moves its pin:
   new CLI commands and flags, environment variables read in shipped code, new child processes and `fetch` calls, packages
   installed at run time, and changed skills with the commands their new lines name. It reports a diff between two
   tags, so a behaviour older than `v<old>` never shows: the CLI has installed `onnxruntime-node` and `@google/genai` from
   npm on first use since `v0.8.51` and `sharp` since `v0.8.182`; `HYPERFRAMES_NO_OPTIONAL_INSTALL=1` (since `v0.8.182`)
   turns that off. Post the report's findings to the consumer when the release is published.
