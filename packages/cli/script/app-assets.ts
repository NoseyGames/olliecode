import { $ } from "bun"
import path from "node:path"
import { AppArchive } from "../src/app-archive"
import { compressAssets } from "./compress-assets"

export async function buildAppArchive(channel: string, version: string, options?: { skipBuild?: boolean }) {
  if (options?.skipBuild) return AppArchive.encode([])
  const root = path.resolve(import.meta.dirname, "../../app")
  await $`bun run build`.cwd(root).env({
    ...process.env,
    OPENCODE_CHANNEL: channel,
    VITE_OPENCODE_SERVER_MODE: "origin",
    VITE_OPENCODE_VERSION: version,
  })
  return AppArchive.encode(await compressAssets(path.join(root, "dist"), channel))
}
