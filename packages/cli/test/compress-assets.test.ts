import { expect, test } from "bun:test"
import { mkdtemp, mkdir, writeFile, rm } from "node:fs/promises"
import { tmpdir } from "node:os"
import path from "node:path"
import { brotliDecompressSync } from "node:zlib"
import { compressAssets } from "../script/compress-assets"

test("asset packaging preserves bytes, deterministic ordering and source-map exclusion", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "ollie-assets-"))
  try {
    await mkdir(path.join(root, "assets"))
    const bodies = new Map<string, Buffer>()
    for (let index = 0; index < 13; index++) {
      const key = `assets/${index}.js`
      const body = Buffer.from(`const value = ${index};\n`.repeat(index * 100))
      bodies.set(key, body)
      await writeFile(path.join(root, key), body)
    }
    await writeFile(path.join(root, "excluded.js.map"), "source map")
    for (const channel of ["beta", "stable"]) {
      const entries = await compressAssets(root, channel)
      expect(entries.map(([key]) => key)).toEqual([...bodies.keys()].sort())
      for (const [key, body] of entries)
        expect(Uint8Array.from(brotliDecompressSync(body))).toEqual(Uint8Array.from(bodies.get(key)!))
    }
  } finally { await rm(root, { recursive: true, force: true }) }
})

test("empty asset directories produce no entries; missing directories fail the build", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "ollie-assets-"))
  try {
    expect(await compressAssets(root, "beta")).toEqual([])
    await expect(compressAssets(path.join(root, "missing"), "beta")).rejects.toThrow()
  } finally { await rm(root, { recursive: true, force: true }) }
})
