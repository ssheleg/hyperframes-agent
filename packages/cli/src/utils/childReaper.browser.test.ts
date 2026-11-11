import type { ChildProcess } from "node:child_process";
import { EventEmitter } from "node:events";
import { describe, expect, it, vi } from "vitest";
import { killBrowserWithThisProcess } from "./childReaper.js";

function browserWith(child: Partial<ChildProcess> | null) {
  return { process: () => child as ChildProcess | null };
}

function chrome(fields: Partial<ChildProcess>): ChildProcess {
  return Object.assign(
    new EventEmitter(),
    { exitCode: null, signalCode: null },
    fields,
  ) as ChildProcess;
}

describe("killBrowserWithThisProcess", () => {
  it("holds a running browser's process group and lets it go when the browser exits", () => {
    const release = vi.fn();
    const register = vi.fn(() => release);
    const child = chrome({ pid: 4242 });

    killBrowserWithThisProcess(browserWith(child), register);

    expect(register).toHaveBeenCalledWith(4242, process.platform !== "win32");
    expect(release).not.toHaveBeenCalled();
    child.emit("exit", 0, null);
    expect(release).toHaveBeenCalledOnce();
  });

  it("holds nothing for a browser without a process or one that already exited", () => {
    const register = vi.fn(() => () => undefined);

    killBrowserWithThisProcess(browserWith(null), register);
    killBrowserWithThisProcess(browserWith(chrome({ pid: undefined })), register);
    killBrowserWithThisProcess(browserWith(chrome({ pid: 1, exitCode: 0 })), register);
    killBrowserWithThisProcess(browserWith(chrome({ pid: 2, signalCode: "SIGKILL" })), register);

    expect(register).not.toHaveBeenCalled();
  });
});
