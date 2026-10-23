# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-23)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the
  `ssheleg` organisation on 2026-10-19; GitHub redirects the old address, release downloads included).
- `main` = upstream `v0.8.187` (merge `5404e6aa8`; before it `v0.8.186` merge `2171ab2d0`, `v0.8.185` merge `b0bd45480`, `v0.8.184` merge `66bfeedd2`, `v0.8.181` merge `2fb047c8a`,
  `v0.8.180` merge `8595a06f6`) + the running-markers sweep (`cbe3ca66a`) + the speech patch (`118a29e52`) + the Node 26 / macOS patch (`cca5e193c`) + `fork/`; `upstream` mirrors HeyGen's `main`.
- Latest release `fork-v0.8.187-sshlg.1` (commit `5404e6aa8`, sha256
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
  its skills kept at `v0.8.184`) is in progress there. `sshlg.2`, `v0.8.186-sshlg.1` and `v0.8.186-sshlg.2` (message `a2e6c159`) and `v0.8.187-sshlg.1` with its audit (message `7d9f3c81`) were announced to it on the
  board (thread `b4d4f898`): with either, speech no longer needs a warm-up outside the run.
- The sixteen inherited workflows are disabled (repository settings).
- The speech patch sits on branch `pr/tts-sandbox-safe` (`c4611fbb8`, cherry-picked onto upstream `main`
  `2c1d9d50d`, the TTS tests 36 of 36). Its upstream PR is not opened: a PR to `heygen-com` needs the operator's
  explicit instruction for that send. With it: `gh pr create -R heygen-com/hyperframes --head ssheleg:pr/tts-sandbox-safe`.
- Node 26 / macOS (2026-10-23, patch `cca5e193c`, merge `d3aeb4203`): the project watcher no longer reports the
  project folder itself as a changed file (FSEvents names it by its basename; 3 of 6 runs of
  `server/fileWatcher.atomic.test.ts` on unchanged `main`, none of 6 with the patch). `whisper/sherpa.test.ts` now
  compares realpaths and `utils/projectLock.test.ts` silences tsx's `DEP0205` in its children. The same commit sits on
  branch `pr/node26-macos` (cherry-picked onto upstream `main` `bb19f342d`, 46 tests pass); its upstream PR needs the
  operator's send instruction like the speech patch's: `gh pr create -R heygen-com/hyperframes --head ssheleg:pr/node26-macos`.
- Not blocking, still open: under load (load average 73) `server/fileWatcher.atomic.test.ts` and
  `server/fileWatcher.fs.test.ts` sometimes hear nothing (`expected [] to include 'index.html'`) on unchanged `main` too:
  FSEvents starts late and misses the first write; chromium, process and watcher tests also time out under load.
- Upstream PR heygen-com/hyperframes#5790 (the same sweep) is open, no reviews; its head `3878df714` still merges
  cleanly onto upstream `main` (`git merge-tree`, 2026-10-20). We do not wait for it.

## Next task

1. Upstream releases after `v0.8.187`: run `git fetch upstream --tags`, read the new tags' commits and take the latest
   (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish`, run `fork/door-audit.sh v0.8.187 v<new>` and update this file. The
   pinning consumer moves its pin in its own repository (its handoff names the steps); post the audit's findings to it on
   the project board. `v0.8.187` is taken (2026-10-23).

Before acting on this section, check it against Git: a tag it names as future may already exist.
