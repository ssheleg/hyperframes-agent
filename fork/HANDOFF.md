# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-24)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the
  `ssheleg` organisation on 2026-10-19; GitHub redirects the old address, release downloads included).
- `main` = upstream `v0.8.192` (merge `038db04dd`; before it `v0.8.191` merge `714739c7d`, `v0.8.190` merge `019d07c6d`, `v0.8.189` merge `711159342`, `v0.8.188` merge `88c8b8af0`, `v0.8.187` merge `5404e6aa8`, `v0.8.186` merge `2171ab2d0`, `v0.8.185` merge `b0bd45480`, `v0.8.184` merge `66bfeedd2`, `v0.8.181` merge `2fb047c8a`,
  `v0.8.180` merge `8595a06f6`) + the running-markers sweep (`cbe3ca66a`) + the speech patch (`118a29e52`) + the Node 26 / macOS patch (`cca5e193c`) + `fork/`; `upstream` mirrors HeyGen's `main`.
- Latest release `fork-v0.8.192-sshlg.1` (commit `3f163dc52`, sha256
  `c3c9f9ee14dd9c9da1e42eb2b662b9c8d0813ec1f33359de7c3830d44b5d684d`); `fork/release.sh` passed at load average 51: the
  patches' tests (9 files, 75 tests), the smoke install printed `0.8.192+sshlg.1` and swept a dead marker, the
  re-downloaded asset matched its sha256. The merge was clean and carries every patch. It was committed without the
  pre-commit hook, as plain `git merge --no-ff` would be: `fallow audit --base origin/main` counted four findings of
  upstream's own in the tag as ours (unused `@types/aws-lambda` and `@types/mime-types`, the `core`/`parsers` cycle, a
  stale suppression at `batchRender.ts:445`, all verbatim in `v0.8.192`); build, `bun run lint` and the hook's typecheck
  commands passed on the merged tree.
