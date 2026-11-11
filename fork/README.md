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
of this line.

A second copy, `passioncode-ai/passioncode-hyperframes-agent` (PassionCode HyperFrames Agent), was made on 2026-11-11 for
the organization PassionCode.ai: the operator asked for each organization's content farm to run on its own, with the
same update path (board thread `2f651c5c`, request `e2c76d3a`; Asset Foundry `docs/ORG-FARMS.md`). It follows the
organization's repository standard (README, `AGENTS.md`, `CLAUDE.md`, agent-sync, backlog sources) except the licence:
the code is HeyGen's under Apache-2.0 and keeps it, as the organization's licensing rule says of third-party code, so the
organization's AGPL `LICENSE`, `COMMERCIAL-LICENSE.md` and `CLA.md` are not added. Each copy is refreshed the same way
after each release of this line:

1. `fork/export.sh <copy-checkout> --org <appvillis|passioncode> --push` (`--org` defaults to `appvillis`) writes the line's tree into the copy as one commit on its `main`, with a
   `Source-Revision: line@<sha12>` line naming the line commit it was built from. It refuses while the copy has a commit
   by anyone but the export's author since the last export or an open pull request. A team change goes back to the line
   first, in a commit whose message carries `Backports: <copy-sha>`; then the export goes through. No
   workflows, no file an LFS rule covers, no maintenance notes of this line; `fork/org/<org>/` supplies the copy's README,
   HANDOFF and the headers of `CLAUDE.md`, `AGENTS.md` and `README.md` (and, for PassionCode, `files/` with the
   coordination config and backlog sources, and a `.gitignore` line that lets the config travel); `fork/org/` the
   `NOTICE` and `.gitleaks.toml` every copy shares. The first export into an empty repository makes its first commit.
2. The export checks itself: with `ORG_TRANSFER_AUDIT` and `ORG_TRANSFER_MARKERS` naming the shared transfer audit and
   its marker file, it audits the exported tree (allow list `fork/org/audit-allow-literals.txt`) and runs gitleaks before
   it commits, and audits the copy with its history before `--push`; anything but `ready` refuses.
3. In the copy's checkout, `fork/release.sh <n> --publish` releases `fork-v<base>-<org>.<n>` (it reads the base and
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

## Visual types and style presets

Agents above the engine show a person what kinds of video it can make before a generation, and keep the taste the
person chose so later videos repeat it (board request `b948516e`, 2026-11-08).

- `visual-types-<base>-<line>.<n>.json`, an asset of every release, written by `node fork/visual-types.mjs` from that
  commit's registry: 11 visual types (kinetic typography; data, charts, maps and diagrams; interface and product; code;
  captions and overlays; 3D, shaders and particles; transitions; backgrounds and textures; images and footage; camera
  and depth; talk, interview and social), each with the registry blocks and components that make it, the libraries
  their files use (GSAP, three.js, WebGL, WebGPU, d3, Lottie, canvas, SVG), an install command and a preview frame
  where the registry has one; the kinds made outside the registry (talking head, screen recording, generated footage)
  with the skill that makes them; and the style layer: the 18 tokens of `themes/CONTRACT.md`, the theme packs and the
  frame presets of the `hyperframes` skill. The same tree gives the same bytes. Every string is written without a dash
  between words (an em dash, `--` or a spaced hyphen becomes a comma): the registry's own descriptions carried about a
  hundred, and these texts go in front of people.
- `visual-types-files-<base>-<line>.<n>.tar.gz`, beside it: the preview frames (`posters/`, JPEG at most 640 px wide
  when ffmpeg is installed) and the line's composition recipes (`recipes/`). Each item's `poster_file` and each
  recipe's `file` are paths inside it, so a caller shows them without the network. `files.posters_missing` lists the
  frames upstream's registry links but does not serve (64 of 178 answered 403 on 2026-11-08). The release refuses when
  no frame at all could be fetched. Frames are fetched only for items a type lists; the 38 items no type names are
  counted in `totals.untyped`.
