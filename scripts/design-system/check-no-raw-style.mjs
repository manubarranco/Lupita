#!/usr/bin/env node
// Fails when the static stylesheet of docs/design-system/prototype.html holds a style value of its own.
// Scanned: the text between /*STATIC*/ and /*END-STATIC*/. Exempt: generated variables and <style id="chrome">.
import { readFileSync } from 'node:fs'
import { DS } from './lib.mjs'

const file = process.argv[2] ?? `${DS}/prototype.html`
const html = readFileSync(file, 'utf8')
const m = html.match(/\/\*STATIC\*\/([\s\S]*?)\/\*END-STATIC\*\//)
if (!m) { console.error('no /*STATIC*/ … /*END-STATIC*/ block found'); process.exit(1) }
const css = m[1].replace(/\/\*[\s\S]*?\*\//g, '')

const NAMED = 'aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgray darkgreen darkgrey darkorange darkred darkslategray gainsboro ghostwhite gold goldenrod gray green grey honeydew hotpink indigo ivory khaki lavender lime linen magenta maroon navy olive orange orchid peru pink plum purple red salmon seagreen silver skyblue slategray snow tan teal tomato turquoise violet wheat white whitesmoke yellow'.split(' ')
const LENGTH_PROPS = /^(font-size|padding(-[a-z]+)?|margin(-[a-z]+)?|gap|row-gap|column-gap|border|border-(top|right|bottom|left)|border-radius|border-[a-z]+-radius|border-width|border-[a-z]+-width|width|min-width|max-width|height|min-height|max-height|box-shadow|letter-spacing|top|left|right|bottom|inset)$/
const COLOR_PROPS = /(^|-)(color|background|fill|stroke|shadow|border|outline)(-|$)/
const violations = []

for (const block of css.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
  const selector = block[1].trim()
  for (const decl of block[2].split(';')) {
    const i = decl.indexOf(':'); if (i < 0) continue
    const prop = decl.slice(0, i).trim().toLowerCase(), value = decl.slice(i + 1).trim()
    const where = `${selector} { ${prop}: ${value} }`
    const bare = value.replace(/var\(--[\w-]+\)/g, '') // var(--x, fallback) keeps its fallback in the scan
    if (/#[0-9a-f]{3,8}\b/i.test(bare) || /\b(rgba?|hsla?|hwb|lab|lch|oklab|oklch|color-mix)\(/i.test(bare)) violations.push(`colour literal: ${where}`)
    if (COLOR_PROPS.test(prop) && prop !== 'content') for (const w of bare.toLowerCase().match(/[a-z]+/g) ?? []) if (NAMED.includes(w)) violations.push(`named colour «${w}»: ${where}`)
    if (LENGTH_PROPS.test(prop)) {
      for (const n of bare.matchAll(/(^|[^\w.-])(-?\d*\.?\d+)(px|pt|em|rem)\b/g)) if (parseFloat(n[2]) !== 0) { violations.push(`length literal: ${where}`); break }
    }
    if (prop === 'font-family' && !/^(var\(--[\w-]+\)|inherit|initial|unset)$/.test(value)) violations.push(`font-family literal: ${where}`)
    if (prop === 'font-weight' && /\d|bold|lighter|bolder/.test(bare)) violations.push(`font-weight literal: ${where}`)
    if (prop === 'opacity' && /\d/.test(bare)) violations.push(`opacity literal: ${where}`)
    if (prop === 'line-height' && /\d/.test(bare)) violations.push(`line-height literal: ${where}`)
  }
}
violations.forEach(v => console.error('  ' + v))
console.log(`check-no-raw-style: ${violations.length} violations`)
process.exit(violations.length ? 1 : 0)
