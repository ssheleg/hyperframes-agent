# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

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
  `86579635`, `v0.9.8-sshlg.1` is message `df1eb3a2`, `v0.9.9-sshlg.1` is message `f1e3e2b3`, `v0.9.10-sshlg.1` is message `4f9bb9ec`, `v0.9.11-sshlg.1` is message `c1b84a77`, `v0.9.12-sshlg.1` is message `15cb59f9`, `v0.9.13-sshlg.1` is message `4fd9d660`.

## Patches

- **Speech** (`118a29e52`, since `fork-v0.8.185-sshlg.2`): with `~/.cache/hyperframes/tts` read-only (a sandboxed run)
  speech runs the synthesis script through `python -c` instead of failing on `mkdtemp`; a Python without kokoro names
  itself and the import's own error. Reported by Frame Agent (board message `881095b3`, their BL-190).
- **Node 26 / macOS** (`cca5e193c`, since `fork-v0.8.186-sshlg.2`): the project watcher no longer reports the project
  folder itself as a changed file (FSEvents names it by its basename); `whisper/sherpa.test.ts` compares realpaths and
  `utils/projectLock.test.ts` silences tsx's `DEP0205` in its children.
- **Watcher tests under load** (`a707fb95b`, `fb4cb29f2`): FSEvents starts its stream a moment after `watch()` returns,
  and a write in that gap is never reported; the real-file-system watcher tests now arm the watcher with a probe and
  wait out late bursts (four of eight parallel runs failed before, sixteen of sixteen pass after). When `fseventsd`
  itself is busy, FSEvents delivers nothing for 15 s and these tests fail: at load average 125 with `fseventsd` at 120%
  CPU (2026-10-24), and again at load average 54 with `fseventsd` at 224% (2026-10-25, the first `v0.8.198` publish run;
  the check run minutes earlier had passed). So the signal is `fseventsd`'s own CPU, not the load average: before
  `--publish`, wait until `ps -Ao pcpu,comm | grep fseventsd` reads under 60%, rather than retrying.

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

## Releases

Every release is a GitHub Release of this repository with the tarball and its `.sha256` (read back from the assets
on 2026-10-25).

