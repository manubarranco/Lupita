// Authoring aid: compact theme definitions → docs/design-system/themes/*.json and variants/*.json.
// The JSON files are the artefact (and what the port reads); this script only saves typing palette pairs
// and refs. Re-run it after editing a definition: `node scripts/design-system/make-themes.mjs`.
import { mkdirSync, writeFileSync, readFileSync, readdirSync, rmSync } from 'node:fs'
import { DS } from './lib.mjs'

const base = JSON.parse(readFileSync(`${DS}/tokens.json`, 'utf8'))
const ROLES = Object.keys(base.semantic.text)

/** One theme definition → theme document. Every colour is a [light, dark] pair; each pair becomes two palette entries. */
function build(def) {
  const overrides = { primitive: {}, semantic: {} }
  const set = (layer, path, value) => {
    const keys = path.split('.')
    let node = overrides[layer]
    for (const k of keys.slice(0, -1)) node = node[k] ??= {}
    node[keys.at(-1)] = value
  }

  // type: families/sizes/weights overrides per role, only the fields that differ from the default
  for (const [role, fields] of Object.entries(def.type ?? {})) {
    if (!ROLES.includes(role)) throw new Error(`${def.id}: unknown text role ${role}`)
    const d = base.semantic.text[role]
    const out = {}
    if ('family' in fields || 'size' in fields) throw new Error(`${def.id}: text.${role}: family comes from \`fonts\` (by role) and size from the scale (D55)`)
    if (fields.weight) out.weight = `{font.weight.${fields.weight}}`
    if (fields.color) out.color = `{color.${fields.color}}`
    for (const k of ['italic', 'lineHeight', 'tracking']) if (k in fields) out[k] = fields[k]
    for (const [k, v] of Object.entries(out)) if (JSON.stringify(d[k]) !== JSON.stringify(v)) set('semantic', `text.${role}.${k}`, v)
  }
  // fonts: heading / body / code → [macOS font, system fallback design]
  for (const [role, pair] of Object.entries(def.fonts ?? {})) {
    if (!['heading', 'body', 'code'].includes(role)) throw new Error(`${def.id}: unknown font role ${role}`)
    set('primitive', `font.family.${role}`, { primary: pair[0], fallback: pair[1] })
  }
  if (def.lineHeight) for (const role of ROLES) if (!(def.type?.[role] && 'lineHeight' in def.type[role])) set('semantic', `text.${role}.lineHeight`, def.lineHeight)
  for (const [role, v] of Object.entries(def.lh ?? {})) set('semantic', `text.${role}.lineHeight`, v)
  if (def.tracking) for (const role of ROLES) if (!(def.type?.[role] && 'tracking' in def.type[role])) set('semantic', `text.${role}.tracking`, def.tracking)

  // colour: [light, dark] hex pairs, or [light, dark] numbers for blur / opacity
  for (const [name, pair] of Object.entries(def.color ?? {})) {
    if (typeof pair[0] === 'number') { set('semantic', `color.${name}`, { light: pair[0], dark: pair[1] }); continue }
    const key = `${def.id}-${name}`
    set('primitive', `palette.${key}-light`, pair[0])
    set('primitive', `palette.${key}-dark`, pair[1])
    set('semantic', `color.${name}`, { light: `{palette.${key}-light}`, dark: `{palette.${key}-dark}` })
  }
  for (const [name, layers] of Object.entries(def.shadows ?? {})) set('primitive', `shadow.${name}`, layers)
  for (const [role, v] of Object.entries(def.shadow ?? {})) set('semantic', `shadow.${role}`, `{shadow.${v}}`)
  for (const [role, v] of Object.entries(def.radius ?? {})) set('semantic', `radius.${role}`, `{radius.${v}}`)
  for (const [role, v] of Object.entries(def.border ?? {})) set('semantic', `border.${role}`, v)
  for (const [role, v] of Object.entries(def.space ?? {})) set('semantic', `space.${role}`, `{space.${v}}`)
  if (def.size) throw new Error(`${def.id}: width and swatch size come from the scale (D55)`)

  if (!Object.keys(overrides.primitive).length) delete overrides.primitive
  if (!Object.keys(overrides.semantic).length) delete overrides.semantic
  const doc = { id: def.id, name: def.name, blurb: def.blurb, axes: def.axes }
  if (def.aaa) doc.aaa = true
  if (def.notes) doc.notes = def.notes
  doc.overrides = overrides
  return doc
}

