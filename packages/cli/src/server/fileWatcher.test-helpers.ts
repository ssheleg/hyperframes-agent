import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { expect, vi } from "vitest";

const WATCH_PROBE = "watch-probe.txt";

/**
 * Wait until a fresh watcher reports writes, then forget what it heard.
 *
 * FSEvents starts its stream a moment after `watch()` returns, and a write in that gap is never
 * reported: under load half of eight parallel runs lost a test's first write. Touching a probe
 * until the watcher hears it closes the gap, and waiting past the burst window keeps the probe
 * (and anything FSEvents replays from before the watch) out of the test's own assertions.
 */
export async function armWatcher(projectDir: string, heard: string[]): Promise<void> {
  const probe = join(projectDir, WATCH_PROBE);
  await vi.waitFor(
    () => {
      writeFileSync(probe, "probe");
      expect(heard).toContain(WATCH_PROBE);
    },
    { timeout: 10_000, interval: 100 },
  );
  // Past the watcher's 300 ms burst window, so every event of the probe has been delivered.
  await new Promise((settle) => setTimeout(settle, 600));
  heard.length = 0;
}
