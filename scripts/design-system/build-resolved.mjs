// Writes docs/design-system/resolved/<theme>.json: every reference resolved, per mode, in DTCG form ($type/$value),
// for the SwiftUI port. `node scripts/design-system/build-resolved.mjs`
import { mkdirSync, writeFileSync } from 'node:fs'
import { DS, listThemes, loadTheme } from './lib.mjs'

const typeOf = (path, v) => {
  if (/^text\./.test(path) && path.split('.').length === 2) return 'typography'
  if (/^shadow\./.test(path) || /\.shadow$/.test(path)) return 'shadow'
  if (typeof v === 'string' && /^#/.test(v)) return 'color'
  if (/^font\.weight/.test(path)) return 'fontWeight'
  if (/^font\.family/.test(path)) return 'fontFamily'
  if (typeof v === 'number') return /opacity|lineHeight/.test(path) ? 'number' : 'dimension'
  return 'string'
}
mkdirSync(`${DS}/resolved`, { recursive: true })
for (const id of [...listThemes()]) {
  const t = loadTheme(id)
  const out = { id: t.id, name: t.name, light: {}, dark: {} }
  for (const mode of ['light', 'dark'])
    for (const [path, v] of Object.entries(t[mode])) out[mode][path] = { $type: typeOf(path, v), $value: v }
  writeFileSync(`${DS}/resolved/${id}.json`, JSON.stringify(out, null, 1) + '\n')
}
console.log(`resolved: ${listThemes().length} themes`)
