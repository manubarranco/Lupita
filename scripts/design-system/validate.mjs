// Validates every theme (or the ones named) structurally and, per mode, visually (WCAG contrast, sizes, hierarchy).
//   node scripts/design-system/validate.mjs [themeId ...] [--json]
// Exit 1 on any FAIL. Themes with "baseline": true print FAIL as WARN and do not affect the exit code.
import { existsSync, readFileSync } from 'node:fs'
import { DS, GROUPS, loadTheme, listThemes, groupOf, leaves, contrastWorst, parseHex, over, ratio } from './lib.mjs'

const args = process.argv.slice(2)
const asJson = args.includes('--json')
const ids = args.filter(a => !a.startsWith('--'))
const themeIds = ids.length ? ids : listThemes()

const ROLES = ['title', 'id', 'description', 'repo', 'location', 'badge', 'eyebrow', 'footnote', 'placeholder', 'swatch', 'notice']
const FIELDS = ['family', 'size', 'weight', 'italic', 'lineHeight', 'tracking', 'color']
const AAA_ROLES = ['title', 'id', 'description', 'repo', 'location', 'badge', 'notice']
const REF = /^\{[^}]+\}$/
const fmt = n => typeof n === 'number' ? Math.round(n * 100) / 100 : n

function readDoc(id) {
  for (const dir of ['themes', 'variants']) {
    const p = `${DS}/${dir}/${id}.json`
    if (existsSync(p)) return JSON.parse(readFileSync(p, 'utf8'))
  }
  return {}
}

function structural(theme, doc) {
  const out = [] // {rule, ok, value, limit}
  const add = (rule, problems, limit = 0) => out.push({ rule, ok: problems.length === 0, value: problems.length ? problems.slice(0, 4).join('; ') + (problems.length > 4 ? ` (+${problems.length - 4})` : '') : 0, limit })

  add('refs', [...new Set(theme.errors)])

  const prim = new Set(leaves(theme.merged.primitive, '', 'primitive').map(([p]) => p))
  const clash = leaves(theme.merged.semantic, '', 'semantic').map(([p]) => p).filter(p => prim.has(p))
  add('namespace-clash', clash)

  const raw = leaves(theme.merged.component, 'component', 'component')
    .filter(([p]) => !p.startsWith('component.limits.'))
    .filter(([, v]) => !(typeof v === 'string' && REF.test(v))).map(([p]) => p)
  add('component-raw', raw)

  const missing = []
  const text = theme.merged.semantic.text ?? {}
  for (const r of ROLES) {
    if (!text[r]) { missing.push(`text.${r}`); continue }
    for (const f of FIELDS) if (!(f in text[r])) missing.push(`text.${r}.${f}`)
  }
  add('text-roles', missing)

  const touched = new Set()
  for (const [p] of leaves(doc.overrides?.primitive ?? {}, '', 'primitive')) touched.add(groupOf('primitive', p))
  for (const [p] of leaves(doc.overrides?.semantic ?? {}, '', 'semantic')) touched.add(groupOf('semantic', p))
  const want = GROUPS.filter(g => touched.has(g)), have = [...(doc.axes ?? [])].sort()
  const diffAxes = []
  if (touched.has(undefined)) diffAxes.push('override path with unknown group')
  if (JSON.stringify([...want].sort()) !== JSON.stringify(have)) diffAxes.push(`declared [${have}] but overrides touch [${want}]`)
  add('axes', diffAxes)

  add('override-keys', Object.keys(doc.overrides ?? {}).filter(k => k !== 'primitive' && k !== 'semantic').map(k => `overrides.${k}`))
  return out
}

