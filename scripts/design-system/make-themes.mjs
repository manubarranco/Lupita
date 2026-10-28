// Authoring aid: compact theme definitions → docs/design-system/themes/*.json and variants/*.json.
// The JSON files are the artefact (and what the port reads); this script only saves typing palette pairs
// and refs. Re-run it after editing a definition: `node scripts/design-system/make-themes.mjs`.
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs'
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
    if (fields.family) out.family = `{font.family.${fields.family}}`
    if (fields.size) out.size = `{font.size.${fields.size}}`
    if (fields.weight) out.weight = `{font.weight.${fields.weight}}`
    if (fields.color) out.color = `{color.${fields.color}}`
    for (const k of ['italic', 'lineHeight', 'tracking']) if (k in fields) out[k] = fields[k]
    for (const [k, v] of Object.entries(out)) if (JSON.stringify(d[k]) !== JSON.stringify(v)) set('semantic', `text.${role}.${k}`, v)
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
  for (const [role, v] of Object.entries(def.size ?? {})) set('semantic', `size.${role}`, v)

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

// ── 2. Papel ─ editorial serif, warm paper, soft shadow ────────────────────────
themes.push({
  id: 'papel', name: 'Papel', axes: ALL,
  blurb: 'Serif editorial sobre papel cálido: el título se lee como un titular, el resto baja en silencio. Esquinas casi rectas y una sombra de hoja sobre la mesa.',
  type: {
    title: { family: 'serif', size: 'xl', weight: 'medium' },
    id: { family: 'mono', size: 'sm', weight: 'semibold', color: 'text-accent' },
    description: { family: 'serif', size: 'lg', color: 'text-secondary' },
    placeholder: { family: 'serif', size: 'lg' },
    repo: { family: 'sans', size: 'sm', weight: 'semibold', tracking: 0.3 },
    location: { size: 'sm' }, eyebrow: { family: 'serif', size: 'sm', italic: true }, footnote: { family: 'serif', size: 'sm', italic: true },
    badge: { size: 'sm', weight: 'semibold', tracking: 0.3 }, swatch: { size: 'sm' }, notice: { family: 'serif', size: 'lg' },
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
  size: { width: 460 },
})

// ── 3. Terminal ─ everything monospaced, square, flat ───────────────────────────
themes.push({
  id: 'terminal', name: 'Terminal', axes: ALL,
  blurb: 'Una pantalla de consola: fósforo verde sobre negro en los dos modos, todo en monoespaciada y esquinas rectas. En oscuro la pantalla sube un tono y el borde se enciende para despegarse del fondo.',
  type: {
    title: { family: 'mono', size: 'lg', weight: 'semibold' },
    id: { family: 'mono', size: 'md', weight: 'regular', color: 'text-accent' },
    description: { family: 'mono', size: 'md' }, placeholder: { family: 'mono', size: 'lg' },
    repo: { family: 'mono', size: 'sm', weight: 'semibold' }, location: { family: 'mono', size: 'sm' },
    badge: { family: 'mono', size: 'sm', weight: 'semibold' }, eyebrow: { family: 'mono', size: 'sm' }, footnote: { family: 'mono', size: 'sm' },
    swatch: { family: 'mono', size: 'sm' }, notice: { family: 'mono', size: 'md' },
  },
  lineHeight: 1.3,
  lh: { title: 1.35, description: 1.5 },
  color: {
    surface: ['#060906FA', '#141A14F7'], 'notice-surface': ['#060906FA', '#141A14F7'],
    border: ['#060906', '#3DFF7A66'],
    'text-primary': ['#D4F7CE', '#D4F7CE'], 'text-secondary': ['#86C081', '#86C081'], 'text-accent': ['#3DFF7A', '#3DFF7A'],
    'badge-bg': ['#3DFF7A26', '#3DFF7A26'], 'badge-fg': ['#9BFFB8', '#9BFFB8'], 'origin-bg': ['#FFB00033', '#FFB00033'], 'origin-fg': ['#FFD27A', '#FFD27A'],
    'swatch-border': ['#3DFF7A99', '#3DFF7A99'], 'row-hover': ['#3DFF7A1F', '#3DFF7A1F'],
    shadow: ['#00000000', '#00000000'], 'shadow-edge': ['#00000000', '#00000000'], 'surface-blur': [0, 0], 'suggestion-opacity': [0.7, 0.7],
  },

  shadow: { container: 'none', notice: 'none' },
  radius: { container: 'none', notice: 'none', swatch: 'none', badge: 'none', row: 'none' },
  border: { container: 1, swatch: 1, notice: 1 },
  space: { padding: '12', 'block-gap': '8', 'range-gap': '6', 'range-line-gap': '4', 'entry-gap': '8', 'inline-gap': '8', 'row-gap': '3', 'name-gap': '2', 'swatch-gap': '8', 'swatch-inner-gap': '6', 'badge-x': '5', 'badge-y': '1', 'notice-x': '10', 'notice-y': '6', 'row-pad-x': '6', 'row-pad-y': '3', 'meta-gap': '3' },
  size: { width: 480 },
})

// ── 4. Neón ─ dark-first, saturated accent, glow as shadow ─────────────────────
themes.push({
  id: 'neon', name: 'Neón', axes: ALL,
  blurb: 'Un rótulo de neón: tubo rosa sobre ciruela profundo en los dos modos, el color cálido de la familia. En claro, una sombra oscura lo asienta y un halo corto del color del tubo lo enciende; en oscuro la luz se derrama alrededor.',
  type: {
    title: { size: 'xl', weight: 'semibold' },
    id: { family: 'mono', size: 'md', weight: 'semibold', color: 'text-accent', tracking: 0.2 },
    description: { size: 'lg' }, placeholder: { size: 'lg' },
    repo: { size: 'sm', weight: 'bold', tracking: 0.4 }, location: { size: 'sm' }, badge: { size: 'sm', weight: 'bold', tracking: 0.4 },
    eyebrow: { size: 'sm', weight: 'medium', tracking: 0.3 }, footnote: { size: 'sm' }, swatch: { size: 'sm' }, notice: { size: 'lg' },
  },
  lh: { title: 1.3, description: 1.45 },
  color: {
    surface: ['#1F0D24F7', '#2A1430F2'], 'notice-surface': ['#1F0D24F7', '#2A1430F2'],
    border: ['#FF4FB0', '#FF4FB0E6'],
    'text-primary': ['#FFF0F8', '#FFF0F8'], 'text-secondary': ['#E7B8D6', '#E7B8D6'], 'text-accent': ['#FF6EC7', '#FF6EC7'],
    'badge-bg': ['#FF4FB026', '#FF4FB026'], 'badge-fg': ['#FFC2E3', '#FFC2E3'], 'origin-bg': ['#FFB34733', '#FFB34733'], 'origin-fg': ['#FFD9A3', '#FFD9A3'],
    'swatch-border': ['#FF6EC7CC', '#FF6EC7CC'], 'row-hover': ['#FF4FB01F', '#FF4FB01F'],
    shadow: ['#2A0A2266', '#FF4FB03D'], 'shadow-edge': ['#FF3EA5F2', '#FF4FB0B3'], 'surface-blur': [24, 24], 'suggestion-opacity': [0.7, 0.7],
  },


  shadows: { glow: [{ x: 0, y: 10, blur: 32, spread: 0, color: '{color.shadow}' }, { x: 0, y: 0, blur: 16, spread: 1, color: '{color.shadow-edge}' }] },
  shadow: { container: 'glow', notice: 'glow' },
  radius: { container: 'xl', notice: 'lg', swatch: 'md', badge: 'pill', row: 'md' },
  border: { container: 1, swatch: 1, notice: 1 },
  space: { padding: '16', 'block-gap': '12', 'range-gap': '10', 'range-line-gap': '6', 'entry-gap': '10', 'inline-gap': '8', 'row-gap': '5', 'name-gap': '3', 'swatch-gap': '12', 'swatch-inner-gap': '6', 'badge-x': '8', 'badge-y': '2', 'notice-x': '14', 'notice-y': '10', 'row-pad-x': '8', 'row-pad-y': '4', 'meta-gap': '4' },
  size: { width: 440 },
})

// ── 5. Compacto ─ dense and quiet ───────────────────────────────────────────────
themes.push({
  id: 'compacto', name: 'Compacto', axes: ALL,
  blurb: 'Lo más denso que sigue siendo legible: ancho mínimo, espacios cortos, esquinas mínimas y una sombra apenas insinuada. Para quien lo ve cien veces al día.',
  type: {
    title: { size: 'md', weight: 'semibold' }, id: { size: 'sm', weight: 'semibold' }, description: { size: 'md' },
    placeholder: { size: 'md' }, repo: { size: 'xs' }, location: { size: 'xs' }, badge: { size: 'xs' }, eyebrow: { size: 'xs' },
    footnote: { size: 'xs' }, swatch: { size: 'xs' }, notice: { size: 'md' },
  },
  lineHeight: 1.15,
  lh: { title: 1.2, description: 1.3 },
  color: {
    surface: ['#F4F4F6F5', '#242426F5'], 'notice-surface': ['#F4F4F6F5', '#242426F5'],
    border: ['#00000026', '#FFFFFF2E'],
    'text-primary': ['#101012', '#F2F2F5'], 'text-secondary': ['#4D4D55', '#B4B4BE'], 'text-accent': ['#0050C8', '#7DB0FF'],
    'badge-bg': ['#0000001A', '#FFFFFF1F'], 'badge-fg': ['#101012', '#F2F2F5'], 'origin-bg': ['#FF950033', '#FF9F0A33'], 'origin-fg': ['#4A2A00', '#FFD9A3'],
    'swatch-border': ['#000000A6', '#FFFFFF66'], 'row-hover': ['#0050C814', '#7DB0FF1F'],
    shadow: ['#00000024', '#00000080'], 'shadow-edge': ['#0000001A', '#00000040'], 'surface-blur': [12, 12], 'suggestion-opacity': [0.75, 0.75],
  },
  shadow: { container: 'sm', notice: 'sm' },
  radius: { container: 'xs', notice: 'xs', swatch: 'xs', badge: 'xs', row: 'xs' },
  border: { container: 1, swatch: 1, notice: 1 },
  space: { padding: '8', 'block-gap': '8', 'range-gap': '5', 'range-line-gap': '3', 'entry-gap': '6', 'inline-gap': '5', 'row-gap': '3', 'name-gap': '1', 'swatch-gap': '6', 'swatch-inner-gap': '4', 'badge-x': '4', 'badge-y': '1', 'notice-x': '8', 'notice-y': '5', 'row-pad-x': '4', 'row-pad-y': '2', 'meta-gap': '2' },
  size: { width: 360, swatch: 16 },
})

// ── 6. Grande ─ legibility first, AAA ───────────────────────────────────────────
themes.push({
  id: 'grande', name: 'Grande', axes: ALL, aaa: true,
  blurb: 'Legibilidad máxima: letra de 13 a 17 pt, contraste AAA, borde grueso, fondo sin transparencia y mucho aire. El tema que no pide esfuerzo.',
  type: {
    title: { size: '2xl', weight: 'semibold' }, id: { size: 'xl', weight: 'semibold' }, description: { size: 'xl', color: 'text-primary' },
    placeholder: { size: 'xl' }, repo: { size: 'lg', weight: 'bold' }, location: { size: 'lg' }, badge: { size: 'md', weight: 'bold' },
    eyebrow: { size: 'lg', weight: 'medium' }, footnote: { size: 'lg' }, swatch: { size: 'lg' }, notice: { size: 'xl', color: 'text-primary' },
  },
  lineHeight: 1.35,
  lh: { title: 1.3, description: 1.55, placeholder: 1.45 },
  color: {
    surface: ['#FFFFFFFF', '#121212FF'], 'notice-surface': ['#FFFFFFFF', '#121212FF'],
    border: ['#1A1A1A', '#FFFFFF'],
    'text-primary': ['#000000', '#FFFFFF'], 'text-secondary': ['#2E2E2E', '#DCDCDC'], 'text-accent': ['#003A9E', '#A8C8FF'],
    'badge-bg': ['#E3E3E3', '#333333'], 'badge-fg': ['#000000', '#FFFFFF'], 'origin-bg': ['#FFE3A3', '#6B4A00'], 'origin-fg': ['#2E1F00', '#FFF3D6'],
    'swatch-border': ['#1A1A1A', '#FFFFFF'], 'row-hover': ['#003A9E1F', '#A8C8FF29'],
    shadow: ['#00000040', '#00000099'], 'shadow-edge': ['#00000026', '#00000066'], 'surface-blur': [0, 0], 'suggestion-opacity': [0.85, 0.85],
  },
  shadow: { container: 'md', notice: 'md' },
  radius: { container: 'xl', notice: 'lg', swatch: 'md', badge: 'md', row: 'md' },
  border: { container: 2, swatch: 2, notice: 2 },
  space: { padding: '20', 'block-gap': '14', 'range-gap': '12', 'range-line-gap': '8', 'entry-gap': '12', 'inline-gap': '8', 'row-gap': '6', 'name-gap': '3', 'swatch-gap': '14', 'swatch-inner-gap': '8', 'badge-x': '8', 'badge-y': '3', 'notice-x': '16', 'notice-y': '12', 'row-pad-x': '8', 'row-pad-y': '5', 'meta-gap': '5' },
  size: { width: 520, swatch: 28 },
})

// ── 7. Brutalista ─ flat colour, thick border, hard shadow ──────────────────────
themes.push({
  id: 'brutalista', name: 'Brutalista', axes: ALL,
  blurb: 'Neobrutalismo: tarjeta limón con trazo negro de 3 pt, esquinas redondeadas y sombra negra dura, sin desenfoque. Los detalles, planos en menta, salmón y lavanda. En oscuro la tarjeta sigue de color y la sombra se vuelve lavanda. Jerarquía por peso, no por gris.',
  type: {
    title: { size: 'xl', weight: 'bold' }, id: { family: 'mono', size: 'md', weight: 'bold', color: 'text-primary' },
    description: { size: 'lg', weight: 'medium', color: 'text-primary' }, placeholder: { size: 'lg', weight: 'medium' },
    repo: { size: 'sm', weight: 'bold' }, location: { size: 'sm', weight: 'medium', color: 'text-primary' }, badge: { size: 'sm', weight: 'bold' },
    eyebrow: { size: 'sm', weight: 'bold', color: 'text-primary' }, footnote: { size: 'sm', weight: 'medium', color: 'text-primary' },
    swatch: { size: 'sm', weight: 'medium', color: 'text-primary' }, notice: { size: 'lg', weight: 'bold', color: 'text-primary' },
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
  size: { width: 440 },
})

// ── 8. Cristal ─ big radius, glow edge, deep diffuse shadow ─────────────────────
themes.push({
  id: 'cristal', name: 'Cristal', axes: ALL,
  blurb: 'Vidrio esmerilado: fondo translúcido con desenfoque fuerte, esquinas de 20 pt, borde de luz y una sombra profunda y difusa.',
  type: {
    title: { size: 'xl', weight: 'medium', tracking: 0.1 }, id: { size: 'md', weight: 'semibold' }, description: { size: 'lg' },
    placeholder: { size: 'lg' }, repo: { size: 'sm', weight: 'semibold' }, location: { size: 'sm' }, badge: { size: 'sm', weight: 'semibold' },
    eyebrow: { size: 'sm', weight: 'medium' }, footnote: { size: 'sm' }, swatch: { size: 'sm' }, notice: { size: 'lg' },
  },
  lineHeight: 1.25,
  lh: { title: 1.3, description: 1.45 },
  color: {
    surface: ['#FFFFFFDB', '#141A2CC8'], 'notice-surface': ['#FFFFFFDB', '#141A2CC8'],
    border: ['#FFFFFFE6', '#FFFFFF3D'],
    'text-primary': ['#0B1B2E', '#F5F8FF'], 'text-secondary': ['#2F4259', '#CBD6EC'], 'text-accent': ['#0A3FA8', '#9EC1FF'],
    'badge-bg': ['#0A3FA81A', '#9EC1FF29'], 'badge-fg': ['#082F7C', '#D6E6FF'], 'origin-bg': ['#FF8A3D33', '#FF9F4A33'], 'origin-fg': ['#552200', '#FFD9B8'],
    'swatch-border': ['#0B1B2EB3', '#FFFFFF80'], 'row-hover': ['#0A3FA81A', '#9EC1FF24'],
    shadow: ['#1B2A4A40', '#00000080'], 'shadow-edge': ['#1B2A4A33', '#00000040'], 'surface-blur': [40, 40], 'suggestion-opacity': [0.72, 0.72],
  },
  shadows: { deep: [{ x: 0, y: 28, blur: 64, spread: -8, color: '{color.shadow}' }, { x: 0, y: 2, blur: 6, spread: 0, color: '{color.shadow-edge}' }] },
  shadow: { container: 'deep', notice: 'deep' },
  radius: { container: '2xl', notice: 'xl', swatch: 'lg', badge: 'pill', row: 'md' },
  border: { container: 1, swatch: 1, notice: 1 },
  space: { padding: '18', 'block-gap': '12', 'range-gap': '10', 'range-line-gap': '6', 'entry-gap': '10', 'inline-gap': '8', 'row-gap': '5', 'name-gap': '3', 'swatch-gap': '12', 'swatch-inner-gap': '6', 'badge-x': '8', 'badge-y': '2', 'notice-x': '16', 'notice-y': '10', 'row-pad-x': '8', 'row-pad-y': '4', 'meta-gap': '4' },
  size: { width: 460 },
})

// ── 9. Ficha (Tile) ─ rounded type, pressable cyan card ───────────────────────────────────────
themes.push({
  id: 'ficha', name: 'Ficha', axes: ALL,
  blurb: 'Una interfaz de juego: tarjeta cian clara como un botón, con un borde cian bien marcado y un canto inferior grueso del mismo cian más oscuro; en oscuro, la tarjeta pasa a azul petróleo, esquinas generosas y letra redondeada gruesa. Las insignias, blancas como fichas. Amable sin ser infantil: la jerarquía sigue mandando.',
  type: {
    title: { family: 'rounded', size: 'xl', weight: 'semibold' }, id: { family: 'mono', size: 'md', weight: 'semibold', color: 'text-accent' },
    description: { family: 'rounded', size: 'lg' }, placeholder: { family: 'rounded', size: 'lg' },
    repo: { family: 'rounded', size: 'sm', weight: 'bold' }, location: { size: 'sm' }, badge: { family: 'rounded', size: 'sm', weight: 'bold' },
    eyebrow: { family: 'rounded', size: 'sm', weight: 'bold', color: 'text-accent', tracking: 0.4 }, footnote: { family: 'rounded', size: 'sm' }, swatch: { size: 'sm' }, notice: { family: 'rounded', size: 'lg' },
  },
  lineHeight: 1.3,
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
  size: { width: 440 },
})

// ── 10. Blueprint ─ technical drawing ───────────────────────────────────────────
themes.push({
  id: 'blueprint', name: 'Blueprint', axes: ALL,
  blurb: 'Un plano de cianotipia: azul de Prusia con línea y letra blancas en los dos modos, identificadores y rutas en monoespaciada y una sombra de dibujo desplazada. En oscuro, el azul baja un tono.',
  type: {
    title: { size: 'lg', weight: 'semibold' }, id: { family: 'mono', size: 'md', weight: 'semibold', color: 'text-accent' },
    description: { size: 'md' }, placeholder: { size: 'lg' }, repo: { family: 'mono', size: 'sm', weight: 'semibold' },
    location: { size: 'sm' }, badge: { family: 'mono', size: 'sm', weight: 'semibold', tracking: 0.4 },
    eyebrow: { family: 'mono', size: 'sm', tracking: 0.5 }, footnote: { family: 'mono', size: 'sm' }, swatch: { size: 'sm' }, notice: { family: 'mono', size: 'md' },
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
  size: { width: 440 },
})

// ── single-group variants, to prove independence ────────────────────────────────
variants.push({
  id: 'ind-type', name: 'Solo tipografía', axes: ['type'], blurb: 'Lupita con otra letra: serif, títulos mayores. Nada más cambia.',
  type: { title: { family: 'serif', size: 'xl', weight: 'semibold' }, description: { family: 'serif', size: 'lg' }, placeholder: { family: 'serif' }, id: { size: 'lg' } },
})
variants.push({
  id: 'ind-color', name: 'Solo color', axes: ['color'], blurb: 'Lupita con otra paleta: pizarra y acento naranja. Mismas formas, mismos espacios, misma letra.',
  color: {
    surface: ['#EEF1F5F5', '#1F2630F5'], 'notice-surface': ['#EEF1F5F5', '#1F2630F5'], border: ['#2C3A4E33', '#CBD6E640'],
    'text-primary': ['#18212D', '#F1F4F8'], 'text-secondary': ['#4A5A70', '#B7C3D4'], 'text-accent': ['#B4470A', '#FFA866'],
    'badge-bg': ['#2C3A4E1F', '#CBD6E62E'], 'badge-fg': ['#18212D', '#F1F4F8'], 'origin-bg': ['#B4470A29', '#FFA86633'], 'origin-fg': ['#5A2300', '#FFD9BD'],
    'swatch-border': ['#2C3A4E66', '#CBD6E699'], 'row-hover': ['#B4470A14', '#FFA8661F'],
    shadow: ['#18212D47', '#00000099'], 'shadow-edge': ['#18212D1A', '#00000040'], 'surface-blur': [20, 20], 'suggestion-opacity': [0.75, 0.75],
  },
})
variants.push({
  id: 'ind-shape', name: 'Solo forma', axes: ['shape'], blurb: 'Lupita con esquinas de 20 pt, cápsulas más cuadradas y borde de 2 pt. Mismo color, letra y espacios.',
  radius: { container: '2xl', notice: 'xl', swatch: 'lg', badge: 'sm' }, border: { container: 2, swatch: 2, notice: 2 },
})
variants.push({
  id: 'ind-space', name: 'Solo espacio', axes: ['space'], blurb: 'Lupita con más aire y más ancho. Mismo color, letra y formas.',
  space: { padding: '20', 'block-gap': '14', 'range-gap': '12', 'range-line-gap': '8', 'entry-gap': '12', 'inline-gap': '8', 'row-gap': '6', 'name-gap': '3', 'swatch-gap': '12', 'swatch-inner-gap': '6', 'badge-x': '8', 'badge-y': '2', 'notice-x': '16', 'notice-y': '10' },
  size: { width: 500 },
})
variants.push({
  id: 'ind-shadow', name: 'Solo sombra', axes: ['shadow'], blurb: 'Lupita con una sombra grande y alta, como si flotara. Mismo color, letra, formas y espacios.',
  shadow: { container: 'lg', notice: 'lg' },
})

mkdirSync(`${DS}/themes`, { recursive: true })
mkdirSync(`${DS}/variants`, { recursive: true })
for (const t of themes) { writeFileSync(`${DS}/themes/${t.id}.json`, JSON.stringify(build(t), null, 2) + '\n'); console.log('theme  ', t.id) }
for (const v of variants) { writeFileSync(`${DS}/variants/${v.id}.json`, JSON.stringify(build(v), null, 2) + '\n'); console.log('variant', v.id) }
