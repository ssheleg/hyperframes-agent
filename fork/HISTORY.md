# History of the line

Dated notes moved verbatim from [`HANDOFF.md`](HANDOFF.md) on 2026-11-08, when it was compacted; the handoff keeps the
current state, the next task and the reference tables. Kept out of the organization copy (`fork/export.sh`).

## State (2026-11-08)

- The estate's migration (one model for every agent: placement, data apart from the source, keys by name, an
  organization copy, heavy work on the second machine) as it applies to a line without a service:
  [`migration.md`](migration.md), items M-1 to M-8. Done here: the exported session transcript at the repository root
  (the agents base's finding F13, excluded only by `.git/info/exclude`) moved to the line's local data folder; release
  builds can run on the second machine (`fork/remote-build.sh`, then `fork/release.sh <n> --publish --prebuilt`),
  checked without publishing at `42ad14381`. The local `node_modules` was removed when the disk reached zero; a build
  here needs `bun install` first.
- Upstream `v0.9.17` to `v0.9.21` merged (`661fbe55d`, clean; the patches survive) and released as
  `fork-v0.9.21-sshlg.1` (`a104ebd63`), the first release built on the second machine and published from here: the
  local run had waited 28 minutes for `fseventsd` (over 100% CPU, other agents' builds) and was stopped before any tag.
  The copy: export `e701a03`, shared audit `ready`, `fork-v0.9.21-appvillis.1` (sha256
  `6fbbb1be8964a6551e628d3e83f2f8ba845e86d36ea59252fce3422b2fb68ec0`), built the same way from a clone of the copy on
  the second machine. Door audit: the `v0.9.16..v0.9.21` row below.
- Announced on the board: the line in `b4d4f898` (`bdb93e1a`), the copy in `7913a557` (`4223fada`). The coordinator of
  the organization's agents answered on the migration (`3ce2abbe`): its checklist is a service's, the line's route is
  right; a row for the line in the placement table is asked in `eec1aa1e`. A neighbour's possibly interrupted test runs
  (my `pkill -f "vitest run"`, 01:20 UTC) are reported in `073cc2a3`.
- The line against its agent type in the template base (`media-production`, variant `engine-line`):
  [`agent-type-plan.md`](agent-type-plan.md). Wave 1 done 2026-11-08 (`6fc41f571`): the door audit skips test
  utilities, the export checks the tree before committing and the copy before pushing (it now needs
  `ORG_TRANSFER_AUDIT` and `ORG_TRANSFER_MARKERS`), the copy builds in the organization's space on the second machine.
  Wave 2 done the same day: `fork/test.sh` (31 cases), run first by `fork/release.sh`.
  **Next task: wave 3, P-6** (report the line's lessons back to the template base on the board), then P-7 and P-8.

## State (2026-11-05)

- `main` carries upstream `v0.9.16` (merge, clean; released as `fork-v0.9.16-sshlg.1`, `9470648c8`, 79 of 79, the
  same day as the one below). Before it upstream `v0.9.15` (merge `5ceec4b00`, clean; upstream touched only `projectLock.test.ts` among the
  patched files and the patch survives). Released as `fork-v0.9.15-sshlg.1` (`42cbd37ea`, table below): the first check
  run failed only the three watcher tests under a busy `fseventsd`; after `release.sh` began waiting for three calm
  readings, the publish run, started once the disk had 8 GB free (the estate's rule for release builds, board thread
  `b91254c4`), passed 79 of 79. The team copy was rechecked on 2026-11-05 for the operator's personal markers (word
  list over the tree and all 11 commits, gitleaks over the history): 0 (board message `e50da555`).

## State (2026-11-02, evening)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the `ssheleg`
  organisation on 2026-10-19; GitHub redirects the old address, release downloads included). Every inherited
  workflow is disabled (repository settings). Four that later upstream releases added had run here unnoticed
  (`lambda-arm64-image`, `lambda-sam-template`, `player-safari`, and `windows-window-probe` from `v0.8.221`);
  they were disabled on 2026-10-30 and a running one cancelled. The door audit now lists added workflow files.
- `main` = upstream `v0.9.13` (merge `fdfd05e84`) + two patches + `fork/`. `git diff v0.9.13 main -- . ':!fork'` shows
  exactly what we carry: the speech patch (`packages/cli/src/tts/`) and the Node 26 / macOS patch with its watcher test
  fixes (`packages/cli/src/server/fileWatcher*`, `utils/projectLock.test.ts`, `whisper/sherpa.test.ts`), plus our
  header in `CLAUDE.md`, `AGENTS.md` and `README.md`. `upstream` mirrors HeyGen's `main`.
- Latest release `fork-v0.9.13-sshlg.1` (table below), a clean merge, built from scratch after the 2026-11-04 cleanup
  removed `node_modules` and build outputs. Before it `fork-v0.9.12-sshlg.1`, a clean merge although upstream touched the speech patch's
  `tts/synthesize.ts` (`makeOutputFolder` for the output folder, #7151); the 41 speech tests pass. Before it
  `fork-v0.9.11-sshlg.1`, a clean merge; its first two push attempts failed during a GitHub
  incident (Git Operations degraded, 2026-11-04), and a watcher on githubstatus.com ran it once it cleared. Before it
  `fork-v0.9.10-sshlg.1`. Before it `fork-v0.9.9-sshlg.1`, also clean; its first publish run stopped before the tests
  because `fseventsd` stayed above 60% CPU for the whole 30-minute wait, and the second, with
  `FSEVENTSD_WAIT_SECONDS=7200`, went through. `fork-v0.9.8-sshlg.1` was a clean merge of `v0.9.6` to `v0.9.8`; its first publish run
  failed one upstream test (`whisper/sherpa.test.ts`, "cancels an in-flight probe": a child Node must start within
  300 ms) at load average 257, and passed on the same commit at 143. Before it, `fork-v0.9.5-sshlg.1` carried `v0.9.0` to `v0.9.4`. The merge was clean. `v0.9.0`
  breaks only distributed rendering: Lambda and Cloud Run run Plan v2 alone, so a stack deployed from 0.8 is
  redeployed with the 0.9 SDK. The release before, `fork-v0.8.231-sshlg.1`, carried `v0.8.222` to `v0.8.230`. The merge was clean
  (upstream moved the speech cache to `hyperframesCacheDir("tts")`, #6716) and was committed with `--no-verify` after
  the `fallow` check (35 findings it calls new, all in files identical to the tag). Upstream `v0.8.221` had conflicted
  with the speech patch in all four `packages/cli/src/tts` files (#6769, a foreign `PYTHONPATH`): resolved so that
  upstream's `workingPythonEnv` picks the environment and the patch's `probePythonPackage` still names the import's
  own error.
- **The running-markers sweep is upstream's now.** heygen-com/hyperframes#5790 was approved and merged on 2026-10-24
  (merge `24965372d`, in `v0.8.193`), so the line no longer carries it: `runningCli.ts` and its test are byte-identical
  to the tag. Getting it in took a signed commit (`heygen-com` requires them; ours were authored `Робот <r@e.com>`) and a
  CodeQL fix in its test; on the operator's word the PR's head was force-updated with a lease. The other two fixes wait
  as signed branches for the operator's send instruction: [`upstream-prs.md`](upstream-prs.md).
- The pinning consumer, Frame Agent, moves its pin in its own repository. On 2026-10-24 it pinned
  `fork-v0.8.192-sshlg.1` (`ssheleg/frame-agent` `main` `e7a61cd7a`, `package.json`); on 2026-11-04 it runs
  `fork-v0.9.13-sshlg.1` on both of its instances (`main` `ce9ca68`, a live order delivered, its message `3b2bf938`), and
  its team copy runs `fork-v0.9.13-appvillis.1` on Linux (Ubuntu 24.04), so the line's patches build there. Every release is announced to it
  on the project board, thread `b4d4f898`, with its door audit; `v0.8.193-sshlg.1` is message `7b997544`,
  `v0.8.198-sshlg.1` is message `d9a91a4f`, `v0.8.206-sshlg.1` is message `1368c271`, `v0.8.210-sshlg.1` is message `1befaec4`, `v0.8.221-sshlg.1` is message `a0f6b927`, `v0.8.231-sshlg.1` is message `d80105a7`, `v0.9.5-sshlg.1` is message
  `86579635`, `v0.9.8-sshlg.1` is message `df1eb3a2`, `v0.9.9-sshlg.1` is message `f1e3e2b3`, `v0.9.10-sshlg.1` is message `4f9bb9ec`, `v0.9.11-sshlg.1` is message `c1b84a77`, `v0.9.12-sshlg.1` is message `15cb59f9`, `v0.9.13-sshlg.1` is message `4fd9d660`, `v0.9.15-sshlg.1` is message `ed34a776`, `v0.9.16-sshlg.1` is message `700ca361`.

## Tooling fixes (2026-10-23 and 2026-10-24)

- `fork/release.sh` removes its temporary directories (`a77f746ce`): `tmpdir` ran inside `$(...)`, so `cleanup` saw an
  empty list and every run left its directories in `TMPDIR` (26 of them, 0.9 GB, found when the disk filled).
- `fork/door-audit.sh` lists new CLI flags (`e20c025a1`) and no longer reads `startPrefetch(` as a network call
  (`846fda8db`). Run over past ranges, the flags section finds `--page-motion-blur` (`v0.8.187`), which that release's
  report had missed.
- A merge committed by hand meets `fallow audit --base origin/main` in the pre-commit hook, which counts upstream's own
  findings in the new tag as ours (`v0.8.192`: two unused `devDependencies`, the `core`/`parsers` cycle, a stale
  suppression at `batchRender.ts:445`, all verbatim in the tag). fork/README.md, "Taking an upstream release", says what
  to check before committing past it.

## Tooling (2026-11-02)

- The copy carries the Appvillis prefix (operator, board thread `0f7e45aa`, 2026-11-04): renamed on GitHub to
  `appvillis-com/appvillis-hyperframes-agent`, titled Appvillis HyperFrames Agent (`2d486260c`, copy `4e9cefd`, org-index
  `954a4ad`, consumers told in `7913a557`, message `3c45c47d`). Its local checkout's origin points at the new name.
- Copy strategy S2/S3 (board thread `b91254c4`, accepted by the coordinator on 2026-11-04): `fork/export.sh` writes
  `Source-Revision: line@<sha12>` into each export commit and refuses while the copy has a commit by anyone but the
  export's author or an open pull request (`2766d1de3`; checked both ways on a local commit, then reset).
- `fork/status.sh` reads both lines at once and names the next step (exit 10 when one is due). Its first run found
  upstream `v0.9.0` to `v0.9.5` not merged, taken the same day.
- `fork/workflows-guard.sh` disables active workflows and cancels their runs; `fork/release.sh --publish` runs it after
  its push. It names the repository from `origin`, not `gh repo view`, which in this fork answers
  `heygen-com/hyperframes`, and refuses any `heygen-com` repository. Checked by enabling `fast-video-validation.yml`
  here and running it: disabled, `--check` then exits 0.
- `fork/release.sh` restores its version stamp of `packages/cli/package.json` from a saved copy. Its `git checkout`
  on exit failed silently after a failed run, my `commit -a` carried `0.9.5+sshlg.1` into `7385d1f55` (the commit the
  tag `fork-v0.9.5-sshlg.1` names; the asset is right, the stamp is the release's own version), and the shared audit
  of the copy caught it. Reverted in `a9a49aaf9`; checked by a run that fails after the stamp (tree clean).
  `fork/export.sh` now checks the whole tree for the line's name. The smoke install prints npm's output on failure.
- `fork/release.sh` waits for `fseventsd` under 60% CPU before the watcher tests instead of failing; checked at 165%
  (it waited, then went on once it fell) and with a limit of 0 and no wait (it fails with the reading).
- Since 2026-11-05 it waits for `FSEVENTSD_CALM_SAMPLES` (3) readings under the limit in a row, 10 s apart: the first
  `v0.9.15` check run started its tests on one reading under 60%, `fseventsd` went back to 100% within seconds, and three
  watcher tests heard nothing (`expected [] to include 'index.html'`); the other 76 tests passed. Checked with a limit
  nothing reaches (returns after two readings, 11 s) and with a limit of 0 and no wait (fails, naming 0 of 3).

## Next task (as of 2026-11-05)

This repository stays where it is (operator, 2026-10-28, thread `3b676949`, message `e1350512`). Since 2026-11-02
the team has a private copy, `appvillis-com/appvillis-hyperframes-agent` (operator, 2026-10-30, thread `7913a557`, message
`0b1fd1e3`): one commit per export of this line, no upstream history. Releases: `fork-v0.8.221-appvillis.1` (`93c768b`,
sha256 `e5cb424361e7c245a60b5f77dc92acf9129502411eba894e5d8ab8ac779dee2b`) and `fork-v0.8.231-appvillis.1` (`746b7fb`,
sha256 `b0fb8f0e67215953bf0b4d3d89e3729f1d2115dc75c7b11fdde35403cd2243b5`) and `fork-v0.9.5-appvillis.1` (`c8d1035`,
sha256 `811dc2b06a27587887e7d168106ac06098b1712f0961032fdf44f3e01c53c479`) and `fork-v0.9.8-appvillis.1` (`05f3b03`,
sha256 `da47f19130b9eab72073ec18edef43fd6074464feeb473341ea4bf8d18328e31`) and `fork-v0.9.9-appvillis.1` (`f672c37`,
sha256 `55474e5d92354c8ed30949c30a84957f885e64a363ad3eca77cca81a34afdac2`) and `fork-v0.9.10-appvillis.1` (`fed951e`,
sha256 `1d5a009adbd7bc2ff1b5045d0b09c274d5efbebedd4118b9e15c9400f54638de`) and `fork-v0.9.11-appvillis.1` (`3c94205`,
sha256 `93d21d23edd0820948083cb93cf4be8de8ee372b4460d86d7dc5f3a87ca6b6d1`) and `fork-v0.9.12-appvillis.1` (`cf34d9e`,
sha256 `eeaecc1025606b7fd38222d738260b48c7f8e8f97a8141f692556f0785b8b00d`) and `fork-v0.9.13-appvillis.1` (`956bfe5`,
sha256 `4f27c68a969c1dd441a0c176ed33791b1d8a58590522ea0d9447446e782a754f`, the first under the new name) and `fork-v0.9.15-appvillis.1` (`d5a3419`,
sha256 `be7cb7ae7e79f6e48385065fb42377a2774d35b9ad9b3b7cd0da1daeea5f9e00`, checked before its push: audit `ready`, the word
list 0 over the line's files, gitleaks 0) and `fork-v0.9.16-appvillis.1` (`1eb6be4`,
sha256 `621d991b02c05af4ed5b75c2b549e582f536d37b3b81bc6889806ec34fe1c76d`, the first export under the service author
`appvillis-hyperframes-agent@users.noreply.github.com`; its first audit stopped on the author credit in upstream's vendored
`three-path-tracer`, now in `fork/org/audit-allow-literals.txt`); shared audit
`ready` on each; catalogued in
`appvillis-com/org-index` (`not_verified`); announced in thread `7913a557` (`9a842399`, `ea6dab16`, `6e9642a9`, `8e4adb91`, `59b98775`, `a00b8d3a`, `c4d9fa7a`, `91bf1b34`, `a8d4c425`, `639219a2`, `1289e52f`). Frame Agent's copy
(`appvillis-com/frame-agent` `8d1b42e`) keeps the copy's tarball in its own `engine/` folder, because an anonymous
download of a private release answers 404; it moves to a new release by replacing that file (its message `091eca5f`). Its
checkout is `~/DATA/_worktrees/hyperframes-agent-org`. How it is refreshed: fork/README.md, "The team copy".

1. Upstream releases after `v0.9.16`: `fork/status.sh` names them. Read the new tags' commits and take the latest (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish`, run
   `fork/door-audit.sh v0.9.16 v<new>`, add its findings to the table above and the release to the release table, and
   post them to the consumer on the board (thread `b4d4f898`). The release disables any workflow the merge added
   (`fork/workflows-guard.sh`). Then refresh the team copy: `fork/export.sh ~/DATA/_worktrees/hyperframes-agent-org --push`, the
   shared audit to `ready`, `fork/release.sh 1 --publish` in the copy's checkout, and tell its consumers in thread
   `7913a557` (fork/README.md, "The team copy").
2. On the operator's send instruction only: the two upstream PRs in [`upstream-prs.md`](upstream-prs.md).

Before acting on this section, check it against Git: a tag it names as future may already exist.