| Release                 | Commit      | Date       | sha256                                                             |
| ----------------------- | ----------- | ---------- | ------------------------------------------------------------------ |
| `fork-v0.9.13-sshlg.1`  | `fdfd05e84` | 2026-11-04 | `cd73bc5614c3dce16d6eba5b278ce6af001d0a60f500912e2c7175a7bc545b5d` |
| `fork-v0.9.12-sshlg.1`  | `15dc2bc03` | 2026-11-04 | `466203881c4ce473c5d123f577a4b40018f989b7c8caa6275db2407fafe29ddc` |
| `fork-v0.9.11-sshlg.1`  | `96165a7ad` | 2026-11-04 | `b81ca2ac3765df6d611fd130b28e1a1c333c982f3861342881dfb0903b0dc16f` |
| `fork-v0.9.10-sshlg.1`  | `ccfd9e3e6` | 2026-11-04 | `a48e6e56231bc5ef46c970caecdaecdf6526c75378d8b9814bd328dfac42ccdc` |
| `fork-v0.9.9-sshlg.1`   | `7c3effd87` | 2026-11-03 | `193cc9c6204ad4078f50fa0e31d8e6eba40457832dacfdd7bc554057687b9049` |
| `fork-v0.9.8-sshlg.1`   | `6d560e1a9` | 2026-11-03 | `bf2db790b1462f81cfef67af128e37358fb58689bfca91c9f1d0c2cfe45062a1` |
| `fork-v0.9.5-sshlg.1`   | `7385d1f55` | 2026-11-02 | `219ca565c3dffaba015014fa8eebafbd06e9745713e5502bf38a1c998027a42b` |
| `fork-v0.8.231-sshlg.1` | `48bfa23ae` | 2026-11-02 | `2b9cbfca19d565c0503a68d5b5bbca4c9ec539026f400f4a971c2262a41fcd91` |
| `fork-v0.8.221-sshlg.1` | `4ca03a605` | 2026-10-30 | `a634e472f0296efdd8a21f8fe1276cece7e47c5cb89026f58948a975a7703a5f` |
| `fork-v0.8.210-sshlg.1` | `2119b8418` | 2026-10-28 | `df14cf52b2d857e17d833dfeffdf6ee620997c2934aa15829e50033c670ca0b7` |
| `fork-v0.8.206-sshlg.1` | `34ae91a84` | 2026-10-27 | `176dcab03c90dd6b23e9b6097ec62631f1b25998e46d5665edb583e0df83f552` |
| `fork-v0.8.198-sshlg.1` | `44ad52549` | 2026-10-25 | `6d9a2e895ee6d6fb7f285cfc64fac9f90dc6893f0c61483bfd3a162d2ed7095c` |
| `fork-v0.8.193-sshlg.1` | `ba2c1fe96` | 2026-10-25 | `ebce0e37f67e4f2558e4bcd19fb9dd693b0e4ef810d9272edfdb8c2e7b1dac4a` |
| `fork-v0.8.192-sshlg.1` | `3f163dc52` | 2026-10-24 | `c3c9f9ee14dd9c9da1e42eb2b662b9c8d0813ec1f33359de7c3830d44b5d684d` |
| `fork-v0.8.191-sshlg.1` | `fb4cb29f2` | 2026-10-24 | `d493a09c0f53ebb08fdcade0dd87bc84192c881987415df735c296ef016f9d37` |
| `fork-v0.8.190-sshlg.1` | `e20c025a1` | 2026-10-24 | `9d7577e59ad2b3fb52e64cc3865835e7244f083fdbdd8f6ba556742df9f9f8c4` |
| `fork-v0.8.189-sshlg.1` | `a77f746ce` | 2026-10-23 | `c1eaca752f4c0e5b46acc31f4bc713cbae6c7b380ade4242bad7ab7ce46bb1f0` |
| `fork-v0.8.188-sshlg.1` | `88c8b8af0` | 2026-10-23 | `43b176b47a0586a58622a023cd18ba8244960d0592afd4365713657b2601fb08` |
| `fork-v0.8.187-sshlg.1` | `5404e6aa8` | 2026-10-23 | `d72024934f671933252434b4ead5c09bdf3863c0c485d73960947f703d0d77cd` |
| `fork-v0.8.186-sshlg.2` | `e71ffc9c4` | 2026-10-23 | `352469a7a2de720b451a58b8930e2c5bb0af2a2084e966fb79da114e151a76aa` |
| `fork-v0.8.186-sshlg.1` | `2171ab2d0` | 2026-10-22 | `9230e4e01af9fa29eedc10f6e78087a7659b94be30d21864a54eb46c81794cf9` |
| `fork-v0.8.185-sshlg.2` | `12b43d223` | 2026-10-22 | `0b25246a1df3ab51953ca8b81d6adbe8271be7c1e13f0d313b9b55bcbcbc4b4a` |
| `fork-v0.8.185-sshlg.1` | `b0bd45480` | 2026-10-22 | `9ac5379a40900436d8ef19525086ee6b16f583a58185e32282fd07591f747be5` |
| `fork-v0.8.184-sshlg.1` | `66bfeedd2` | 2026-10-21 | `0787016464639fd9a0dd69d0ed5d11bb18e987230f789a48be315c3c971aa597` |
| `fork-v0.8.181-sshlg.1` | `2fb047c8a` | 2026-10-21 | `3a61ad3809dedf9b70e9b9150518b9bb4d9fee5596408c5c40921b6b1b6e34ab` |
| `fork-v0.8.180-sshlg.1` | `8595a06f6` | 2026-10-20 | `72d5b034513b0a41c160aeca57f796f9929c2dd8b9a615282bf439dbcd8103e4` |
| `fork-v0.8.174-sshlg.1` | `3146a2f73` | 2026-10-19 | `7d53662e673cb3a63ce82239fe0c2804e9707d544386789553e67d89d16efafc` |
| `fork-v0.8.170-sshlg.1` | `4f3420c3f` | 2026-10-19 | `1ea79c72244907cf21375360a9570b9364cba105184320661b3f18d9dc6e67db` |

## Door audit findings

What `fork/door-audit.sh <from> <to>` found that a confining consumer must know. A range not listed found nothing.