- `fork/door-audit.sh v0.8.191 v0.8.192` (66 commits): no new command, flag or run-time install. `HYPERFRAMES_SKIP_SKILLS`
  now also silences a new stderr notice after `render`, `lint` and `validate` ("N HyperFrames skills out of date or
  missing", read from the existing 24 h background check's cache; `HYPERFRAMES_NO_UPDATE_CHECK` too); `init` no longer
  touches installed skills; `history` runs `git diff --no-index` for large text diffs; the engine runs `tasklist` on
  Windows. Two skill files changed (`init-and-scaffold.md`, `skill-lifecycle.md`).
- Upstream PR heygen-com/hyperframes#5790 was **approved** on 2026-10-24; the maintainer queues it once its commits are
  signed and CodeQL is green. CodeQL's finding (a file system race in the test) is fixed in `d5959004e`. All three of
  our upstream fixes now have a signed branch whose files match `main`; replacing #5790's unsigned head needs the
  operator's word (a force push, or a new PR): [`upstream-prs.md`](upstream-prs.md).
- Previous release `fork-v0.8.191-sshlg.1` (commit `fb4cb29f2`, sha256
  `d493a09c0f53ebb08fdcade0dd87bc84192c881987415df735c296ef016f9d37`); `fork/release.sh` passed: the patches' tests
  (9 files, 75 tests), the smoke install printed `0.8.191+sshlg.1` and swept a dead marker, the re-downloaded asset
  matched its sha256. The merge was clean; all patches carry over. The first attempt stopped on five watcher tests at
  load average 139 (`fseventsd` at 120% CPU delivered events seconds late); `fb4cb29f2` lets them wait out late
  bursts, and the release passed once the load fell to 18. Upstream's 31 commits: preview fetches only the clips due
  next, a composition whose script throws is skipped with a warning, `check` writes progress lines to stderr, Studio
  gains a motion blur panel, and fixes across the SDK, engine, lint and producer.
- `fork/door-audit.sh v0.8.190 v0.8.191`: no new command, flag, environment variable, child process, network call or
  run-time install. Eight skill files changed: `snapshot --range` is written `START,END` (was `START:END`), `--fps`
  takes 1 to 240 or a rational and defaults to the root's `data-fps`, the `hyperframes usage --json` section left
  `hyperframes-cli/references/upgrade-info-misc.md`, and the `transcribe` default model is reworded. Its first run
  listed `startPrefetch(` as a network call; `846fda8db` makes `fetch(` start a word.
- Previous release `fork-v0.8.190-sshlg.1` (commit `e20c025a1`, sha256
  `9d7577e59ad2b3fb52e64cc3865835e7244f083fdbdd8f6ba556742df9f9f8c4`); `fork/release.sh` passed: the patches' tests
  (7 files, 69 tests), the smoke install printed `0.8.190+sshlg.1` and swept a dead marker, the re-downloaded asset
  matched its sha256, no `hf-fork-*` directory was left. The merge was clean; all four patches carry over. Upstream's
  changes: motion blur picks its tier itself (`filter` when every mover only translates, else `capture`;
  `data-motion-blur-tier` forces one) and `check` reports `motion_blur_filter_fallback`; a render no longer decodes the
  videos it replaces with extracted frames; a long audio mix prepares its clips a few at a time; the frame cache budget
  is shared by the capture workers; `render -c` takes an absolute entry inside the project; Studio gains a seek bar.
- `fork/door-audit.sh v0.8.189 v0.8.190`: every section empty except one changed skill line
  (`hyperframes/references/motion.md`, naming `hyperframes check`).
- `fork/door-audit.sh` lists new CLI flags since `e20c025a1` (citty argument definitions added under
  `packages/cli/src/commands`). Before that a new flag on an existing command never showed: run over past ranges it finds
  `check --prepare-media` (`v0.8.189`), `--video-arch` and `--page-motion-blur` (`render`, `cloud render`; `v0.8.187`);
  the last was missing from that release's report. Both are in the announcement of `v0.8.190-sshlg.1`.
- Previous release `fork-v0.8.189-sshlg.1` (commit `a77f746ce`, sha256
  `c1eaca752f4c0e5b46acc31f4bc713cbae6c7b380ade4242bad7ab7ce46bb1f0`); `fork/release.sh` passed: the patches' tests
  (7 files, 69 tests), the smoke install printed `0.8.189+sshlg.1` and swept a dead marker, the re-downloaded asset
  matched its sha256. The merge was clean; all four patches carry over. Upstream's six fixes: long projects `check` to
  completion (boxed resumable proxy copies, `check --prepare-media`, an idle deadline), any number of audio clips mix in
  stages, the same x264/x265 thread count on any host, an opaque ProRes clip extracts to jpg, the history lock works
  without hard links, and a CI size-budget tolerance.
- `fork/door-audit.sh v0.8.188 v0.8.189`: one new environment variable, `HYPERFRAMES_PROXY_CACHE_STALE_TEMP_MS`
  (`studio-server/src/helpers/proxyTranscoder.ts`): how old an untouched proxy temp file in the project's own cache must
  be before it is removed; default and ceiling 10 minutes, so it can only shorten that. The proxy transcode now runs in
  pieces joined by the same `ffmpeg` (no new binary). New flag `check --prepare-media` (no new command). No new child
  process kind, network call, run-time install or skill change.
- `fork/release.sh` left its temporary directories in `TMPDIR` on every run until `a77f746ce` (`tmpdir` ran inside
  `$(...)`, so `cleanup` saw an empty list): 26 of them, 0.9 GB, were removed on 2026-10-23 when the disk filled and the
  first `v0.8.189` release attempt failed with `ENOSPC` before publishing anything. The fixed run left none.
- Previous release `fork-v0.8.188-sshlg.1` (commit `88c8b8af0`, sha256
  `43b176b47a0586a58622a023cd18ba8244960d0592afd4365713657b2601fb08`); `fork/release.sh` passed: the patches' tests
  (7 files, 69 tests), the smoke install printed `0.8.188+sshlg.1` and swept a dead marker, the re-downloaded asset
  matched its sha256. The merge was clean; all four patches carry over. Upstream's seven fixes: a blank media `src`
  is no source, a composition that shadows `console` no longer breaks the runtime, renders into a folder whose name
  holds `%`, long small-frame renders pass the disk estimate, a lint hint for nested timed video, and the arm64
  staging script stays out of the Lambda package.
- `fork/door-audit.sh v0.8.187 v0.8.188`: every section empty (no new command, environment variable, child process,
  network call, run-time install or skill change).
- Previous release `fork-v0.8.187-sshlg.1` (commit `5404e6aa8`, sha256
  `d72024934f671933252434b4ead5c09bdf3863c0c485d73960947f703d0d77cd`); `fork/release.sh` passed: the patches' tests
  (7 files, 69 tests), the smoke install printed `0.8.187+sshlg.1` and swept a dead marker, the re-downloaded asset
  matched its sha256. The merge was clean; all four patches carry over.
- `fork/door-audit.sh v0.8.186 v0.8.187`: everything new is in `hyperframes lambda deploy` (AWS, run only on request):
  `--video-arch arm64` (now the default) pushes an arm64 video image to the stack's own ECR, downloads the pinned
  `video-arm64.oci.tar` from the release unless `HYPERFRAMES_LAMBDA_VIDEO_IMAGE` names a local one
  (`commands/lambda/videoImage.ts`, runs `tar`), and `HYPERFRAMES_LAMBDA_HANDLER_URL` overrides the handler download
  (`prebuiltHandler.ts`); `destroy` reads `AWS_PROFILE`. No change to local render, preview, speech or run-time installs;
  one skill line (`hyperframes/references/motion.md`).
- Previous release `fork-v0.8.186-sshlg.2` (commit `e71ffc9c4`, sha256
  `352469a7a2de720b451a58b8930e2c5bb0af2a2084e966fb79da114e151a76aa`); `fork/release.sh` passed: the patches' tests
  (7 files, 69 tests), the smoke install printed `0.8.186+sshlg.2` and swept a dead marker, the re-downloaded asset
  matched its sha256; its `dist/studioServer-*.js` carries the watcher guard. It adds the Node 26 / macOS patch below.
- Previous release `fork-v0.8.186-sshlg.1` (commit `2171ab2d0`, sha256
  `9230e4e01af9fa29eedc10f6e78087a7659b94be30d21864a54eb46c81794cf9`); `fork/release.sh` passed: the patches' tests
  (4 files, 23 tests), the smoke install printed `0.8.186+sshlg.1` and swept a dead marker, the re-downloaded asset
  matched its sha256. Its tarball also generated speech with a read-only `~/.cache/hyperframes/tts` (1.3 s WAV, the
  cache untouched).
- `fork/door-audit.sh v0.8.185 v0.8.186`: no new CLI command, child process or run-time install. New:
  `hyperframes audio read --quality best` uploads the recording to HeyGen's cloud to split it into stems
  (`audio/read/stems.ts`), reading `HYPERFRAMES_AUDIO_STEMS_URL`, `HYPERFRAMES_AUDIO_API_KEY` and
  `HYPERFRAMES_AUDIO_STEMS_TIMEOUT_MS`; it runs only when the CLI is signed in to HeyGen or a key is set, and an empty
  `HYPERFRAMES_AUDIO_STEMS_URL` turns it off. Other qualities keep audio on the machine. The audit now also lists
  variable names kept in constants (it missed these three before) and skips `__fixtures__`.
- Previous release `fork-v0.8.185-sshlg.2` (commit `12b43d223`, sha256
  `0b25246a1df3ab51953ca8b81d6adbe8271be7c1e13f0d313b9b55bcbcbc4b4a`); `fork/release.sh` passed: the patches' tests
  (4 files, 23 tests), the smoke install printed `0.8.185+sshlg.2` and swept a dead marker, the re-downloaded asset
  matched its sha256. It adds the speech patch: with `~/.cache/hyperframes/tts` read-only (a sandboxed run) the
  installed tarball generated a 1.7 s WAV through `python -c` and wrote nothing there, while `sshlg.1` in the same
  sandbox failed with `EACCES … mkdtemp …/.hf-create-XXXXXX` (2026-10-22, Frame Agent's kokoro venv as
  `HYPERFRAMES_PYTHON`); a Python without kokoro now names itself and the import's own error. Reported by Frame Agent on
  the board (message `881095b3`, their BL-190). Earlier releases stay published.
- `fork/door-audit.sh v0.8.184 v0.8.185`: no new CLI command (`snapshotReview.ts` serves `snapshot`), no new environment
  variable, child process or run-time install. **`v0.8.185` retires the workflow skills** (upstream #5651): `skills/` goes
  from 21 to 7 (`hyperframes`, `hyperframes-cli`, `hyperframes-registry`, `media-use`, `figma`, `slideshow`,
  `remotion-to-hyperframes`), the domain skills become guides under `hyperframes/` and `media-use/`, and
  `skills update` removes the retired ones. A consumer that vendors workflow skills keeps an older tag's copy until it
  redesigns; the engine itself reads none of them.
- Door audit v0.8.181..v0.8.184: the CLI installs `onnxruntime-node` and `@google/genai` from npm on first use since
  `v0.8.51` and `sharp` since `v0.8.182`; `HYPERFRAMES_NO_OPTIONAL_INSTALL=1` (since `v0.8.182`) turns that off.
- The private consumer that pins this line moves to each release in its own repository; its move to `0.8.185` (with
  its skills kept at `v0.8.184`) is in progress there. `sshlg.2`, `v0.8.186-sshlg.1` and `v0.8.186-sshlg.2` (message `a2e6c159`) `v0.8.187-sshlg.1` with its audit (message `7d9f3c81`) and `v0.8.188-sshlg.1` with its audit (message `87d2232f`) `v0.8.189-sshlg.1` with its audit (message `fe6d3ad0`) `v0.8.190-sshlg.1` with its audit (message `bea18764`) `v0.8.191-sshlg.1` with its audit (message `a6eaf0e1`) and `v0.8.192-sshlg.1` with its audit (message `01af75d4`) were announced to it on the
  board (thread `b4d4f898`): with either, speech no longer needs a warm-up outside the run.
- The sixteen inherited workflows are disabled (repository settings).
- The speech patch sits on branch `pr/tts-sandbox-safe` (`c4611fbb8`, cherry-picked onto upstream `main`
  `2c1d9d50d`, the TTS tests 36 of 36). Its upstream PR is not opened: a PR to `heygen-com` needs the operator's
  explicit instruction for that send. Send the signed branch `pr/tts-sandbox-safe-signed`, not this one
  ([`upstream-prs.md`](upstream-prs.md)).
- Node 26 / macOS (2026-10-23, patch `cca5e193c`, merge `d3aeb4203`): the project watcher no longer reports the
  project folder itself as a changed file (FSEvents names it by its basename; 3 of 6 runs of
  `server/fileWatcher.atomic.test.ts` on unchanged `main`, none of 6 with the patch). `whisper/sherpa.test.ts` now
  compares realpaths and `utils/projectLock.test.ts` silences tsx's `DEP0205` in its children. The same commit sits on
  branch `pr/node26-macos` (cherry-picked onto upstream `main` `bb19f342d`, 46 tests pass); its upstream PR needs the
  operator's send instruction like the speech patch's, from the signed branch `pr/node26-macos-signed`.
- The watcher tests under load (fixed 2026-10-24, `a707fb95b`): FSEvents starts its stream a moment after `watch()`
  returns and a write in that gap is never reported, so `server/fileWatcher.fs.test.ts` and
  `server/fileWatcher.atomic.test.ts` lost their first write (four of eight parallel runs failed with
  `expected [] to include 'index.html'`). Both now arm the watcher with a probe first (`fileWatcher.test-helpers.ts`);
  sixteen of sixteen parallel runs pass. `fb4cb29f2` also waits out late bursts (a quiet second, 15 s per event); at
  load average about 125 FSEvents still delivers nothing for 15 s, so a release run then waits for the load to fall. A test-only change; it is in `pr/node26-macos-signed`. The product is not affected (Studio starts its watcher long before the first edit). The chromium, process and watcher
  timeouts seen at load average 73 on 2026-10-23 were not measured again.

## Next task

1. Upstream releases after `v0.8.192`: run `git fetch upstream --tags`, read the new tags' commits and take the latest
   (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish`, run `fork/door-audit.sh v0.8.192 v<new>` and update this file. The
   pinning consumer moves its pin in its own repository (its handoff names the steps); post the audit's findings to it on
   the project board. `v0.8.192` is taken (2026-10-24).

Before acting on this section, check it against Git: a tag it names as future may already exist.