const ALL = ['type', 'color', 'shape', 'space', 'shadow']
const sans = (o) => o
const themes = []
const variants = []

// Sizes and the width are NOT here: they come from the scale in tokens.json (D55). A theme sets fonts by role,
// weights, colours, shape, spacing and shadow. Only faces that exist in the font's family are used as weights
// (check-fonts.mjs), so a weight never lands on a face the Mac would synthesise.
// The base tokens ARE Cristal (the default theme), so Cristal has no overrides.

// ── 1. Cristal ─ the default: system faces, frosted glass ───────────────────────
themes.push({
  id: 'cristal', name: 'Cristal', axes: [],
  blurb: 'Vidrio esmerilado con las fuentes del sistema: fondo translúcido con desenfoque fuerte, esquinas de 20 pt, borde de luz y una sombra profunda y difusa. Es el tema por defecto.',
})

// ── 2. Papel ─ editorial serif, warm paper, soft shadow ────────────────────────
themes.push({
  id: 'papel', name: 'Papel', axes: ALL,
  blurb: 'Charter sobre papel cálido: el título se lee como un titular, el resto baja en silencio. Esquinas casi rectas y una sombra de hoja sobre la mesa.',
  fonts: { heading: ['Charter', 'serif'], body: ['Charter', 'serif'], code: ['PT Mono', 'monospaced'] },
  type: {
    title: { weight: 'bold', tracking: 0 }, id: { weight: 'bold', color: 'text-accent' }, description: { color: 'text-secondary' },
    repo: { weight: 'bold', tracking: 0.3 }, location: {}, eyebrow: { weight: 'regular', italic: true }, footnote: { italic: true },
    badge: { weight: 'bold', tracking: 0.3 }, swatch: {}, notice: {},
  },
  lineHeight: 1.3,
  lh: { title: 1.3, description: 1.5, placeholder: 1.4 },
  color: {
    surface: ['#FBF6ECF7', '#2B2620F7'], 'notice-surface': ['#FBF6ECF7', '#2B2620F7'],
    border: ['#2A241B33', '#F3E9D633'],
    'text-primary': ['#2A241B', '#F6EEDD'], 'text-secondary': ['#645A4C', '#C9BDA8'], 'text-accent': ['#9A3B14', '#F0A27C'],
    'badge-bg': ['#2A241B14', '#F3E9D61F'], 'badge-fg': ['#2A241B', '#F6EEDD'], 'origin-bg': ['#C98A1B33', '#E0A63A33'], 'origin-fg': ['#4F3300', '#FFE6B3'],
    'swatch-border': ['#2A241BB3', '#F3E9D666'], 'row-hover': ['#9A3B140F', '#F0A27C1A'],
    shadow: ['#3A2A1038', '#00000099'], 'shadow-edge': ['#3A2A1014', '#00000040'], 'surface-blur': [0, 0], 'suggestion-opacity': [0.78, 0.78],
  },
  shadows: { sheet: [{ x: 0, y: 1, blur: 2, spread: 0, color: '{color.shadow-edge}' }, { x: 0, y: 8, blur: 20, spread: -2, color: '{color.shadow}' }] },
  shadow: { container: 'sheet', notice: 'sheet' },
  radius: { container: 'sm', notice: 'sm', swatch: 'xs', badge: 'xs', row: 'xs' },
  border: { container: 1, swatch: 1, notice: 1 },
  space: { padding: '18', 'block-gap': '12', 'range-gap': '10', 'range-line-gap': '6', 'entry-gap': '10', 'inline-gap': '8', 'row-gap': '5', 'name-gap': '3', 'swatch-gap': '12', 'swatch-inner-gap': '6', 'badge-x': '6', 'badge-y': '2', 'notice-x': '14', 'notice-y': '10', 'row-pad-x': '6', 'row-pad-y': '4', 'meta-gap': '4' },
})