| Range                | Finding                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| up to `v0.8.184`     | The CLI installs `onnxruntime-node` and `@google/genai` from npm on first use since `v0.8.51` and `sharp` since `v0.8.182`; `HYPERFRAMES_NO_OPTIONAL_INSTALL=1` (since `v0.8.182`) turns that off. Since `v0.8.182` (#5943) a `check` run with neither stdout nor stderr a terminal and no `CI` in its environment starts a detached Node child (`warmCheckClient.ts:138`) that keeps the CLI and Chrome up for 5 minutes (`WARM_IDLE_MS`) for the next `check`; `CI=1` turns it off. The audits missed it until 2026-10-27, when `door-audit.sh` began listing detached and unref'd children.                                                                                                                                                                                                                                                                 |
| `v0.8.184..v0.8.185` | The workflow skills are retired (upstream #5651): `skills/` goes from 21 to 7 and `skills update` removes the retired ones. A consumer that vendors them keeps an older tag's copy; the engine reads none of them.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `v0.8.185..v0.8.186` | `audio read --quality best` uploads the recording to HeyGen's cloud for stems (`audio/read/stems.ts`), reading `HYPERFRAMES_AUDIO_STEMS_URL`, `HYPERFRAMES_AUDIO_API_KEY`, `HYPERFRAMES_AUDIO_STEMS_TIMEOUT_MS`; only when signed in or keyed, and an empty URL turns it off.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `v0.8.186..v0.8.187` | All in `lambda deploy` (AWS, on request): `--video-arch arm64` (the default) pushes an arm64 image to the stack's ECR and downloads `video-arm64.oci.tar` unless `HYPERFRAMES_LAMBDA_VIDEO_IMAGE` names one (runs `tar`); `HYPERFRAMES_LAMBDA_HANDLER_URL`; `AWS_PROFILE`. New `--page-motion-blur`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `v0.8.188..v0.8.189` | `HYPERFRAMES_PROXY_CACHE_STALE_TEMP_MS` (studio-server proxy cache; default and ceiling 10 minutes); proxy transcodes run in pieces joined by the same `ffmpeg`; new flag `check --prepare-media`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `v0.8.190..v0.8.191` | Skills: `snapshot --range` is written `START,END`, `--fps` takes 1 to 240 or a rational, the `hyperframes usage --json` section left `upgrade-info-misc.md`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `v0.8.191..v0.8.192` | A stderr notice after `render`, `lint` and `validate` when skills are stale (silenced by `HYPERFRAMES_SKIP_SKILLS=1` or `HYPERFRAMES_NO_UPDATE_CHECK`); `init` no longer touches installed skills; `history` runs `git diff --no-index`; the engine runs `tasklist` on Windows.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `v0.8.192..v0.8.193` | The engine fetches stored ffprobe facts for remote `http(s)` media (`utils/ffprobe.ts`, 10 s timeout), declared only by the distributed (cloud/Lambda) plan (`producer/src/services/distributed/plan.ts:1214`); `HF_TAIL_PROBE_SLOTS` (default 16).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `v0.8.193..v0.8.198` | `HYPERFRAMES_GSAP_BASE_URL` names an npm mirror (HTTPS, or HTTP on localhost) that renders and Studio preview load GSAP from; Studio preview now uses the CLI's bundled GSAP by default (#6256). The Chrome download moved into a child process (Node running the CLI's `renderSetupWorker.js browser-install`, `utils/cancellableProcess.ts`; same download source). Orphan cleanup kills only browsers carrying HyperFrames' launch marker; `HYPERFRAMES_NO_ORPHAN_CLEANUP=1` turns it off.                                                                                                                                                                                                                                                                                                                                                                  |
| `v0.8.198..v0.8.206` | New CLI: `hyperframes <dir>` opens the project (`open`); `lambda deploy --warm`, `--width`, `--height` (runs `aws`). A killed CLI's children are ended by a Node child it spawns (`utils/childReaper.ts`, #6431). Media grading runs `ffprobe`/`ffmpeg` (`core/src/mediaGradeAnalyzer.ts`, `HYPERFRAMES_ANALYZE_TIMEOUT_MS`); the engine reads `vm_stat` on macOS; Studio history runs `ps`. New `fetch` calls stay local: same-origin composition scripts in the page (`engine/src/services/frameCapture.ts:2104`), the preview server for `check` findings, the proxy in the runtime. `HF_DE_PARALLEL_ROUTER`, `HF_DE_PAR_DEBUG` (render); telemetry recognises OpenClaw by `OPENCLAW_CONFIG_PATH`. Skills: 13 files (runtimes, launch, media-use memory and mixing, remotion-to-hyperframes).                                                               |
| `v0.8.206..v0.8.210` | New flags `capture --local-file <html>` and `--local-root <dir>` (the page reads files under that root), `media-treatment --grading`. `HYPERFRAMES_CAPTURE_PROXY` routes `capture` through an upstream proxy (off by default, #6499). `HYPERFRAMES_HANG_REPORT`, `HYPERFRAMES_NO_PREVIEW_DISCOVERY`; preview records go to `XDG_STATE_HOME` on Linux and `LOCALAPPDATA` on Windows (#6461). Chrome is started by `spawn` with a host ceiling probe (`chromeStartup.ts`, `chromeHostCeiling.ts`, #6547, #6516). No children outlive their command. Skills: 10 files.                                                                                                                                                                                                                                                                                            |
| `v0.8.210..v0.8.221` | Dedicated OAuth clients (#6687): `HYPERFRAMES_OAUTH_{AUTHORIZE,TOKEN,DEVICE,REVOKE}_URL`, `HYPERFRAMES_OAUTH_CLIENT_ID`, `HYPERFRAMES_ENV`, `HYPERFRAMES_CONFIG_DIR`. Downloads honour `HTTPS_PROXY` through `undici` (`core/src/envProxy.ts`, `NODE_USE_ENV_PROXY`) and refuse hosts that resolve to private addresses (#6571). The background self-update no longer runs when nobody is at the terminal (#6617; `HYPERFRAMES_NO_AUTO_INSTALL=1`, `HYPERFRAMES_AGENT`, `CI`). `hyperframes open` can start the HyperFrames desktop app detached (`utils/desktopApp.ts:75`). `media-use` runs its engine in a Node child; AAC encoding runs `ffmpeg`. New workflow `windows-window-probe.yml` (disabled here). Lambda: `HYPERFRAMES_LAMBDA_RESERVED_CONCURRENCY`, `HYPERFRAMES_STITCH_FUNCTION`.                                                               |
| `v0.8.221..v0.8.231` | New commands `billing` (HeyGen plan and credits: `HYPERFRAMES_PLANS_URL`, `HYPERFRAMES_CREDITS_URL`), `diff`, `measure` (`curve`, `cuts`, `energy`, `events`, `extract`, `face`, `frames`, `ink`, `look`, `probe`, `sync`; they run `ffmpeg`) and `media-use generate` (paid HeyGen generation, `--max-credits`). `HYPERFRAMES_CACHE_DIR` moves every CLI cache, the speech script's included (#6716). The exit-time telemetry sender is a detached Node child (`telemetry/transport.ts:182`, there since upstream `v0.7.77`; `HYPERFRAMES_NO_TELEMETRY=1` turns telemetry off); optional `npm` installs now run in the cache folder. New workflow `player-safari-audio.yml` (disabled here). New skill `reverse-any-video`; `remotion-to-hyperframes` lost its `frame_strip.sh` and `render_diff.sh`.                                                         |
| `v0.8.231..v0.9.5`   | `v0.9.0` removes the Plan v1 distributed transport (Lambda, Cloud Run): a stack deployed from 0.8 is redeployed from 0.9. New flag `media-use generate --voice`, which lists voices from HeyGen's cloud (`heygen/v3.ts:273`, signed in only). No new commands, environment variables, outliving children, workflows or run-time installs. Skills: 7 files (`reverse-any-video` among them).                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `v0.9.5..v0.9.8`     | New command `reverse start` notes a reverse run with HeyGen (`heygen/reverse.ts`, `HYPERFRAMES_CLIENT` names the caller). `audio --read` describes audio through the HeyGen account when signed in, sending the audio as base64 to HeyGen's description service (`audio/read/describe.ts:144`) instead of needing a Gemini key. A `hyperframes auth login` session now outranks `HEYGEN_API_KEY` and `HYPERFRAMES_API_KEY`; `HEYGEN_API_BASE` marks a host's gateway (`auth/resolver.ts:114`). `auth login --device` works without a terminal (refused in CI). New flags `billing --feature`, `--session`, `reverse start --dir`; `cloud render` drops `--page-motion-blur`. `HF_INPAGE_ENCODE` (off by default, `engine/src/config.ts:310`). No outliving children, workflows or run-time installs. Skills: 9 files (`media-use` audio, `reverse-any-video`). |
| `v0.9.8..v0.9.9`     | New command `templates pull` (HyperFrames Pro style templates): signed in, it downloads an archive from HeyGen and unpacks it with `tar`, refusing absolute paths and `..` (`commands/templates.ts`). `media-use` finds assets: `--type`, `--intent`, `--entity`, `--provider`, `--from <file or URL>`, `--candidates`, `--reuse`, `--adopt`; `media-use generate --avatar`, `--prompt`, `--video`; `diff --offset`. Skills install from the CLI's own release tag and there is no auto-update across 0.x minors (#7013). No new environment variables, outliving children, workflows or run-time installs. Skills: new `style-sampling`.                                                                                                                                                                                                                      |
| `v0.9.9..v0.9.10`    | `billing top-up` is renamed `add-credits` with no alias. `billing` shows the price and on Enter creates a Stripe checkout with HeyGen and opens it in a browser (`commands/billing.ts:56`, `heygen/plan.ts:175`); the payment itself is the person's, in the browser, and without a terminal it only prints the checkout link (`billing.ts:50`). `CLAUDE_CONFIG_DIR` locates Claude Code's global skills (`utils/skillsManifest.ts:397`). `templates pull` unpacks from memory through `tar` and reuses only a template it pulled. No new commands, outliving children, workflows or run-time installs. Skills: 6 files.                                                                                                                                                                                                                                       |
| `v0.9.10..v0.9.11`   | New command `update`: `--check` only reports; without it, it reinstalls the CLI the way it was installed (`upgradeRunningCli`, `commands/update.ts:122`; npm, brew or the project's lockfile, `utils/installerDetection.ts`) and updates skills, and unattended without `--yes` it asks for a person (`update.ts:238`). For this line `update --yes` after the next upstream release would replace the line's build with npm's, so consumers should forbid it with `upgrade`. New `media-use voices --limit`; a credit limit the person names now holds on every paid media call (`skills/media-use/scripts/lib/credit-limit.mjs`). `HYPERFRAMES_PLUGIN_VERSION`. No outliving children or workflows.                                                                                                                                                          |
| `v0.9.11..v0.9.12`   | Nothing for a confining consumer: no new commands, flags, environment variables, children, network calls, workflows or run-time installs. A render whose page never becomes ready fails once with a plain reason. Skills: 15 files; they no longer tell the agent to install, update or remove skills (#7102).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `v0.9.12..v0.9.13`   | New command `media-use avatars --limit`: the avatar looks on the HyperFrames account, signed in only (`heygen/avatars.ts:75`). Network failures name the host (`utils/networkFailure.ts`, a wrapper around `fetch`, no new host). The desktop-app hint is no longer printed under CI or a pipe unless `HYPERFRAMES_AGENT=1` (`utils/desktopApp.ts`). No new environment variables, outliving children, workflows or run-time installs. Skills: 5 files.                                                                                                                                                                                                                                                                                                                                                                                                        |

## Next task

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
sha256 `4f27c68a969c1dd441a0c176ed33791b1d8a58590522ea0d9447446e782a754f`, the first under the new name); shared audit
`ready` on each; catalogued in
`appvillis-com/org-index` (`not_verified`); announced in thread `7913a557` (`9a842399`, `ea6dab16`, `6e9642a9`, `8e4adb91`, `59b98775`, `a00b8d3a`, `c4d9fa7a`, `91bf1b34`, `a8d4c425`). Frame Agent's copy
(`appvillis-com/frame-agent` `8d1b42e`) keeps the copy's tarball in its own `engine/` folder, because an anonymous
download of a private release answers 404; it moves to a new release by replacing that file (its message `091eca5f`). Its
checkout is `~/DATA/_worktrees/hyperframes-agent-org`. How it is refreshed: fork/README.md, "The team copy".

1. Upstream releases after `v0.9.13`: `fork/status.sh` names them. Read the new tags' commits and take the latest (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish`, run
   `fork/door-audit.sh v0.9.13 v<new>`, add its findings to the table above and the release to the release table, and
   post them to the consumer on the board (thread `b4d4f898`). The release disables any workflow the merge added
   (`fork/workflows-guard.sh`). Then refresh the team copy: `fork/export.sh ~/DATA/_worktrees/hyperframes-agent-org --push`, the
   shared audit to `ready`, `fork/release.sh 1 --publish` in the copy's checkout, and tell its consumers in thread
   `7913a557` (fork/README.md, "The team copy").
2. On the operator's send instruction only: the two upstream PRs in [`upstream-prs.md`](upstream-prs.md).

Before acting on this section, check it against Git: a tag it names as future may already exist.
