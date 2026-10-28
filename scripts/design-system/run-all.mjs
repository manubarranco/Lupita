// Runs every design-system check as a child process and prints each one's last line.
//   node scripts/design-system/run-all.mjs
import { spawnSync } from 'node:child_process'
import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const dir = dirname(fileURLToPath(import.meta.url))
const CHECKS = ['check-inventory', 'validate', 'check-parity', 'check-independence']
const failed = []
for (const name of CHECKS) {
  const r = spawnSync(process.execPath, [`${dir}/${name}.mjs`], { encoding: 'utf8', timeout: 8000 })
  const lines = (r.stdout + (r.stderr ?? '')).trim().split('\n')
  const last = lines[lines.length - 1] || (r.error ? String(r.error.message) : '(no output)')
  const ok = r.status === 0
  if (!ok) failed.push(name)
  console.log(`${ok ? '✓' : '✗'} ${name.padEnd(20)} ${last}`)
}
console.log(failed.length ? `FAILED: ${failed.join(', ')}` : 'ALL GREEN')
process.exit(failed.length ? 1 : 0)
