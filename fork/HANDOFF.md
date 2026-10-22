# HANDOFF: HyperFrames Agent

## Objective

Run our own line of the HyperFrames engine: take upstream releases when they help, carry our patches, and
publish tarball releases that consumers pin.

## State (2026-10-22, evening)

- Repository `ssheleg/hyperframes-agent` (renamed from `sshlg/heygen-hyperframes-vr` and moved to the
  `ssheleg` organisation on 2026-10-19; GitHub redirects the old address, release downloads included).
- `main` = upstream `v0.8.185` (merge `b0bd45480`; before it `v0.8.184` merge `66bfeedd2`, `v0.8.181` merge `2fb047c8a`,
  `v0.8.180` merge `8595a06f6`) + the running-markers sweep (`cbe3ca66a`) + the speech patch (`118a29e52`) + `fork/`; `upstream` mirrors HeyGen's `main`.
- Latest release `fork-v0.8.185-sshlg.2` (commit `12b43d223`, sha256
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
  its skills kept at `v0.8.184`) is in progress there. `sshlg.2` was announced to it on the board (thread `b4d4f898`):
  with it, speech no longer needs a warm-up outside the run.
- The sixteen inherited workflows are disabled (repository settings).
- The speech patch sits on branch `pr/tts-sandbox-safe` (`c4611fbb8`, cherry-picked onto upstream `main`
  `2c1d9d50d`, the TTS tests 36 of 36). Its upstream PR is not opened: a PR to `heygen-com` needs the operator's
  explicit instruction for that send. With it: `gh pr create -R heygen-com/hyperframes --head ssheleg:pr/tts-sandbox-safe`.
- Not blocking, found 2026-10-22: on this Mac (Node 26.10, macOS) some inherited CLI tests fail on clean `main` too:
  `whisper/sherpa.test.ts` (expects `/var/...`, gets the realpath `/private/var/...`), `utils/projectLock.test.ts`
  (Node's `DEP0205` warning on the child's stderr), `server/fileWatcher.atomic.test.ts`; under load (146) also
  chromium, process and watcher tests time out. Upstream CI runs another Node; fix upstream or when Node 26 is the target.
- Upstream PR heygen-com/hyperframes#5790 (the same sweep) is open, no reviews; its head `3878df714` still merges
  cleanly onto upstream `main` (`git merge-tree`, 2026-10-20). We do not wait for it.

## Next task

1. Upstream releases after `v0.8.185`: run `git fetch upstream --tags`, read the new tags' commits and take the latest
   (fork/README.md, "Taking an upstream release"), then `fork/release.sh 1 --publish`, run `fork/door-audit.sh v0.8.185 v<new>` and update this file. The
   pinning consumer moves its pin in its own repository (its handoff names the steps); post the audit's findings to it on
   the project board.

Before acting on this section, check it against Git: a tag it names as future may already exist.
