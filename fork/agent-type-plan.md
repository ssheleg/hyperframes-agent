# The line against its agent type: review and plan (2026-11-08)

The estate's base of agent templates files this repository as a source of its media template, variant `engine-line`
("not an agent, a library line"; read at `42ad14381` on 2026-11-07). The variant teaches the method in its playbook
(section 6, the organization copy in section 7, maintenance tools and lessons in an appendix), its code (`release_line`:
versions, tags, door audit, workflow guard; `org_copy_export`: the copy) and three acceptance checks. This page compares
the line with that variant item by item and plans what brings it to production quality. Kept out of the organization
copy (`fork/export.sh`).

## What the variant teaches and where the line stands

| #   | Item of the variant                                                                                     | Here                                                                           | State                                                                                                                                                                                                                  |
| --- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | upstream mirror branch, no-ff merge of release tags, append-only main                                   | [README](README.md) "Branches", "Taking an upstream release"; `fork/status.sh` | matches                                                                                                                                                                                                                |
| 2   | patch table with drop condition, signed upstream branches sent only on instruction                      | README "Patches on the line", [upstream-prs.md](upstream-prs.md)               | matches; two branches wait for the operator's send instruction                                                                                                                                                         |
| 3   | inherited workflows disabled after every merge, guard with a report mode                                | `fork/workflows-guard.sh`, run by `release.sh --publish`                       | matches; on 2026-11-08 it disabled `stale.yml` that `v0.9.21` added                                                                                                                                                    |
| 4   | release: build, patch tests, pack, smoke install, version check, tarball and sha256, re-download check  | `fork/release.sh`                                                              | matches, and goes further: `fork/remote-build.sh` and `--prebuilt` (build on another machine, publish here)                                                                                                            |
| 5   | versions `<base>+<line>.<n>`, tags `fork-v<base>-<line>.<n>`, a package field naming the line           | `release.sh`, `hyperframesFork`                                                | matches; the variant computes `n` from existing tags (`next_release`), the line takes it by hand                                                                                                                       |
| 6   | door audit between tags; test files left out                                                            | `fork/door-audit.sh`                                                           | defect: `__fixtures__`, `__test_utils__` and `*.test-helpers.*` are not left out, so the `v0.9.16..v0.9.21` report listed `CI`, `FONTCONFIG_FILE` and two `spawnSync` calls from test utilities as shipped code        |
| 7   | status script naming the next step                                                                      | `fork/status.sh` (exit 10 when a step is due)                                  | matches                                                                                                                                                                                                                |
| 8   | organization copy: refusals, `Source-Revision`, `Backports`, org folder, audit allow list, no LFS files | `fork/export.sh`, `fork/org/`                                                  | matches in shape; gap: the word check and the secret scan run by hand after the export, and `--push` pushes before them (the variant checks every file before the single commit and pushes only after the copy's gate) |
| 9   | a hand-committed merge may skip the pre-commit audit when every finding is verbatim in the tag          | README step 3                                                                  | matches                                                                                                                                                                                                                |
| 10  | wait for the file-event daemon before the watcher tests                                                 | `release.sh`                                                                   | matches, refined: three calm readings in a row (2026-11-05); the variant still says one reading                                                                                                                        |
| 11  | public repository: no private agent's name, path, port or data                                          | export's name check; notes kept out of the copy                                | matches for the copy; the public line has no check of its own                                                                                                                                                          |
| 12  | the engine skills' authored-video methods                                                               | upstream's skills, shipped as they are                                         | upstream's, nothing to do                                                                                                                                                                                              |
| 13  | runtime-install switch; a tag diff hides older behaviour                                                | HANDOFF door-audit table, correction of 2026-11-05                             | matches                                                                                                                                                                                                                |

Operating rules every template inherits:

| Rule                                              | Here                                                                     | State                                                                                                                           |
| ------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| a handoff per unit of work                        | [HANDOFF.md](HANDOFF.md)                                                 | kept, but it has grown into a dated log (several "State" sections, a 30-row table); the next agent's first task is hard to find |
| lessons go back to the template                   | none sent                                                                | gap: the remote build, the three calm readings and the door-audit exclusions are not in the variant                             |
| read and append the insights journal each session | the line's data folder, `insights/2026-11.jsonl`                         | gap: last line 2026-11-04                                                                                                       |
| tests for the line's own tools                    | the variant's code has tests; `fork/*.sh` has none, only checked by hand | gap                                                                                                                             |

Acceptance checks of the variant:

| Check                                                                                                                                      | Evidence                                                                                     | State                             |
| ------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- | --------------------------------- |
| 36: the tarball installs into an empty folder, prints the line's version, its published sha256 matches a re-download                       | `fork-v0.9.21-sshlg.1` and `-appvillis.1`, 2026-11-08 (`hyperframes-0.9.21-sshlg.1.tgz: OK`) | passes                            |
| 37: after an upstream merge the workflow guard reports no active workflow                                                                  | 2026-11-08: `disabled .github/workflows/stale.yml`, then `no active workflow`                | passes                            |
| 38: the export refuses with an unannounced commit or an open pull request, and the exported tree passes the word check and the secret scan | refusals in `export.sh`; the shared audit read `ready` on `e701a03`, run by hand             | passes by hand, not by the script |

Findings the base holds against this source: F13 (a session transcript at the root), fixed on 2026-11-08
([migration.md](migration.md), M-3), not yet reported back.

## Plan

### Wave 1: defects and the gate (now)

- P-1 Door audit leaves out `__fixtures__`, `__test_utils__`, `__tests__` and `*.test-helpers.*`; a correction to the
  `v0.9.16..v0.9.21` report goes to the consumers. **Done 2026-11-08** (`6fc41f571`): reruns over `v0.9.16..v0.9.21`
  and `v0.9.5..v0.9.16` drop only those lines.
- P-2 `fork/export.sh` runs the word check (the shared transfer audit with the allow list) and the secret scan on the
  copy before committing, and `--push` pushes only after they pass. Done when an export with a planted marker refuses
  and commits nothing. **Done 2026-11-08** (`6fc41f571`): an export of a throwaway line clone with a planted marker
  read `fix_tree`, refused, and left the throwaway copy on its HEAD with a clean tree.
- P-3 The release route on the second machine: its personal space has a working GitHub CLI (a wrapper that reads the
  token from the credential store); write it down; build the copy in the organization's space (deploy key and clone in
  place since 2026-11-08). **Done 2026-11-08**: the personal space's GitHub CLI is a wrapper over the credential store
  (`~/.local/bin/gh`, from a login shell); the copy built in the organization's space (79 passed, 6 skipped, smoke),
  after GitHub's release downloads had answered 504 for about 12 minutes.
