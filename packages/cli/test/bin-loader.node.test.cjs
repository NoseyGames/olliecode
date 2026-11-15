const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const source = readFileSync(path.join(__dirname, '../bin/opencode.cjs'), 'utf8')

function launch({ explicit, cached }) {
  let probes = 0
  let started
  const child = { on() {}, kill() {} }
  const modules = {
    child_process: {
      spawn(target, args) { started = { target, args }; return child },
      spawnSync() { probes++; return { status: 0, stdout: 'true' } },
    },
    fs: { realpathSync: (file) => file, existsSync: (file) => cached && file.endsWith('.opencode') },
    path: path.win32,
    os: { platform: () => 'win32', arch: () => 'x64' },
  }
  vm.runInNewContext(source, {
    require: (name) => modules[name],
    __filename: 'C:\\app\\bin\\opencode.cjs',
    console,
    process: {
      platform: 'win32', env: { OPENCODE_BIN_PATH: explicit },
      argv: ['node', 'opencode.cjs', '--continue'], on() {}, removeListener() {},
      exit(code) { throw new Error(`exit ${code}`) },
    },
  })
  return { probes, started }
}

test('explicit binary launches without spawning PowerShell capability probes', () => {
  const result = launch({ explicit: 'C:\\built\\opencode.exe', cached: true })
  assert.equal(result.probes, 0)
  assert.equal(result.started.target, 'C:\\built\\opencode.exe')
  assert.equal(result.started.args.join(','), '--continue')
})

test('cached binary launches without spawning PowerShell capability probes', () => {
  const result = launch({ cached: true })
  assert.equal(result.probes, 0)
  assert.equal(result.started.target, 'C:\\app\\bin\\.opencode')
})
