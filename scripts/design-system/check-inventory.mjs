// Cross-checks docs/design-system/inventory.md against the style lines of TooltipPanel.swift, and enforces that
// the file holds NO style literal: every style line of TooltipView, Swatch and NoticeView must read a token
// (`theme`, or a ThemeStyle helper such as `.themed(`) and carry no numeric size, space, radius or colour literal.
// Each style line also needs exactly one inventory row (by line number), and the quoted code in the row must still
// be on that line (so a shifted file fails loudly).
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const swift = readFileSync(`${root}/Sources/LupitaApp/TooltipPanel.swift`, 'utf8').split('\n')
const md = readFileSync(`${root}/docs/design-system/inventory.md`, 'utf8').split('\n')

const start = swift.findIndex(l => l.startsWith('struct TooltipView')) + 1
const STYLE = /\.font\(|foregroundStyle|cornerRadius|\.padding\(|\.opacity\(|spacing:|\.frame\((?!maxWidth: \.infinity)|\.background\(|\.overlay\(|strokeBorder|lineLimit|truncationMode|\.themed\(|themedSurface|\.shape\(|lineWidth/
// A number in the argument of a style call is a literal; 0 and 1 are structural (no margin, full opacity).
const NUMERIC = /(\.padding\(|spacing:|\.frame\((?!maxWidth: \.infinity)|cornerRadius|lineWidth:|\.opacity\(|\.lineLimit\(|width:|height:)[^)\n]*?(?<![\w.])(?!(?:0|1)(?![\d.]))\d+(\.\d+)?\b/
const RAW = /Color\(\s*(white|red|\.sRGB|\.|nsColor)|\.font\(\.|\.opacity\(\s*0\.|\.regularMaterial|\.thinMaterial|\.separator|\.secondary|\.primary|Color\.accentColor|\.orange/
const expected = []
swift.forEach((l, i) => { if (i + 1 >= start && STYLE.test(l)) expected.push(i + 1) })

const problems = []
swift.forEach((l, i) => {
  const code = l.replace(/\/\/.*$/, '').replace(/"(?:[^"\\]|\\.)*"/g, '""')
  const n = i + 1
  if (RAW.test(code)) problems.push(`line ${n}: raw style, not a token → ${l.trim()}`)
  if (n >= start && STYLE.test(code)) {
    if (!/theme|\.themed\(/.test(code)) problems.push(`line ${n}: style line does not read \`theme\` → ${l.trim()}`)
    if (NUMERIC.test(code)) problems.push(`line ${n}: numeric style literal → ${l.trim()}`)
  }
})

const rows = new Map()
for (const l of md) {
  const m = l.match(/^\|\s*(\d+)\s*\|\s*`([^`]+)`\s*\|\s*(.+?)\s*\|\s*$/)
  if (!m) continue
  const n = Number(m[1])
  if (rows.has(n)) problems.push(`line ${n}: assigned twice`)
  rows.set(n, { code: m[2], tokens: m[3] })
  if (!swift[n - 1]?.includes(m[2])) problems.push(`line ${n}: code “${m[2]}” is not on that line of TooltipPanel.swift`)
}
for (const n of expected) if (!rows.has(n)) problems.push(`line ${n}: unassigned → ${swift[n - 1].trim()}`)
for (const n of rows.keys()) if (!expected.includes(n)) problems.push(`line ${n}: in the inventory but not a style line`)

console.log(`style lines: ${expected.length} · inventory rows: ${rows.size} · problems: ${problems.length}`)
problems.forEach(p => console.log('  ' + p))
process.exit(problems.length ? 1 : 0)