// ── 3. Terminal ─ Monaco everywhere, ONE weight, square, flat ───────────────────
// Monaco has a single weight and no italic. What replaces bold: colour (the accent) and the size the scale gives each role.
themes.push({
  id: 'terminal', name: 'Terminal', axes: ALL,
  blurb: 'Una pantalla de consola: fósforo verde sobre negro en los dos modos, todo en Monaco (un solo peso: el énfasis lo da el color) y esquinas rectas. En oscuro la pantalla sube un tono y el borde se enciende para despegarse del fondo.',
  fonts: { heading: ['Monaco', 'monospaced'], body: ['Monaco', 'monospaced'], code: ['Monaco', 'monospaced'] },
  type: {
    title: { weight: 'regular', color: 'text-accent' }, id: { weight: 'regular', color: 'text-accent' },
    description: { weight: 'regular' }, placeholder: { italic: false },
    repo: { weight: 'regular' }, location: {}, badge: { weight: 'regular' }, eyebrow: { weight: 'regular' }, footnote: {}, swatch: {}, notice: {},
  },
  lineHeight: 1.3,
  lh: { title: 1.35, description: 1.5 },
  color: {
    surface: ['#060906FA', '#141A14F7'], 'notice-surface': ['#060906FA', '#141A14F7'],
    border: ['#3DFF7A99', '#3DFF7A99'],
    'text-primary': ['#D4F7CE', '#D4F7CE'], 'text-secondary': ['#86C081', '#86C081'], 'text-accent': ['#3DFF7A', '#3DFF7A'],
    'badge-bg': ['#3DFF7A26', '#3DFF7A26'], 'badge-fg': ['#9BFFB8', '#9BFFB8'], 'origin-bg': ['#FFB00033', '#FFB00033'], 'origin-fg': ['#FFD27A', '#FFD27A'],
    'swatch-border': ['#3DFF7A99', '#3DFF7A99'], 'row-hover': ['#3DFF7A1F', '#3DFF7A1F'],
    shadow: ['#00000000', '#00000000'], 'shadow-edge': ['#00000000', '#00000000'], 'surface-blur': [0, 0], 'suggestion-opacity': [0.7, 0.7],
  },
  shadow: { container: 'none', notice: 'none' },
  radius: { container: 'none', notice: 'none', swatch: 'none', badge: 'none', row: 'none' },
  border: { container: 1, swatch: 1, notice: 1 },
  space: { padding: '12', 'block-gap': '8', 'range-gap': '6', 'range-line-gap': '4', 'entry-gap': '8', 'inline-gap': '8', 'row-gap': '3', 'name-gap': '2', 'swatch-gap': '8', 'swatch-inner-gap': '6', 'badge-x': '5', 'badge-y': '1', 'notice-x': '10', 'notice-y': '6', 'row-pad-x': '6', 'row-pad-y': '3', 'meta-gap': '3' },
})

