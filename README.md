# olliEcode Free â€” Source

A fork of [OpenCode](https://github.com/anomalyco/opencode) (MIT) with a rebranded interface and an Auto JB toggle.

## Included

- `packages/` â€” app, desktop, CLI, core, AI, UI, plugins and the rest of the source tree
- `script/` and `patches/` â€” upstream build tooling
- `installer/olliEcode-Setup-Free.iss` â€” the free-edition Inno Setup script
- `shortcuts/olliEcode.vbs` â€” the direct launcher
- `CHANGELOG-free-2027.1.1.9.md`

## Not included

Release signing keys, the license Worker, the R2 release feed, private infrastructure, build artifacts, user data, logs and databases. The client references to those services are placeholders; point them at your own deployment.

## Build

Use the pinned Bun version from `package.json` (1.4.4).

```sh
bun install --frozen-lockfile
# Build for the current machine instead of every release platform:
bun --cwd packages/cli run build --single
bun --cwd packages/desktop run build
```

For a CLI-only build without the embedded browser UI, add `--skip-web-ui`.
Use `--skip-install` only after installing dependencies yourself.
Cross-platform release builds remain available by omitting `--single`.
Native builds install host-compatible dependencies; release builds install the target platform libraries.

The desktop build produces `packages/desktop/out`. The CLI build produces
`packages/cli/dist`. A signed release requires your own Ed25519 key and integrity
manifest; a development build does not.

## Windows folder launcher

Run `shortcuts/launch.cmd` to choose the last folder, current folder, or a native
folder picker, then start or continue a CLI session. It adds no third-party
libraries. See [launcher instructions](shortcuts/README.md) for executable selection,
private-server mode, and checks. The existing desktop shortcut remains available.

## Free models

The app uses OpenCode's provider. Users can connect their own provider key in Settings. No key is bundled in this repository.

## Auto JB

The toggle is in Settings. The Auto JB prompt is included in `packages/core/src/plugin/abliterated-AGENTS.md`. Edit it in Settings or replace the file.

## License

MIT. Upstream copyright belongs to the OpenCode authors. Fork changes are published under the same license.