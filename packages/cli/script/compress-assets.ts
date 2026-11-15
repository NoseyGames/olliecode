import { readFile } from "node:fs/promises"
import path from "node:path"
import { promisify } from "node:util"
import { brotliCompress, constants } from "node:zlib"
import { collectFiles } from "./files"

const compress = promisify(brotliCompress)

/** Bound raw buffers and Brotli jobs while keeping the archive's stable, sorted entry order. */
export async function compressAssets(root: string, channel: string) {
  const keys = (await collectFiles(root))
    .map((key) => key.replaceAll(path.sep, "/"))
    .filter((key) => !key.endsWith(".map"))
    .toSorted()
  const entries = new Array<readonly [string, Buffer]>(keys.length)
  let next = 0
  let failed = false
  await Promise.all(Array.from({ length: Math.min(4, keys.length) }, async () => {
    while (!failed && next < keys.length) {
      const index = next++
      try {
        const body = await readFile(path.join(root, keys[index]))
        const encoded = await compress(body, {
          params: {
            [constants.BROTLI_PARAM_QUALITY]: channel === "beta" ? 6 : 11,
            [constants.BROTLI_PARAM_SIZE_HINT]: body.length,
          },
        })
        entries[index] = [keys[index], encoded]
      } catch (error) {
        failed = true
        throw error
      }
    }
  }))
  return entries
}