- P-4 Insights journal lines for 2026-11-08.

### Wave 2: tests of the line's tools

- P-5 `fork/test.sh`, plain Bash with temporary Git repositories, no network: version and tag names, `--prebuilt`
  refusals (number, renamed tarball, appended byte, missing file, missing `.sha256`), `remote-build.sh` refusals (dirty
  tree, HEAD not on origin, unsafe directory), export refusals (a foreign commit, a commit named in `Backports:`, the
  line's name in the tree), door-audit exclusions. `release.sh` runs it first. **Done 2026-11-08**: 31 cases in about 20 s, no network
  (stubs for `gh` and `ssh`); `release.sh` runs them first and skips them in a copy, which carries no `fork/test.sh`.
  Writing them found that the export refused its own test file (it holds the line's name as test data), so the copy
  leaves `fork/test.sh` out.

### Wave 3: back to the template and tidy

- P-6 Report to the base through the board (`agents-db.contribute`): F13 fixed; the remote build with `--prebuilt`;
  three calm readings; the door-audit exclusions; the export gate. Each with its commit.
- P-7 `release.sh` proposes `n` from existing tags (the variant's `next_release`) and refuses a gap. **Done
  2026-11-08**: `auto` in `release.sh` and `remote-build.sh`, three cases in `fork/test.sh`.
- P-8 HANDOFF compacted: current state, the next task and open waits first; history moved to a dated file. **Done
  2026-11-08**: `HANDOFF.md` 242 to 148 lines, dated notes verbatim in `HISTORY.md` (kept out of the copy), the copy's
  releases as a table.

### Board request b948516e: visual types and style presets

- P-9 `fork/visual-types.mjs` (a catalogue asset of every release) and `fork/style-preset.mjs` (a project's taste as a
  checked file), with cases in `fork/test.sh`. **Done 2026-11-08**, first shipped in `fork-v0.9.21-sshlg.2`.

### Waits on others

- The two signed upstream branches: the operator's send instruction ([upstream-prs.md](upstream-prs.md)).
- A row for the line in the coordinator's placement table: asked on the board (thread `eec1aa1e`).
- The board's old tasks in review are the operator's to close.