// ── 4. Neón ─ dark-first, saturated accent, glow as shadow ─────────────────────
themes.push({
  id: 'neon', name: 'Neón', axes: ALL,
  blurb: 'Un rótulo de neón: tubo rosa sobre ciruela profundo en los dos modos, con Arial Rounded en los títulos y Avenir Next en el texto. En claro, una sombra oscura lo asienta y un halo corto del color del tubo lo enciende; en oscuro la luz se derrama alrededor.',
  fonts: { heading: ['Arial Rounded MT Bold', 'rounded'], body: ['Avenir Next', 'default'], code: ['Menlo', 'monospaced'] },
  type: {
    title: { weight: 'regular' }, id: { weight: 'bold', color: 'text-accent', tracking: 0.2 },
    description: { weight: 'regular' }, placeholder: { italic: false },
    repo: { weight: 'bold', tracking: 0.4 }, location: {}, badge: { weight: 'bold', tracking: 0.4 },
    eyebrow: { weight: 'medium', tracking: 0.3 }, footnote: {}, swatch: {}, notice: {},
  },
  lh: { title: 1.3, description: 1.45 },
  color: {
    surface: ['#1F0D24F7', '#2A1430F2'], 'notice-surface': ['#1F0D24F7', '#2A1430F2'],
    border: ['#FF4FB0', '#FF4FB0E6'],
    'text-primary': ['#FFF0F8', '#FFF0F8'], 'text-secondary': ['#E7B8D6', '#E7B8D6'], 'text-accent': ['#FF6EC7', '#FF6EC7'],
    'badge-bg': ['#FF4FB026', '#FF4FB026'], 'badge-fg': ['#FFC2E3', '#FFC2E3'], 'origin-bg': ['#FFB34733', '#FFB34733'], 'origin-fg': ['#FFD9A3', '#FFD9A3'],
    'swatch-border': ['#FF6EC7CC', '#FF6EC7CC'], 'row-hover': ['#FF4FB01F', '#FF4FB01F'],
    shadow: ['#2A0A2266', '#FF4FB03D'], 'shadow-edge': ['#FF3EA5F2', '#FF4FB0B3'], 'surface-blur': [24, 24], 'suggestion-opacity': [0.7, 0.7],
    'inner-glow': ['#FF4FB026', '#FF4FB026'],
  },
  shadows: { glowIn: [{ x: 0, y: 0, blur: 10, spread: 0, color: '{color.inner-glow}' }], glow: [{ x: 0, y: 10, blur: 32, spread: 0, color: '{color.shadow}' }, { x: 0, y: 0, blur: 16, spread: 1, color: '{color.shadow-edge}' }] },
  shadow: { container: 'glow', notice: 'glow', inset: 'glowIn' },
  radius: { container: 'xl', notice: 'lg', swatch: 'md', badge: 'pill', row: 'md' },
  border: { container: 1, swatch: 1, notice: 1 },
  space: { padding: '16', 'block-gap': '12', 'range-gap': '10', 'range-line-gap': '6', 'entry-gap': '10', 'inline-gap': '8', 'row-gap': '5', 'name-gap': '3', 'swatch-gap': '12', 'swatch-inner-gap': '6', 'badge-x': '8', 'badge-y': '2', 'notice-x': '14', 'notice-y': '10', 'row-pad-x': '8', 'row-pad-y': '4', 'meta-gap': '4' },
})

