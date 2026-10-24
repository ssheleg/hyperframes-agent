import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { expect, vi } from "vitest";

const WATCH_PROBE = "watch-probe.txt";

/**
 * How long a real-file-system watcher test waits for one event. On an idle machine an event arrives
 * within a few hundred ms and the wait ends then; at load average 139 FSEvents delivered seconds late.
 */
export const WATCH_EVENT_TIMEOUT_MS = 15_000;

/** A real-file-system watcher test makes several such waits in a row. */
export const WATCH_TEST_TIMEOUT_MS = 60_000;

const sleep = (ms: number) => new Promise((settle) => setTimeout(settle, ms));

/**
 * Wait until a fresh watcher reports writes, then forget what it heard.
 *
 * FSEvents starts its stream a moment after `watch()` returns, and a write in that gap is never
 * reported: under load half of eight parallel runs lost a test's first write. Touching a probe
 * until the watcher hears it closes the gap. Then a whole second has to pass with nothing new
 * before the list is cleared: under heavy load the probe's later events arrive seconds late and
 * would otherwise land in the test's own assertions.
 */
export async function armWatcher(projectDir: string, heard: string[]): Promise<void> {
  const probe = join(projectDir, WATCH_PROBE);
  await vi.waitFor(
    () => {
      writeFileSync(probe, "probe");
      expect(heard).toContain(WATCH_PROBE);
    },
    { timeout: WATCH_EVENT_TIMEOUT_MS, interval: 500 },
  );
  // Longer than the watcher's 300 ms burst window, so a quiet second means the burst is over.
  for (let count = -1; count !== heard.length; ) {
    count = heard.length;
    await sleep(1000);
  }
  heard.length = 0;
}
