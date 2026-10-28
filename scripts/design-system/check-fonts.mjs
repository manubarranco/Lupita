// Every font a theme names exists on this Mac (macos-fonts.json), and every weight / italic a theme asks of it is a
// face the family really has, so nothing resolves silently to another face (D55). «system» is the macOS system font:
// any weight, any design. `node scripts/design-system/check-fonts.mjs`
import { readFileSync } from 'node:fs'
import { DS, listThemes, loadTheme } from './lib.mjs'

const fonts = JSON.parse(readFileSync(`${DS}/macos-fonts.json`, 'utf8')).families
const byFamily = new Map(fonts.map(f => [f.family, f.styles]))
const WEIGHT_WORDS = [['ultra light', 200], ['ultralight', 200], ['thin', 100], ['light', 300], ['demi bold', 600], ['semibold', 600], ['medium', 500], ['condensed bold', 700], ['bold', 700], ['heavy', 800], ['black', 900]]
const faces = styles => styles.map(s => {
  const l = s.toLowerCase()
  const w = WEIGHT_WORDS.find(([k]) => l.includes(k))?.[1] ?? 400
  return { weight: w, italic: /italic|oblique/.test(l) }
})

const problems = [], used = new Map() // "family" → themes
for (const id of listThemes()) {
  const t = loadTheme(id), m = t.light
  for (const role of ['heading', 'body', 'code']) {
    const f = m[`font.family.${role}`]
    if (f.primary === 'system') continue
    if (!byFamily.has(f.primary)) { problems.push(`${id}: ${role} font «${f.primary}» is not installed on this Mac (falls back to ${f.fallback})`); continue }
    used.set(f.primary, [...(used.get(f.primary) ?? []), id])
  }
  for (const [path, v] of Object.entries(m)) {
    if (!/^text\.[^.]+$/.test(path)) continue
    const f = m[`font.family.${v.familyKey}`]
    if (f.primary === 'system' || !byFamily.has(f.primary)) continue
    const fs = faces(byFamily.get(f.primary))
    if (!fs.some(x => x.weight === v.weight)) problems.push(`${id}: ${path} asks ${f.primary} for weight ${v.weight}; it has ${[...new Set(fs.map(x => x.weight))].join('/')}`)
    if (v.italic && !fs.some(x => x.italic)) problems.push(`${id}: ${path} asks ${f.primary} for italic; it has none`)
  }
}
problems.forEach(p => console.log('  ' + p))
console.log(`fonts: ${used.size} families named by ${listThemes().length} themes, all installed here: ${[...used.keys()].join(', ')} · problems: ${problems.length}`)
process.exit(problems.length ? 1 : 0)
