# Migration to the estate's agent model (2026-11-08)

The operator asked every agent of the estate to move to one model: one copy of each singleton on one machine, data
apart from the source, keys by name, an organization copy, heavy work on the second machine (project board, thread
`c1a45468`, from 2026-11-05; the agents base's template rules). This page says which of those items apply to a
library line that runs no service, what was done here and what waits. Kept out of the organization copy
(`fork/export.sh`).

## Items

| Item                                 | What the estate asks                                                                                                                                                 | Here                                                                                                                                                                                                                                                                                                                                                                                                                         | State                    |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| M-1 Placement                        | each singleton (scheduler, poller, gateway) has one host; it refuses to start where the placement record names another machine; its port is chosen free and recorded | no service, no LaunchAgent, no port, no scheduler: nothing runs between releases                                                                                                                                                                                                                                                                                                                                             | not applicable           |
| M-2 Peer gate                        | a service on a shared loopback refuses another account's connection before reading it                                                                                | no listener                                                                                                                                                                                                                                                                                                                                                                                                                  | not applicable           |
| M-3 Data apart from the source       | no instance data in the tree; data in the agent's data folder                                                                                                        | the agents base's finding F13 (2026-11-07): an exported session transcript sat at the repository root, excluded only by `.git/info/exclude`. Moved out to the line's local data folder on 2026-11-08 (`git status --ignored` lists no transcript). The data folder holds notes only, so no private data repository yet                                                                                                       | done                     |
| M-4 Keys by name                     | keys only in the credential store, read by name; no key files of the agent's own                                                                                     | the line holds no key: releases use the GitHub CLI's sign-in and Git over SSH                                                                                                                                                                                                                                                                                                                                                | nothing to move          |
| M-5 Organization copy                | a copy in the organization, rebuilt by export with `Source-Revision`, the organization's prefix and notice, audited for personal markers                             | done 2026-11-02 to 2026-11-05: `fork/export.sh`, its own releases `-appvillis.<n>` ([HANDOFF](HANDOFF.md), "Tooling (2026-11-02)")                                                                                                                                                                                                                                                                                           | done                     |
| M-6 Source check                     | the adapter's `fabric_source_check.py check` finds home paths, credentials and owner strings in a source tree                                                        | measured 2026-11-08 (adapter 0.62.0): 8962 files, 1130 findings, every one in upstream's tree except `fork/org/audit-allow-literals.txt`, which lists upstream's own placeholder paths on purpose. Not added to the release checks: they would fail on upstream's code; the copy's marker audit and gitleaks cover our files. `fabric.source.json` waits on the adapter's manifest (FAA-188 part 2); no peer carries one yet | measured, not applicable |
| M-7 Service contract                 | well-known descriptor, events, spend and load reports, dashboard, board responder, budget                                                                            | the agents base registers the line as `library-agent`, variant `engine-line`: not an agent                                                                                                                                                                                                                                                                                                                                   | not applicable           |
| M-8 Heavy work on the second machine | the heaviest builds and full gates run on the second machine, where the disk is                                                                                      | a release builds every workspace package and runs the patch tests; this machine had 5.9 GB free on 2026-11-08, under the 8 GB the estate asks of a release build                                                                                                                                                                                                                                                             | see below                |

## M-8: release builds on the second machine

Measured 2026-11-08 on the second machine (personal space): Git over SSH pushes, Node 26.12 and ffmpeg are installed,
Bun was not and is now (1.3.14, the version this machine builds with, in the user's home), the GitHub CLI's sign-in
there is invalid, 742 GB free. A check run (`fork/release.sh 2`, no publish) at `42ad14381` built every workspace
package, passed the patch tests (79 passed, 6 skipped, as here) and the smoke install in 2 min 39 s, dependencies
included; its tarball's sha256 (`05a2d0dd…b882b7`) was the same in a second run.

So the build and the tests move there and publishing stays here, where the GitHub CLI is signed in:
`fork/remote-build.sh <ssh-host> <n>` builds origin's `main` there and brings the tarball back, and
`fork/release.sh <n> --publish --prebuilt <tarball>` checks that it is this commit and version, runs the smoke install
and publishes ([README](README.md), "Release"). Checked on 2026-11-08 without publishing: the remote build at
`42ad14381`, then `--prebuilt` here (smoke passed), and five refusals: another release number, a tarball renamed to
another number, a byte appended, a missing file, a missing `.sha256`. The same day this machine's disk reached zero
during the smoke step (other agents' builds share it), which is the reason for the move.

Publishing from the second machine needs a person to sign the GitHub CLI in there (`gh auth login`); until then the
two-step route above is the release route whenever this machine has under 8 GB free.

## Open

- The next upstream releases (`v0.9.17` to `v0.9.19` on 2026-11-08) are the first to take the two-step route.
- The coordinator of the organization's agents was asked on the board (thread `0e1e694d`) what else the migration
  expects of a line without a service; its answer may add items here.
