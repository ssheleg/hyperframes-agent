/**
 * Stream a presigned `video_url` (or any HTTPS URL) into a local file.
 *
 * The presigned URLs returned by `GET /v3/hyperframes/renders/{id}` are
 * S3 URLs scoped per-request — they don't take any HeyGen auth header.
 * That's why this lives separate from the cloud client: the client
 * threads auth headers, the download path explicitly does NOT.
 *
 * Failure behavior is "all or nothing": on any error we (1) listen for
 * stream errors / aborts so awaits resolve promptly instead of hanging,
 * (2) verify the final byte count matches `content-length` when the
 * server supplied one, and (3) discard the private staged output. An
 * existing destination is replaced only after the download succeeds.
 */

import { chmodSync, mkdirSync, mkdtempSync, renameSync, rmSync, statSync } from "node:fs";
import { open } from "node:fs/promises";
import { dirname, join } from "node:path";
import { resolveWritePath } from "@hyperframes/core/atomic-file";

// The first request asks for PART_BYTES; a larger file is split into up to
// CONNECTIONS ranged GETs. A server that ignores Range answers 200 and is streamed.
const PART_BYTES = 8 * 1024 * 1024;
const CONNECTIONS = 8;

export interface DownloadOptions {
  signal?: AbortSignal;
  /** Inject fetch (used by tests). */
  fetchImpl?: typeof fetch;
  /** Called with (bytes downloaded, total or undefined). */
  onProgress?: (bytes: number, total: number | undefined) => void;
}

export interface DownloadResult {
  path: string;
  bytes: number;
}

/**
 * Stream `url` into `destPath`. Creates the parent directory if needed,
 * replaces an existing file only after the complete response is written,
 * and removes staged bytes on failure while preserving the old output.
 * Atomic replacement requires a writable parent directory and creates a new
 * inode: mode is retained, owner/group are not, and hard links keep old bytes.
 * A read-only file can be replaced when its parent permits the rename.
 */
// fallow-ignore-next-line complexity
export async function downloadToFile(
  url: string,
  destPath: string,
  options: DownloadOptions = {},
): Promise<DownloadResult> {
  const fetchImpl = options.fetchImpl ?? fetch;
  // Cancels the sibling parts when one fails.
  const failFast = new AbortController();
  const signal = options.signal
    ? AbortSignal.any([options.signal, failFast.signal])
    : failFast.signal;
  const get = async (range?: string) => fetchImpl(url, { signal, headers: range ? { range } : {} });

  let first = await get(`bytes=0-${PART_BYTES - 1}`);
  // 416 (empty file) or a 206 without a total cannot be split: fetch it whole.
  if (first.status === 416 || (first.status === 206 && contentRangeTotal(first) === undefined)) {
    await first.body?.cancel();
    first = await get();
  }
  assertOk(first, url);
  const ranged = first.status === 206;
  const total = ranged ? contentRangeTotal(first) : contentLength(first);

  mkdirSync(dirname(destPath), { recursive: true });

  // Writes through a caller-selected symlink, as before.
  const destination = resolveWritePath(destPath);
  const previous = statSync(destination, { throwIfNoEntry: false });
  const stage = mkdtempSync(join(dirname(destination), ".hf-download-"));
  const stagedFile = join(stage, "download");
  let bytes = 0;
  let firstError: unknown;
  try {
    const file = await open(stagedFile, "wx");
    const writePart = async (res: Response, start: number, length: number | undefined) => {
      let written = 0;
      for await (const chunk of res.body as unknown as AsyncIterable<Uint8Array>) {
        await file.write(chunk, 0, chunk.byteLength, start + written);
        written += chunk.byteLength;
        bytes += chunk.byteLength;
        signal.throwIfAborted();
        options.onProgress?.(bytes, total);
      }
      if (length !== undefined && written !== length) {
        throw new Error(
          `Truncated download: got ${written} bytes, expected ${length} (content-length). ` +
            `The presigned URL may have expired mid-transfer — refetch via \`hyperframes cloud get\`.`,
        );
      }
    };
    const parts: Promise<void>[] = [];
    if (ranged && total !== undefined) {
      parts.push(writePart(first, 0, Math.min(PART_BYTES, total)));
      const rest = total - PART_BYTES;
      const size = Math.ceil(rest / Math.min(CONNECTIONS - 1, Math.ceil(rest / PART_BYTES)));
      for (let start = PART_BYTES; start < total; start += size) {
        const end = Math.min(start + size, total) - 1;
        parts.push(
          get(`bytes=${start}-${end}`).then((res) => {
            assertOk(res, url);
            if (res.status !== 206) throw new Error(`Failed to download ${url}: range ignored`);
            return writePart(res, start, end - start + 1);
          }),
        );
      }
    } else {
      parts.push(writePart(first, 0, total));
    }
    await Promise.all(
      parts.map((part) =>
        part.catch((error: unknown) => {
          firstError ??= error;
          failFast.abort(error);
        }),
      ),
    );
    await file.close();
    if (firstError !== undefined) throw firstError;
    options.signal?.throwIfAborted();
    if (previous?.isFile()) chmodSync(stagedFile, previous.mode & 0o777);
    renameSync(stagedFile, destination);
  } catch (error) {
    const reason = options.signal?.reason;
    if (options.signal?.aborted && reason instanceof Error) throw reason;
    throw error;
  } finally {
    rmSync(stage, { recursive: true, force: true });
  }
  return { path: destPath, bytes };
}

function assertOk(res: Response, url: string): void {
  if (!res.ok) {
    throw new Error(`Failed to download ${url}: HTTP ${res.status} ${res.statusText}`);
  }
  if (!res.body) {
    throw new Error(`Failed to download ${url}: empty response body`);
  }
}

function contentLength(res: Response): number | undefined {
  const total = Number.parseInt(res.headers.get("content-length") ?? "", 10);
  return Number.isFinite(total) ? total : undefined;
}

function contentRangeTotal(res: Response): number | undefined {
  const match = /^bytes \d+-\d+\/(\d+)$/.exec(res.headers.get("content-range") ?? "");
  return match ? Number(match[1]) : undefined;
}