// ── 5. Brutalista ─ flat colour, thick border, hard shadow ──────────────────────
themes.push({
  id: 'brutalista', name: 'Brutalista', axes: ALL,
  blurb: 'Neobrutalismo: tarjeta limón con trazo negro de 3 pt, esquinas redondeadas y sombra negra dura, sin desenfoque. Avenir Next en los títulos, Helvetica Neue en el texto y PT Mono en los datos. Los detalles, planos en menta, salmón y lavanda. En oscuro la tarjeta sigue de color y la sombra se vuelve lavanda. Jerarquía por peso, no por gris.',
  fonts: { heading: ['Avenir Next', 'default'], body: ['Helvetica Neue', 'default'], code: ['PT Mono', 'monospaced'] },
  type: {
    title: { weight: 'bold' }, id: { weight: 'bold', color: 'text-primary' },
    description: { weight: 'medium', color: 'text-primary' }, placeholder: { weight: 'medium' },
    repo: { weight: 'bold' }, location: { color: 'text-primary' }, badge: { weight: 'bold' },
    eyebrow: { weight: 'bold', color: 'text-primary' }, footnote: { weight: 'medium', color: 'text-primary' },
    swatch: { color: 'text-primary' }, notice: { weight: 'bold', color: 'text-primary' },
  },
  lh: { title: 1.25, description: 1.4 },
  color: {
    surface: ['#FDFD96', '#ECE47C'], 'notice-surface': ['#FDFD96', '#ECE47C'],
    border: ['#000000', '#000000'],
    'text-primary': ['#000000', '#000000'], 'text-secondary': ['#2B2B2B', '#2B2B2B'], 'text-accent': ['#4B1FC2', '#4B1FC2'],
    'badge-bg': ['#A7DBD8', '#A7DBD8'], 'badge-fg': ['#000000', '#000000'], 'origin-bg': ['#FFA07A', '#FFA07A'], 'origin-fg': ['#000000', '#000000'],
    'swatch-border': ['#000000', '#000000'], 'row-hover': ['#C4A1FF', '#C4A1FF'],
    shadow: ['#000000', '#C4A1FF'], 'shadow-edge': ['#000000', '#C4A1FF'], 'surface-blur': [0, 0], 'suggestion-opacity': [0.8, 0.8],
  },
  shadows: { hard: [{ x: 5, y: 5, blur: 0, spread: 0, color: '{color.shadow}' }] },
  shadow: { container: 'hard', notice: 'hard' },
  radius: { container: 'xl', notice: 'lg', swatch: 'sm', badge: 'md', row: 'md' },
  border: { container: 3, swatch: 2, notice: 3 },
  space: { padding: '14', 'block-gap': '10', 'range-gap': '8', 'range-line-gap': '5', 'entry-gap': '8', 'inline-gap': '8', 'row-gap': '4', 'name-gap': '2', 'swatch-gap': '10', 'swatch-inner-gap': '6', 'badge-x': '6', 'badge-y': '2', 'notice-x': '12', 'notice-y': '8', 'row-pad-x': '6', 'row-pad-y': '3', 'meta-gap': '3' },
})

// ── 6. Ficha (Tile) ─ rounded type, pressable cyan card ─────────────────────────
themes.push({
  id: 'ficha', name: 'Ficha', axes: ALL,
  blurb: 'Una interfaz de juego: tarjeta cian clara como un botón, con un borde cian bien marcado y un canto inferior grueso del mismo cian más oscuro; en oscuro, la tarjeta pasa a azul petróleo. Letra redondeada (Arial Rounded en los títulos, SF Rounded en el texto). Las insignias, blancas como fichas. Amable sin ser infantil: la jerarquía sigue mandando.',
  fonts: { heading: ['Arial Rounded MT Bold', 'rounded'], body: ['system', 'rounded'], code: ['Menlo', 'monospaced'] },
  type: {
    title: { weight: 'regular' }, id: { weight: 'bold', color: 'text-accent' }, description: { weight: 'regular' }, placeholder: { italic: false },
    repo: { weight: 'bold' }, location: {}, badge: { weight: 'bold' },
    eyebrow: { weight: 'bold', color: 'text-accent', tracking: 0.4 }, footnote: {}, swatch: {}, notice: {},
  },
  lh: { title: 1.3, description: 1.45 },
  color: {
    surface: ['#D2F3FC', '#163A47'], 'notice-surface': ['#D2F3FC', '#163A47'],
    border: ['#16A5C7', '#2BB8DA'],
    'text-primary': ['#032F3C', '#E6FAFF'], 'text-secondary': ['#0A4757', '#A8DCEA'], 'text-accent': ['#006A82', '#5FD8F5'],
    'badge-bg': ['#FFFFFF', '#E6FAFF'], 'badge-fg': ['#004F63', '#004F63'], 'origin-bg': ['#FFE08A', '#FFE08A'], 'origin-fg': ['#4A3200', '#4A3200'],
    'swatch-border': ['#032F3CCC', '#A8DCEACC'], 'row-hover': ['#A8E8F8', '#1F4F5F'],
    shadow: ['#1597B8', '#0E7895'], 'shadow-edge': ['#1597B8', '#0E7895'], 'surface-blur': [0, 0], 'suggestion-opacity': [0.75, 0.75],
  },
  shadows: { pop: [{ x: 0, y: 5, blur: 0, spread: 0, color: '{color.shadow-edge}' }] },
  shadow: { container: 'pop', notice: 'pop' },
  radius: { container: '2xl', notice: 'xl', swatch: 'md', badge: 'lg', row: 'lg' },
  border: { container: 2, swatch: 2, notice: 2 },
  space: { padding: '16', 'block-gap': '12', 'range-gap': '10', 'range-line-gap': '6', 'entry-gap': '10', 'inline-gap': '8', 'row-gap': '5', 'name-gap': '3', 'swatch-gap': '12', 'swatch-inner-gap': '6', 'badge-x': '8', 'badge-y': '3', 'notice-x': '16', 'notice-y': '10', 'row-pad-x': '8', 'row-pad-y': '4', 'meta-gap': '4' },
})