- `registry-<base>-<line>.<n>.tar.gz`, beside them: the registry in the layout the HTTPS registry serves
  (`registry/registry.json`, then `registry/<type-dir>/<name>/registry-item.json` with every file beside it; 457 items,
  823 files, 39 MB on 2026-11-09). Each item's `mirror_dir` names its directory, so a run without the network reads a
  block's own sources and copies each file to its `target` (the CLI's `add` reads only an `https://` registry). Files a
  manifest hosts on a CDN (`url`, 410 of them) are not in it and are listed in `registry_mirror.hosted_elsewhere`.
- Composition recipes (`compositions` in the catalogue, sources in `fork/recipes/`) cover layouts the registry has no
  block for. `presenter-over-diagram`: a cut-out presenter over a diagram that fills the frame; the presenter shrinks
  into a corner while it plays and leaves by turns (a dissolve, then a reverse grow); nothing covers the face. It is a
  root composition because the runtime seeks media only in the root; `npx hyperframes lint` and `check` pass on it.
- `fork/style-preset.mjs` keeps a project's taste as a `hyperframes-style-preset/1` file: every contract token
  (`--dur-beat` is the pace), and optionally a frame preset, a caption item, preferred transitions, the text density
  and who decided each field (a person or the agent, with the date). `new <theme-pack>` starts one, `check` says what is
  missing or wrong, `css` writes the `:root` block a composition loads. The preset lives with the project's consumer
  (a video service's project profile); the engine only reads it.

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

Before that, `fork/release.sh` reads the free space of the build volume and refuses under 8 GB (`FORK_MIN_FREE_GB`),
naming `fork/remote-build.sh` as the way out; with `--prebuilt` it skips that and checks instead that `TMPDIR` holds
the tarball's unpacked size plus 2 GB (`FORK_SMOKE_FREE_GB`) for the smoke install.

The smoke step installs the tarball into an empty directory, checks that `hyperframes --version`
prints the line's version, and that a start removes the marker of a dead pid.

A release build wants about 8 GB of free disk. On a machine short of it, build on another one over SSH and publish
from here; the other machine needs a clone of this repository, Bun and Node, and no GitHub CLI sign-in:

```sh
git push origin HEAD:main                                          # the other machine builds origin's main
FORK_REMOTE_DIR=<clone> fork/remote-build.sh <ssh-host> <n>        # build, test, pack, smoke there; the tarball comes back to fork/out/
fork/release.sh <n> --publish --prebuilt fork/out/<tarball>        # here: check it is this commit and version, smoke, publish
```

Published assets are never replaced: consumers pin their sha256, and a replaced asset breaks the pin and makes the
earlier release impossible to reproduce. A fix to an asset (a repacked archive, a corrected catalogue) ships under the
next release number. On 2026-11-09 the repacked archives of `v0.9.26` replaced the originals under the same tags and a
consumer's build refused them as "not the pinned bytes" (board `4fe90f86`). Release notes may be corrected; assets may
not.

`--prebuilt` refuses a tarball whose name, `.sha256`, version or `hyperframesFork.commit` is not this release's.
`<n>` may be `auto` in both scripts: the next number on the base from the tags here and on origin. A number past it is
refused as a gap, and an existing tag as taken.
On the second machine the personal space publishes too: its GitHub CLI is `~/.local/bin/gh`, a wrapper that reads the
token from the credential store (call it from a login shell). The copy builds in the organization's space there, from a
clone reached by its own read-only deploy key (`Host gh-appvillis-hyperframes-agent`).

## Taking an upstream release

1. `git fetch upstream --tags && git push origin upstream/main:refs/heads/upstream`
2. `git switch main && git merge --no-ff v<new>`
   A release that adds a workspace package (`v0.9.33` added `packages/share`) fails the commit hook's typecheck until
   `bun install` links it; that install also rewrites the version fields of upstream's stale `bun.lock`. Restore it
   (`git checkout -- bun.lock`) before `fork/remote-build.sh`, which refuses a tree with uncommitted changes.
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
