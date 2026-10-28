/* Client of docs/design-system/prototype.html. Inlined by build-prototype.mjs.
   It holds NO style value of the tooltip: it only turns resolved tokens into CSS custom properties. */
(function () {
  'use strict'
  var DATA = JSON.parse(document.getElementById('proto-data').textContent)
  var THEMES = DATA.themes, STATES = DATA.states
  var UNITLESS = { 'color.suggestion-opacity': 1 }

  function themeById(id) { return THEMES.find(function (t) { return t.id === id }) || THEMES[0] }
  function stateById(id) { return STATES.find(function (s) { return s.id === id }) || STATES[0] }
  /** CSS font-family for a text role: the macOS font by name, then the stand-in of its system fallback. */
  function famCss(res, t) {
    var f = res['font.family.' + t.familyKey]
    return f.primary === 'system' ? 'var(--font-fb-' + f.fallback + ')' : '"' + f.primary + '", var(--font-fb-' + f.fallback + ')'
  }
  function px(n) { return n + 'px' }

  /** Resolved flat map → { '--css-var': value }. */
  function varsFor(res) {
    var v = {}
    Object.keys(res).forEach(function (k) {
      var val = res[k], name = '--' + k.replace(/^component\.limits\./, 'limit-').replace(/\./g, '-')
      if (k.indexOf('font.family.') === 0) return
      if (k.indexOf('text.') === 0) {
        v[name + '-family'] = famCss(res, val)
        v[name + '-size'] = px(val.size)
        v[name + '-weight'] = String(val.weight)
        v[name + '-style'] = val.italic ? 'italic' : 'normal'
        v[name + '-lh'] = String(val.lineHeight)
        v[name + '-tracking'] = px(val.tracking)
        v[name + '-color'] = val.color
      } else if (k.indexOf('shadow.') === 0) {
        v[name] = val.length ? val.map(function (l) { return px(l.x) + ' ' + px(l.y) + ' ' + px(l.blur) + ' ' + px(l.spread) + ' ' + l.color }).join(', ') : '0 0 0 0 transparent'
      } else if (k.indexOf('component.limits.') === 0) {
        if (typeof val === 'number') v[name] = String(val)
      } else if (typeof val === 'number') {
        v[name] = UNITLESS[k] ? String(val) : px(val)
      } else v[name] = String(val)
    })
    return v
  }

  function setPath(res, path, value) {
    var parts = path.split('.'), key = parts.slice(0, 2).join('.'), rest = parts.slice(2)
    if (!(key in res)) { res[path] = value; return }
    if (!rest.length) { res[key] = value; return }
    var node = res[key] = JSON.parse(JSON.stringify(res[key]))
    for (var i = 0; i < rest.length - 1; i++) node = node[rest[i]]
    node[rest[rest.length - 1]] = value
  }
  function getPath(res, path) {
    var parts = path.split('.'), key = parts.slice(0, 2).join('.'), node = res[key]
    parts.slice(2).forEach(function (p) { node = node == null ? node : node[p] })
    return node
  }
  function effective(themeId, mode, overrides, size, density) {
    var th = themeById(themeId), res = Object.assign({}, th[mode])
    var delta = th.deltas[(size || 'M') + '/' + (density || 'normal')]
    if (delta) Object.assign(res, delta[mode])
    Object.keys(overrides || {}).forEach(function (p) { setPath(res, p, overrides[p]) })
    return res
  }
  function applyVars(container, res) {
    ;(container._keys || []).forEach(function (k) { container.style.removeProperty(k) })
    var v = varsFor(res)
    Object.keys(v).forEach(function (k) { container.style.setProperty(k, v[k]) })
    container._keys = Object.keys(v)
  }

  // ── DOM helpers ───────────────────────────────────────────────────────────
  function h(tag, cls, text, role) {
    var e = document.createElement(tag)
    if (cls) e.className = cls
    if (text != null) e.textContent = text
    if (role) e.dataset.role = role
    return e
  }
  function T(role, cls, text, dataRole) { return h('div', 't-' + role + (cls ? ' ' + cls : ''), text, dataRole || role) }
  function trunc(el, mode, lines) { el.dataset.trunc = mode; el.dataset.lines = lines; el.classList.add(lines === 1 ? 'one-line' : 'multi-line'); return el }

  // ── truncation (SwiftUI truncationMode: middle / tail) ────────────────────
  function cut(full, n, mode) {
    if (mode === 'middle') { var a = Math.ceil(n / 2); return full.slice(0, a) + '…' + full.slice(full.length - (n - a)) }
    if (mode === 'head') return '…' + full.slice(full.length - n)
    return full.slice(0, n).replace(/\s+$/, '') + '…'
  }
  function over(el, lines) {
    if (lines === 1) return el.scrollWidth > el.clientWidth
    var lh = parseFloat(getComputedStyle(el).lineHeight) || 0
    return el.getBoundingClientRect().height > lines * lh + 0.5
  }
  function fit(el) {
    var lines = +el.dataset.lines, mode = el.dataset.trunc
    if (el.dataset.full == null) el.dataset.full = el.textContent
    var full = el.dataset.full
    el.textContent = full
    if (!over(el, lines)) return
    var lo = 0, hi = full.length
    while (lo < hi) {
      var mid = (lo + hi + 1) >> 1
      el.textContent = cut(full, mid, mode)
      if (over(el, lines)) hi = mid - 1; else lo = mid
    }
    el.textContent = cut(full, lo, mode)
  }
  function fitAll(root) { root.querySelectorAll('[data-trunc]').forEach(fit) }

  // ── tooltip views (mirror TooltipView / NoticeView in TooltipPanel.swift) ─
  function lim(res, k, d) { var v = res['component.limits.' + k]; return v == null ? d : v }

  function swatch(s) {
    var e = h('div', 'swatch')
    var chip = h('div', 'chip'); chip.style.background = s.hex // sample content colour, not a tooltip style
    e.append(chip, T('swatch', '', s.label ? s.label + ' ' + s.hex : s.hex, 'swatch-label'))
    return e
  }

  function buildRow(r, isFirst, res) {
    var row = h('div', 'row' + (r.muted ? ' muted' : '') + (r.hover ? ' hover' : ''))
    var name = h('div', 'name')
    if (r.id && r.kind !== 'git' && r.kind !== 'término')
      name.append(trunc(T('id', '', r.id, 'id'), lim(res, 'id-truncation', 'middle'), lim(res, 'id-lines', 2)))
    if (r.placeholderTitle) name.append(T('placeholder', '', r.placeholderTitle, 'placeholder'))
    else if (r.title) name.append(T('title', 'clamp clamp-title', r.title, 'title'))
    if (name.children.length) row.append(name)
    if (r.swatches && r.swatches.length) {
      var sw = h('div', 'swatches'); r.swatches.forEach(function (s) { sw.append(swatch(s)) }); row.append(sw)
    }
    if (r.description) row.append(T('description', 'clamp clamp-description', r.description, 'description'))
    var meta = h('div', 'meta')
    if (r.kind) meta.append(T('badge', 'badge', r.kind, 'badge'))
    if (r.repo) meta.append(T('repo', 'repo', r.repo, 'repo'))
    if (r.location) meta.append(trunc(T('location', 'location', r.location, 'location'), lim(res, 'location-truncation', 'middle'), lim(res, 'location-lines', 1)))
    if (isFirst && r.origin) meta.append(T('badge', 'badge origin', 'de otro repo', 'badge-origin'))
    if (meta.children.length) row.append(meta)
    return row
  }

  function buildDefinitions(t, res) {
    var root = h('div', 'tooltip')
    if (t.eyebrow) root.append(T('eyebrow', '', t.eyebrow, 'eyebrow'))
    var max = lim(res, 'max-rows', 3)
    t.rows.slice(0, max).forEach(function (r, i) { root.append(buildRow(r, i === 0, res)) })
    if (t.rows.length > max) root.append(T('footnote', '', '+' + (t.rows.length - max) + ' más', 'footnote'))
    ;(t.footnotes || []).forEach(function (f) { root.append(T('footnote', '', f, 'footnote')) })
    return root
  }

  function buildRange(t, res) {
    var root = h('div', 'tooltip range')
    root.append(T('eyebrow', '', t.eyebrow, 'eyebrow'))
    var lines = h('div', 'lines')
    t.entries.forEach(function (e) {
      var line = h('div', 'entry')
      line.append(T('id', 'entry-id', e.id, 'id'))
      if (e.title == null) line.append(T('placeholder', 'entry-title', 'sin definición', 'placeholder'))
      else line.append(trunc(T('title', 'entry-title', e.title, 'title'), lim(res, 'range-title-truncation', 'tail'), lim(res, 'range-title-lines', 1)))
      lines.append(line)
    })
    if (t.more) lines.append(T('description', '', t.more, 'more'))
    root.append(lines)
    if (t.sharedRepo || t.sharedPath) {
      var f = h('div', 'meta')
      if (t.sharedRepo) f.append(T('repo', 'repo', t.sharedRepo, 'repo'))
      if (t.sharedPath) f.append(trunc(T('location', 'location', t.sharedPath, 'location'), lim(res, 'location-truncation', 'middle'), lim(res, 'location-lines', 1)))
      root.append(f)
    }
    return root
  }

  function buildNotice(t) { var n = h('div', 'notice'); n.append(T('notice', '', t.text, 'notice')); return n }

  /** Renders `stateId` into `container` (a .scope element attached to the document) with the theme/mode variables. */
  function renderState(container, stateId, themeId, mode, overrides, size, density) {
    var res = effective(themeId, mode, overrides, size, density)
    container.dataset.size = size || 'M'; container.dataset.density = density || 'normal'
    applyVars(container, res)
    container.dataset.theme = themeId; container.dataset.mode = mode; container.dataset.state = stateId
    container._res = res
    container.replaceChildren()
    var t = stateById(stateId).tooltip
    var el = t.type === 'notice' ? buildNotice(t) : t.type === 'range' ? buildRange(t, res) : buildDefinitions(t, res)
    el.dataset.state = stateId
    container.append(el)
    fitAll(el)
    return el
  }
  /** Re-applies variables (after a token edit) without rebuilding the DOM. */
  function restyle(container, overrides) {
    var res = effective(container.dataset.theme, container.dataset.mode, overrides, container.dataset.size, container.dataset.density)
    applyVars(container, res); container._res = res
    fitAll(container)
  }

  /** Overflow check on a rendered tooltip: root and every [data-role] element must not overflow; width must equal size.width. */
  function overflowCheck(el) {
    var scope = el.parentElement, res = scope._res, out = []
    var nodes = [el].concat(Array.prototype.slice.call(el.querySelectorAll('[data-role]')))
    nodes.forEach(function (n) {
      if (n.scrollWidth > n.clientWidth + 1 && getComputedStyle(n).textOverflow !== 'ellipsis') // an ellipsis is a deliberate clamp, not an overflow
        out.push((n === el ? 'root' : n.dataset.role) + ': scrollWidth ' + n.scrollWidth + ' > clientWidth ' + n.clientWidth + (n.textContent ? ' «' + n.textContent.slice(0, 40) + '»' : ''))
    })
    if (el.dataset.state !== 'notice') {
      var w = el.getBoundingClientRect().width
      if (Math.abs(w - res['size.width']) > 0.5) out.push('width ' + w + ' != size.width ' + res['size.width'])
    }
    return out
  }

  // ── page chrome: faux backdrop ────────────────────────────────────────────
  var LINES = [92, 78, 86, 64, 90, 70, 84, 58, 94, 76, 88, 66, 80, 72, 90, 60]
  function makeCell(mode) {
    var stage = h('div', 'stage'); stage.dataset.mode = mode
    var faux = h('div', 'faux')
    LINES.forEach(function (w) { var i = h('i'); i.style.width = w + '%'; faux.append(i) })
    faux.append(h('b'))
    var scope = h('div', 'scope')
    stage.append(faux, scope)
    return { stage: stage, scope: scope }
  }

  // ── page ──────────────────────────────────────────────────────────────────
  var params = new URLSearchParams(location.search)
  var S = {
    theme: themeById(params.get('theme') || DATA.defaultTheme).id,
    mode: params.get('mode') || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'),
    state: stateById(params.get('state') || 'definition').id,
    size: DATA.sizes.indexOf(params.get('size')) >= 0 ? params.get('size') : 'M',
    density: DATA.densities.indexOf(params.get('density')) >= 0 ? params.get('density') : 'normal',
    view: params.get('view') || 'one',
    over: {}
  }
  if (S.mode !== 'dark') S.mode = 'light'
  var $ = function (id) { return document.getElementById(id) }
  var scopes = []

  function syncUrl() {
    var q = new URLSearchParams({ theme: S.theme, mode: S.mode, state: S.state, size: S.size, density: S.density })
    if (S.view !== 'one') q.set('view', S.view)
    try { history.replaceState(null, '', '?' + q) } catch (e) { /* file:// in some contexts */ }
  }

  function drawMain() {
    document.documentElement.dataset.mode = S.mode
    var main = $('view'); main.replaceChildren(); scopes = []
    var list = S.view === 'all' ? STATES.map(function (s) { return s.id }) : [S.state]
    main.className = S.view === 'all' ? 'grid' : 'single'
    list.forEach(function (id) {
      var box = h('figure', 'card'), cap = h('figcaption', '', stateById(id).label)
      var cell = makeCell(S.mode)
      box.append(cap, cell.stage); main.append(box)
      renderState(cell.scope, id, S.theme, S.mode, S.over, S.size, S.density)
      scopes.push(cell.scope)
    })
    var th = themeById(S.theme)
    $('blurb').textContent = th.name + ' · ' + th.blurb
    syncUrl()
  }
  function restyleAll() { scopes.forEach(function (s) { restyle(s, S.over) }) }

  // live token editor
  function editablePaths() {
    var res = effective(S.theme, S.mode, {}, S.size, S.density), out = []
    DATA.semanticKeys.forEach(function (k) {
      if (k.indexOf('text.') === 0) out.push(k + '.size')
      else if (k.indexOf('shadow.') === 0) (res[k] || []).forEach(function (_, i) { out.push(k + '.' + i + '.blur') })
      else out.push(k)
    })
    return out
  }
  function isColorPath(p) { return p.indexOf('color.') === 0 && typeof getPath(themeById(S.theme)[S.mode], p) === 'string' }
  function fillTokens() {
    var sel = $('tok'), cur = sel.value; sel.replaceChildren()
    var groups = {}
    editablePaths().forEach(function (p) {
      var g = p.split('.')[0]
      if (!groups[g]) { groups[g] = h('optgroup'); groups[g].label = g; sel.append(groups[g]) }
      var o = h('option', '', p); o.value = p; groups[g].append(o)
    })
    if (cur && editablePaths().indexOf(cur) >= 0) sel.value = cur
    showToken()
  }
  function showToken() {
    var p = $('tok').value, res = effective(S.theme, S.mode, S.over, S.size, S.density), v = getPath(res, p)
    var color = isColorPath(p), box = $('tokval')
    box.type = color ? 'text' : 'number'; box.step = (typeof v === 'number' && v % 1) ? '0.05' : '1'
    box.value = v
    $('tokcol').hidden = !color
    if (color && /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v)) $('tokcol').value = v.slice(0, 7)
    $('tokdef').textContent = 'tema: ' + getPath(themeById(S.theme)[S.mode], p) + (p in S.over ? ' · editado' : '')
  }
  function editToken(value) {
    var p = $('tok').value
    S.over[p] = (typeof getPath(themeById(S.theme)[S.mode], p) === 'number') ? parseFloat(value) : value
    if (Number.isNaN(S.over[p])) { delete S.over[p]; return }
    restyleAll(); showToken()
  }

  function init() {
    var ts = $('theme'), ss = $('state')
    THEMES.forEach(function (t) { var o = h('option', '', t.name + (t.variant ? ' (variante)' : '')); o.value = t.id; ts.append(o) })
    STATES.forEach(function (s) { var o = h('option', '', s.label); o.value = s.id; ss.append(o) })
    var sz = $('size'), de = $('density')
    DATA.sizes.forEach(function (x) { var o = h('option', '', x); o.value = x; sz.append(o) })
    DATA.densities.forEach(function (x) { var o = h('option', '', { compact: 'Compacta', normal: 'Normal', airy: 'Amplia' }[x]); o.value = x; de.append(o) })
    sz.value = S.size; de.value = S.density
    sz.onchange = function () { S.size = sz.value; fillTokens(); drawMain() }
    de.onchange = function () { S.density = de.value; fillTokens(); drawMain() }
    ts.value = S.theme; ss.value = S.state
    $('mode').onclick = function () { S.mode = S.mode === 'dark' ? 'light' : 'dark'; $('mode').textContent = S.mode === 'dark' ? 'Oscuro' : 'Claro'; fillTokens(); drawMain() }
    $('mode').textContent = S.mode === 'dark' ? 'Oscuro' : 'Claro'
    $('viewbtn').onclick = function () { S.view = S.view === 'all' ? 'one' : 'all'; $('viewbtn').textContent = S.view === 'all' ? 'Todos los estados' : 'Un estado'; drawMain() }
    $('viewbtn').textContent = S.view === 'all' ? 'Todos los estados' : 'Un estado'
    ts.onchange = function () { S.theme = ts.value; S.over = {}; fillTokens(); drawMain() }
    ss.onchange = function () { S.state = ss.value; drawMain() }
    $('tok').onchange = showToken
    $('tokval').oninput = function () { editToken(this.value) }
    $('tokcol').oninput = function () {
      var cur = String(effective(S.theme, S.mode, S.over, S.size, S.density)[$('tok').value]), alpha = /^#[0-9a-f]{8}$/i.test(cur) ? cur.slice(7) : ''
      editToken(this.value.toUpperCase() + alpha)
    }
    $('reset').onclick = function () { delete S.over[$('tok').value]; restyleAll(); showToken() }
    $('resetall').onclick = function () { S.over = {}; restyleAll(); showToken() }
    fillTokens(); drawMain()
  }

  window.PROTO = { themes: THEMES.map(function (t) { return { id: t.id, name: t.name, blurb: t.blurb, axes: t.axes, variant: !!t.variant } }), states: STATES, renderState: renderState, sizes: DATA.sizes, densities: DATA.densities, makeCell: makeCell, overflowCheck: overflowCheck, varsFor: varsFor, effective: effective }
  window.renderState = renderState
  if (!params.has('noinit')) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init()
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { fitAll(document) })
  }
})()
