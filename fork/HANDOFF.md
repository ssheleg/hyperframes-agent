# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-27)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the `ssheleg`
  organisation on 2026-10-19; GitHub redirects the old address, release downloads included). The sixteen inherited
  workflows are disabled (repository settings).
- `main` = upstream `v0.8.206` (merge `34ae91a84`) + two patches + `fork/`. `git diff v0.8.206 main -- . ':!fork'` shows
  exactly what we carry: the speech patch (`packages/cli/src/tts/`) and the Node 26 / macOS patch with its watcher test
  fixes (`packages/cli/src/server/fileWatcher*`, `utils/projectLock.test.ts`, `whisper/sherpa.test.ts`), plus our
  header in `CLAUDE.md`, `AGENTS.md` and `README.md`. `upstream` mirrors HeyGen's `main`.
- Latest release `fork-v0.8.206-sshlg.1` (table below); it carries `v0.8.199` to `v0.8.205`, which were not released
  on their own. Upstream changed none of our patches' files in `v0.8.198..v0.8.206`, so the merge was clean (the
  `fallow` hook did not run: `git merge` committed it).
- **The running-markers sweep is upstream's now.** heygen-com/hyperframes#5790 was approved and merged on 2026-10-24
  (merge `24965372d`, in `v0.8.193`), so the line no longer carries it: `runningCli.ts` and its test are byte-identical
  to the tag. Getting it in took a signed commit (`heygen-com` requires them; ours were authored `Робот <r@e.com>`) and a
  CodeQL fix in its test; on the operator's word the PR's head was force-updated with a lease. The other two fixes wait
  as signed branches for the operator's send instruction: [`upstream-prs.md`](upstream-prs.md).
- The pinning consumer, Frame Agent, moves its pin in its own repository. On 2026-10-24 it pinned
  `fork-v0.8.192-sshlg.1` (`ssheleg/frame-agent` `main` `e7a61cd7a`, `package.json`). Every release is announced to it
  on the project board, thread `b4d4f898`, with its door audit; `v0.8.193-sshlg.1` is message `7b997544`,
  `v0.8.198-sshlg.1` is message `d9a91a4f`, `v0.8.206-sshlg.1` is message `1368c271`.

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

## Releases

Every release is a GitHub Release of this repository with the tarball and its `.sha256` (read back from the assets
on 2026-10-25).

| Release                 | Commit      | Date       | sha256                                                             |
| ----------------------- | ----------- | ---------- | ------------------------------------------------------------------ |
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

| Range                | Finding                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| up to `v0.8.184`     | The CLI installs `onnxruntime-node` and `@google/genai` from npm on first use since `v0.8.51` and `sharp` since `v0.8.182`; `HYPERFRAMES_NO_OPTIONAL_INSTALL=1` (since `v0.8.182`) turns that off.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `v0.8.184..v0.8.185` | The workflow skills are retired (upstream #5651): `skills/` goes from 21 to 7 and `skills update` removes the retired ones. A consumer that vendors them keeps an older tag's copy; the engine reads none of them.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `v0.8.185..v0.8.186` | `audio read --quality best` uploads the recording to HeyGen's cloud for stems (`audio/read/stems.ts`), reading `HYPERFRAMES_AUDIO_STEMS_URL`, `HYPERFRAMES_AUDIO_API_KEY`, `HYPERFRAMES_AUDIO_STEMS_TIMEOUT_MS`; only when signed in or keyed, and an empty URL turns it off.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `v0.8.186..v0.8.187` | All in `lambda deploy` (AWS, on request): `--video-arch arm64` (the default) pushes an arm64 image to the stack's ECR and downloads `video-arm64.oci.tar` unless `HYPERFRAMES_LAMBDA_VIDEO_IMAGE` names one (runs `tar`); `HYPERFRAMES_LAMBDA_HANDLER_URL`; `AWS_PROFILE`. New `--page-motion-blur`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `v0.8.188..v0.8.189` | `HYPERFRAMES_PROXY_CACHE_STALE_TEMP_MS` (studio-server proxy cache; default and ceiling 10 minutes); proxy transcodes run in pieces joined by the same `ffmpeg`; new flag `check --prepare-media`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `v0.8.190..v0.8.191` | Skills: `snapshot --range` is written `START,END`, `--fps` takes 1 to 240 or a rational, the `hyperframes usage --json` section left `upgrade-info-misc.md`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `v0.8.191..v0.8.192` | A stderr notice after `render`, `lint` and `validate` when skills are stale (silenced by `HYPERFRAMES_SKIP_SKILLS=1` or `HYPERFRAMES_NO_UPDATE_CHECK`); `init` no longer touches installed skills; `history` runs `git diff --no-index`; the engine runs `tasklist` on Windows.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `v0.8.192..v0.8.193` | The engine fetches stored ffprobe facts for remote `http(s)` media (`utils/ffprobe.ts`, 10 s timeout), declared only by the distributed (cloud/Lambda) plan (`producer/src/services/distributed/plan.ts:1214`); `HF_TAIL_PROBE_SLOTS` (default 16).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `v0.8.193..v0.8.198` | `HYPERFRAMES_GSAP_BASE_URL` names an npm mirror (HTTPS, or HTTP on localhost) that renders and Studio preview load GSAP from; Studio preview now uses the CLI's bundled GSAP by default (#6256). The Chrome download moved into a child process (Node running the CLI's `renderSetupWorker.js browser-install`, `utils/cancellableProcess.ts`; same download source). Orphan cleanup kills only browsers carrying HyperFrames' launch marker; `HYPERFRAMES_NO_ORPHAN_CLEANUP=1` turns it off.                                                                                                                                                                                                                                                                                                    |
| `v0.8.198..v0.8.206` | New CLI: `hyperframes <dir>` opens the project (`open`); `lambda deploy --warm`, `--width`, `--height` (runs `aws`). A killed CLI's children are ended by a Node child it spawns (`utils/childReaper.ts`, #6431). Media grading runs `ffprobe`/`ffmpeg` (`core/src/mediaGradeAnalyzer.ts`, `HYPERFRAMES_ANALYZE_TIMEOUT_MS`); the engine reads `vm_stat` on macOS; Studio history runs `ps`. New `fetch` calls stay local: same-origin composition scripts in the page (`engine/src/services/frameCapture.ts:2104`), the preview server for `check` findings, the proxy in the runtime. `HF_DE_PARALLEL_ROUTER`, `HF_DE_PAR_DEBUG` (render); telemetry recognises OpenClaw by `OPENCLAW_CONFIG_PATH`. Skills: 13 files (runtimes, launch, media-use memory and mixing, remotion-to-hyperframes). |

## Next task

1. Moving to a private repository of the team organisation is being prepared on the project board (thread `3b676949`):
   nothing moves until the coordinator accepts the audit. The audit (message `fba92970`) found no secrets in our
   commits; the operator's own address is in one upstream commit, `24965372d` (it cannot be rewritten without breaking
   upstream merges), and in the two `pr/*-signed` branches (they stay here). A fork of a public repository cannot be
   private, so the move is a new repository, not a fork. Wait for the coordinator's answer there.
2. Upstream releases after `v0.8.206`: run `git fetch upstream --tags`, read the new tags' commits and take the latest
   (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish`, run
   `fork/door-audit.sh v0.8.206 v<new>`, add its findings to the table above and the release to the release table, and
   post them to the consumer on the board (thread `b4d4f898`). `v0.8.206` is taken (2026-10-27).
3. On the operator's send instruction only: the two upstream PRs in [`upstream-prs.md`](upstream-prs.md).

Before acting on this section, check it against Git: a tag it names as future may already exist.