// ── 7. Blueprint ─ technical drawing ───────────────────────────────────────────
themes.push({
  id: 'blueprint', name: 'Blueprint', axes: ALL,
  blurb: 'Un plano de cianotipia: azul de Prusia con línea y letra blancas en los dos modos, PT Mono en títulos y datos, PT Sans en el texto y una sombra de dibujo desplazada. En oscuro, el azul baja un tono.',
  fonts: { heading: ['PT Mono', 'monospaced'], body: ['PT Sans', 'default'], code: ['PT Mono', 'monospaced'] },
  type: {
    title: { weight: 'bold' }, id: { weight: 'bold', color: 'text-accent' }, description: {}, placeholder: { italic: false },
    repo: { weight: 'bold' }, location: {}, badge: { weight: 'bold', tracking: 0.4 },
    eyebrow: { weight: 'regular', tracking: 0.5 }, footnote: {}, swatch: {}, notice: {},
  },
  lineHeight: 1.25,
  lh: { title: 1.3, description: 1.4 },
  color: {
    surface: ['#1D4F91F7', '#173F75F5'], 'notice-surface': ['#1D4F91F7', '#173F75F5'],
    border: ['#FFFFFFE6', '#FFFFFFCC'],
    'text-primary': ['#FFFFFF', '#FFFFFF'], 'text-secondary': ['#C9DCF5', '#C9DCF5'], 'text-accent': ['#9FE3FF', '#9FE3FF'],
    'badge-bg': ['#FFFFFF1F', '#FFFFFF1F'], 'badge-fg': ['#FFFFFF', '#FFFFFF'], 'origin-bg': ['#FFD34D33', '#FFD34D33'], 'origin-fg': ['#FFF3CC', '#FFF3CC'],
    'swatch-border': ['#FFFFFFB3', '#FFFFFF99'], 'row-hover': ['#FFFFFF14', '#FFFFFF14'],
    shadow: ['#0B2A5B4D', '#00000080'], 'shadow-edge': ['#0B2A5B1A', '#FFFFFF1F'], 'surface-blur': [0, 0], 'suggestion-opacity': [0.72, 0.72],
  },
  shadows: { offset: [{ x: 4, y: 4, blur: 0, spread: 0, color: '{color.shadow}' }] },
  shadow: { container: 'offset', notice: 'offset' },
  radius: { container: 'xs', notice: 'xs', swatch: 'none', badge: 'xs', row: 'xs' },
  border: { container: 1, swatch: 1, notice: 1 },
  space: { padding: '12', 'block-gap': '10', 'range-gap': '8', 'range-line-gap': '4', 'entry-gap': '8', 'inline-gap': '8', 'row-gap': '4', 'name-gap': '2', 'swatch-gap': '10', 'swatch-inner-gap': '6', 'badge-x': '6', 'badge-y': '1', 'notice-x': '12', 'notice-y': '8', 'row-pad-x': '6', 'row-pad-y': '3', 'meta-gap': '3' },
})

