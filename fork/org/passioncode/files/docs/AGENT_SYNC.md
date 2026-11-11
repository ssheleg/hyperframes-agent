# Coordination in this copy

Written by the line's export script with `.claude/agent-sync.json`; never edited by hand. The repository holds an
export of the HyperFrames Agent line, so its coordination is small: one export writes `main`, one release tags it.

| | |
|---|---|
| Record plane | `fs`: local, under `.agent-sync/`, ignored by Git |
| Lease | `git` on `origin`: exclusive across machines; TTL 2700 s, renewed every 300 s |
| Integration branch | `main` |
| Guarded files | `fork/line.env`: an export writes it; hold the lease before pushing one |
| Gates | `fork/release.sh 1` (build, the patches' tests, pack, smoke install) |
| Merge log | `docs/MERGES.md`, kept 7 days |

The cycle: acquire the lease, export from the line, check, commit, push, release the lease.
