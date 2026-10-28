// Checks the generated contact sheets: they exist, are real PNGs of a plausible size, and the overflow report
// covers every theme (20 renders each: 10 states × 2 modes) with 0 violations. `node scripts/design-system/check-sheets.mjs`
import { existsSync, readFileSync } from 'node:fs'
import { DS, listThemes } from './lib.mjs'

const dir = `${DS}/sheets`
const problems = []
const size = f => { const b = readFileSync(f); return b.readUInt32BE(0) === 0x89504e47 ? [b.readUInt32BE(16), b.readUInt32BE(20)] : null }
const states = JSON.parse(readFileSync(`${DS}/states.json`, 'utf8')).states.length

const files = [...listThemes().map(t => `theme-${t}.png`), 'compare.png', 'compare-definition.png', 'compare-stress.png', 'compare-sizes.png', 'independence.png']
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
// The full matrix (themes × states × modes × sizes × densities) was rendered with 0 overflows (render-sheets.mjs --only matrix).
const mx = JSON.parse(readFileSync(`${dir}/overflow-report.json`, 'utf8')).matrix
const expected = listThemes().length * states * 2 * 4 * 3
if (!mx) problems.push('overflow report has no matrix (run render-sheets.mjs --only matrix)')
else {
  if (mx.renders !== expected) problems.push(`matrix: ${mx.renders} renders, expected ${expected}`)
  if (mx.violations) problems.push(`matrix: ${mx.violations} overflow violations`)
}
console.log(`matrix: ${mx?.renders ?? 0} renders (${listThemes().length} themes × ${states} states × 2 modes × 4 sizes × 3 densities) · violations ${mx?.violations ?? '?'}`)
console.log(`sheets: ${files.length} PNGs · themes: ${listThemes().length} × ${states} states × 2 modes · renders ${renders} · violations ${violations} · problems: ${problems.length}`)
problems.forEach(p => console.log('  ' + p))
process.exit(problems.length ? 1 : 0)