// ── single-group variants, to prove independence ────────────────────────────────
variants.push({
  id: 'ind-type', name: 'Solo tipografía', axes: ['type'], blurb: 'Cristal con otra letra: Charter en títulos y texto, títulos más pesados. Nada más cambia.',
  fonts: { heading: ['Charter', 'serif'], body: ['Charter', 'serif'] },
  type: { title: { weight: 'bold' }, placeholder: { weight: 'regular' } },
})
variants.push({
  id: 'ind-color', name: 'Solo color', axes: ['color'], blurb: 'Cristal con otra paleta: pizarra y acento naranja. Mismas formas, mismos espacios, misma letra.',
  color: {
    surface: ['#EEF1F5F5', '#1F2630F5'], 'notice-surface': ['#EEF1F5F5', '#1F2630F5'], border: ['#2C3A4E33', '#CBD6E640'],
    'text-primary': ['#18212D', '#F1F4F8'], 'text-secondary': ['#4A5A70', '#B7C3D4'], 'text-accent': ['#B4470A', '#FFA866'],
    'badge-bg': ['#2C3A4E1F', '#CBD6E62E'], 'badge-fg': ['#18212D', '#F1F4F8'], 'origin-bg': ['#B4470A29', '#FFA86633'], 'origin-fg': ['#5A2300', '#FFD9BD'],
    'swatch-border': ['#2C3A4E66', '#CBD6E699'], 'row-hover': ['#B4470A14', '#FFA8661F'],
    shadow: ['#18212D47', '#00000099'], 'shadow-edge': ['#18212D1A', '#00000040'], 'surface-blur': [20, 20], 'suggestion-opacity': [0.75, 0.75],
  },
})
variants.push({
  id: 'ind-shape', name: 'Solo forma', axes: ['shape'], blurb: 'Cristal con esquinas de 4 pt, cápsulas más cuadradas y borde de 2 pt. Mismo color, letra y espacios.',
  radius: { container: 'sm', notice: 'sm', swatch: 'xs', badge: 'sm' }, border: { container: 2, swatch: 2, notice: 2 },
})
variants.push({
  id: 'ind-space', name: 'Solo espacio', axes: ['space'], blurb: 'Cristal con más aire entre las piezas. Mismo color, letra y formas.',
  space: { padding: '20', 'block-gap': '14', 'range-gap': '12', 'range-line-gap': '8', 'entry-gap': '12', 'inline-gap': '8', 'row-gap': '6', 'name-gap': '3', 'swatch-gap': '12', 'swatch-inner-gap': '6', 'badge-x': '8', 'badge-y': '2', 'notice-x': '16', 'notice-y': '10' },
})
variants.push({
  id: 'ind-shadow', name: 'Solo sombra', axes: ['shadow'], blurb: 'Cristal con una sombra grande y alta, como si flotara. Mismo color, letra, formas y espacios.',
  shadow: { container: 'lg', notice: 'lg' },
})

mkdirSync(`${DS}/themes`, { recursive: true })
mkdirSync(`${DS}/variants`, { recursive: true })
// A theme that is no longer defined here (Lupita, Compacto, Grande: D55) must not linger as a file.
for (const [dir, list] of [['themes', themes], ['variants', variants]])
  for (const f of readdirSync(`${DS}/${dir}`)) if (f.endsWith('.json') && !list.some(t => `${t.id}.json` === f)) { rmSync(`${DS}/${dir}/${f}`); console.log('removed', dir, f) }
for (const t of themes) { writeFileSync(`${DS}/themes/${t.id}.json`, JSON.stringify(build(t), null, 2) + '\n'); console.log('theme  ', t.id) }
for (const v of variants) { writeFileSync(`${DS}/variants/${v.id}.json`, JSON.stringify(build(v), null, 2) + '\n'); console.log('variant', v.id) }
