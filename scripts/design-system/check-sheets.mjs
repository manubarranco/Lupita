// Checks the generated contact sheets: they exist, are real PNGs of a plausible size, and the overflow report
// covers every theme (20 renders each: 10 states × 2 modes) with 0 violations. `node scripts/design-system/check-sheets.mjs`
import { existsSync, readFileSync } from 'node:fs'
import { DS, listThemes } from './lib.mjs'

const dir = `${DS}/sheets`
const problems = []
const size = f => { const b = readFileSync(f); return b.readUInt32BE(0) === 0x89504e47 ? [b.readUInt32BE(16), b.readUInt32BE(20)] : null }
const states = JSON.parse(readFileSync(`${DS}/states.json`, 'utf8')).states.length

const files = [...listThemes().map(t => `theme-${t}.png`), 'compare.png', 'compare-definition.png', 'compare-stress.png', 'independence.png']
for (const f of files) {
  if (!existsSync(`${dir}/${f}`)) { problems.push(`missing ${f}`); continue }
  const s = size(`${dir}/${f}`)
  if (!s || s[0] < 1000 || s[1] < 400) problems.push(`${f}: not a plausible PNG (${s})`)
}
const report = JSON.parse(readFileSync(`${dir}/overflow-report.json`, 'utf8')).themes
let renders = 0, violations = 0
for (const t of [...listThemes(), 'ind-type', 'ind-color', 'ind-shape', 'ind-space', 'ind-shadow']) {
  const r = report[t]
  if (!r) { problems.push(`overflow report has no entry for ${t}`); continue }
  renders += r.renders; violations += r.violations
  if (listThemes().includes(t) && r.renders !== states * 2) problems.push(`${t}: ${r.renders} renders, expected ${states * 2}`)
  if (r.violations) problems.push(`${t}: ${r.violations} overflow violations`)
}
console.log(`sheets: ${files.length} PNGs · themes: ${listThemes().length} × ${states} states × 2 modes · renders ${renders} · violations ${violations} · problems: ${problems.length}`)
problems.forEach(p => console.log('  ' + p))
process.exit(problems.length ? 1 : 0)