function visual(theme, mode, aaa) {
  const m = theme[mode]
  const out = []
  const push = (rule, ok, value, limit) => out.push({ rule, ok, value, limit })
  const surface = m['color.surface']
  const t = r => m[`text.${r}`]
  const pages = ['#FFFFFF', '#000000']
  const worstOn = (fg, bgHex) => { // fg over (bg over page), bg translucent
    let w = Infinity
    for (const page of pages) {
      const bg = over(parseHex(bgHex), parseHex(page))
      w = Math.min(w, ratio(over(parseHex(fg), bg), bg))
    }
    return w
  }
  const worstOnBadge = (fg, badgeBg) => {
    let w = Infinity
    for (const page of pages) {
      const bg = over(parseHex(badgeBg), over(parseHex(surface), parseHex(page)))
      w = Math.min(w, ratio(over(parseHex(fg), bg), bg))
    }
    return w
  }
  const ratios = {}
  for (const r of ROLES) {
    const fg = r === 'title' ? m['color.text-primary'] : t(r).color
    if (r === 'badge') ratios[r] = worstOnBadge(fg, m['color.badge-bg'])
    else if (r === 'notice') ratios[r] = contrastWorst(fg, m['color.notice-surface'])
    else ratios[r] = contrastWorst(fg, surface)
  }
  ratios['origin-badge'] = worstOnBadge(m['color.origin-fg'], m['color.origin-bg'])
  for (const [r, v] of Object.entries(ratios)) {
    const limit = aaa && AAA_ROLES.includes(r === 'origin-badge' ? 'badge' : r) ? 7 : 4.5
    push(`contrast.${r}`, v >= limit, v, limit)
  }
  const sw = contrastWorst(m['color.swatch-border'], surface)
  push('contrast.swatch-border', sw >= 3, sw, 3)

  const sizes = ROLES.map(r => t(r).size)
  push('font-min', Math.min(...sizes) >= 10, Math.min(...sizes), 10)
  push('title-size', t('title').size >= 12, t('title').size, 12)
  push('description-size', t('description').size >= 12, t('description').size, 12)

  const ti = t('title'), de = t('description'), ey = t('eyebrow')
  const sizeOk = ti.size >= de.size && de.size > ey.size
  const distinct = ti.weight > de.weight || ratios.title > ratios.description
  push('hierarchy', sizeOk && distinct, `title ${ti.size}/${ti.weight}/${fmt(ratios.title)} desc ${de.size}/${de.weight}/${fmt(ratios.description)} eyebrow ${ey.size}`, 'size t>=d>e and (weight or contrast t>d)')

  const w = m['size.width']
  push('width', w >= 360 && w <= 520, w, '360..520')

  const bleedX = m['space.row-pad-x'] <= m['space.padding'], bleedY = m['space.row-pad-y'] * 2 <= m['space.block-gap']
  push('row-bleed', bleedX && bleedY, `x ${m['space.row-pad-x']}/${m['space.padding']} y ${m['space.row-pad-y']}*2/${m['space.block-gap']}`, 'row inset fits the container padding and the block gap')

  const neg = Object.entries(m).filter(([p, v]) => /^radius\./.test(p) && typeof v === 'number' && v < 0).map(([p]) => p)
  push('radius', neg.length === 0, neg.length ? neg.join(',') : 0, '>=0')
  const negB = Object.entries(m).filter(([p, v]) => /^border\./.test(p) && typeof v === 'number' && v < 0).map(([p]) => p)
  push('border-width', negB.length === 0, negB.length ? negB.join(',') : 0, '>=0')
  const badShadow = Object.entries(m).filter(([p, v]) => /^shadow\./.test(p) && Array.isArray(v) && v.some(s => !(s.blur >= 0))).map(([p]) => p)
  push('shadow', badShadow.length === 0, badShadow.length ? badShadow.join(',') : 0, 'blur>=0')
  return { checks: out, ratios: { ...ratios, 'swatch-border': sw } }
}

const rows = [] // JSON rows
const lines = []
let nPass = 0, nFail = 0, nWarn = 0

for (const id of themeIds) {
  let theme, doc
  try { theme = loadTheme(id); doc = readDoc(id) } catch (e) {
    rows.push({ theme: id, mode: '-', rule: 'load', status: 'fail', value: e.message, limit: null })
    lines.push(`${id.padEnd(14)} FAIL cannot load: ${e.message}`)
    nFail++; continue
  }
  const base = !!doc.baseline
  const bad = base ? 'warn' : 'fail'
  const status = ok => ok ? 'pass' : bad
  let failed = 0
  const parts = []
  const detail = []
  const record = (mode, c) => {
    const st = status(c.ok)
    rows.push({ theme: id, mode, rule: c.rule, status: st, value: c.value, limit: c.limit })
    if (!c.ok) { failed++; detail.push(`    ${st === 'fail' ? 'FAIL' : 'WARN'} ${mode.padEnd(9)} ${c.rule}: ${fmt(c.value)} (limit ${c.limit})`) }
  }
  const s = structural(theme, doc)
  s.forEach(c => record('structure', c))
  parts.push(`structure ${s.every(c => c.ok) ? '✓' : '✗'}`)
  const mins = []
  for (const mode of ['light', 'dark']) {
    let res
    try { res = visual(theme, mode, !!doc.aaa) } catch (e) {
      record(mode, { rule: 'visual', ok: false, value: `crash: ${e.message}`, limit: 'no errors' })
      parts.push(`${mode} ✗`); continue
    }
    res.checks.forEach(c => record(mode, c))
    const cs = res.checks.filter(c => !c.ok).map(c => c.rule)
    parts.push(`${mode} ${cs.length ? '✗ ' + cs.join(',') : '✓'}`)
    const [minRole, minVal] = Object.entries(res.ratios).sort((a, b) => a[1] - b[1])[0]
    mins.push(`${mode} ${fmt(minVal)}:1 (${minRole})`)
  }
  lines.push(`${id.padEnd(14)} ${parts.join('  ')}${base ? '  [baseline: FAIL→WARN]' : ''}${doc.aaa ? '  [AAA]' : ''}`)
  if (mins.length) lines.push(`${''.padEnd(14)} min contrast: ${mins.join(' · ')}`)
  lines.push(...detail)
  if (!failed) nPass++; else if (base) nWarn++; else nFail++
}

if (asJson) console.log(JSON.stringify(rows, null, 2))
else {
  lines.forEach(l => console.log(l))
  console.log(`themes: ${themeIds.length} · pass: ${nPass} · fail: ${nFail} · warn: ${nWarn}`)
}
process.exit(nFail ? 1 : 0)
