# Tooltip inventory: every style line → token

Source: `Sources/LupitaApp/TooltipPanel.swift` (`TooltipView`, `Swatch`, `NoticeView`).
Every style line reads the tokens through a `TooltipTheme` (`theme.space.*`, `theme.radius.*`, `.themed(role, theme)`, `themedSurface`…; the translation to SwiftUI lives in `ThemeStyle.swift`). `check-inventory.mjs` fails on any style line without `theme` or with a numeric literal, and checks that each style line has exactly one row and that the quoted code is still on that line.
Tokens are named in [tokens.json](tokens.json). `structural` = layout behaviour with no visual value to theme.

## Text roles (what each piece of text is)

| Role | Used for | In the view |
|---|---|---|
| `text.title` | what the thing is / means | `.themed(.title, theme)` |
| `text.id` | the cited name: ID, symbol, file | `.themed(.id, theme)` |
| `text.description` | the explanation | `.themed(.description, theme)` |
| `text.repo` | where it comes from | `.themed(.repo, theme)` |
| `text.location` | `path:line` | `.themed(.location, theme)` |
| `text.badge` | kind («término», «rama») and «de otro repo» | `.themed(.badge, theme)` |
| `text.eyebrow` | «¿Querías decir…?», «Lectura dudosa», header of a range | `.themed(.eyebrow, theme)` |
| `text.footnote` | «+2 más», «citado 12 veces» | `.themed(.footnote, theme)` |
| `text.placeholder` | «sin definición», «sin comentario» | `.themed(.placeholder, theme)` |
| `text.swatch` | colour label | `.themed(.swatch, theme)` |
| `text.notice` | the small notices | `.themed(.notice, theme)` |

## Rows

| Line | Code | Token(s) |
|---|---|---|
| 159 | `VStack(alignment: .leading, spacing: theme.space.rangeGap) {` | space.range-gap |
| 160 | `Text(S.rangeHeader(list.count, noun: list.noun)).themed(.eyebrow, theme)` | text.eyebrow |
| 161 | `VStack(alignment: .leading, spacing: theme.space.rangeLineGap) {` | space.range-line-gap |
| 164 | `case .more(let n): Text(S.rangeMore(n)).themed(.description, theme)` | text.description |
| 170 | `HStack(spacing: theme.space.inlineGap) {` | space.inline-gap |
| 171 | `if let repo = list.sharedRepo { Text(repo).themed(.repo, theme) }` | text.repo |
| 172 | `if let path = list.sharedPath { Text(path).themed(.location, theme).lineLimit(theme.limits.locationLines).truncationMode(.middle) }` | text.location, limits.location-lines, truncation: structural |
| 176 | `.padding(theme.space.padding)` | space.padding |
| 177 | `.frame(width: theme.width, alignment: .leading)` | size.width |
| 178 | `.themedSurface(theme, fill: theme.colors.surface, radius: theme.radius.container, borderWidth: theme.border.container, shadow: theme.containerShadow)` | radius.container, border.container, color.surface, shadow.container, color.surface-blur, border.container/notice (stroke inside the shape), shadow layers |
| 184 | `HStack(alignment: .firstTextBaseline, spacing: theme.space.entryGap) {` | space.entry-gap |
| 185 | `Text(e.id).themed(.id, theme)` | text.id |
| 186 | `Text(d.title).themed(.title, theme).lineLimit(theme.limits.rangeTitleLines).truncationMode(.tail)` | text.title, limits.range-title-lines, truncation: structural |
| 194 | `HStack(alignment: .firstTextBaseline, spacing: theme.space.entryGap) {` | space.entry-gap |
| 195 | `Text(e.id).themed(.id, theme)` | text.id |
| 196 | `Text(S.notDefined).themed(.placeholder, theme)` | text.placeholder |
| 202 | `VStack(alignment: .leading, spacing: theme.space.blockGap) {` | space.block-gap |
| 204 | `Text(S.didYouMean(resolution.key ?? "", read: resolution.query)).themed(.eyebrow, theme)` | text.eyebrow |
| 206 | `Text(S.unclearReading(resolution.query)).themed(.eyebrow, theme)` | text.eyebrow |
| 210 | `.opacity(resolution.isSuggestion ? theme.suggestionOpacity : 1)` | color.suggestion-opacity |
| 213 | `Text(S.moreDefinitions(resolution.definitions.count - theme.limits.maxRows)).themed(.footnote, theme)` | text.footnote, limits.max-rows |
| 216 | `Text(S.cited(m.count, files: m.files.count)).themed(.footnote, theme)` | text.footnote |
| 219 | `.padding(theme.space.padding)` | space.padding |
| 220 | `.frame(width: theme.width, alignment: .leading)` | size.width |
| 221 | `.themedSurface(theme, fill: theme.colors.surface, radius: theme.radius.container, borderWidth: theme.border.container, shadow: theme.containerShadow)` | radius.container, border.container, color.surface, shadow.container, color.surface-blur, border.container/notice (stroke inside the shape), shadow layers |
| 237 | `VStack(alignment: .leading, spacing: theme.space.rowGap) {` | space.row-gap |
| 239 | `VStack(alignment: .leading, spacing: theme.space.nameGap) {` | space.name-gap |
| 242 | `Text(d.id).themed(.id, theme)` | text.id |
| 243 | `.lineLimit(theme.limits.idLines).truncationMode(.middle)` | limits.id-lines, truncation: structural |
| 246 | `Text(S.noComment).themed(.placeholder, theme)` | text.placeholder |
| 248 | `Text(d.title).themed(.title, theme).lineLimit(theme.limits.titleLines).fixedSize(horizontal: false, vertical: true)` | text.title, limits.title-lines |
| 252 | `HStack(spacing: theme.space.swatchGap) { ForEach(Array(colors.enumerated()), id: \.offset) { _, c in Swatch(sample: c, theme: theme) } }` | space.swatch-gap |
| 255 | `Text(d.summary).themed(.description, theme).lineLimit(theme.limits.descriptionLines).fixedSize(horizontal: false, vertical: true)` | text.description, limits.description-lines |
| 257 | `HStack(spacing: theme.space.inlineGap) {` | space.inline-gap |
| 261 | `if !d.repo.isEmpty { Text(d.repo).themed(.repo, theme) }` | text.repo |
| 263 | `Text(location).themed(.location, theme).lineLimit(theme.limits.locationLines).truncationMode(.middle)` | text.location, limits.location-lines, truncation: structural |
| 269 | `.padding(.top, theme.space.metaGap)` | space.meta-gap |
| 276 | `Text(text).themed(.badge, theme).foregroundStyle(Color(rgba: fg))` | text.badge |
| 277 | `.padding(.horizontal, theme.space.badgeX).padding(.vertical, theme.space.badgeY)` | space.badge-x, space.badge-y |
| 278 | `.background(Color(rgba: bg), in: theme.shape(theme.radius.badge))` | radius.badge |
| 334 | `.padding(.horizontal, theme.space.rowPadX).padding(.vertical, theme.space.rowPadY)` | space.row-pad-x, space.row-pad-y |
| 335 | `.background(hovered.wrappedValue ? Color(rgba: theme.colors.rowHover) : Color.clear, in: theme.shape(theme.radius.row))` | radius.row, color.row-hover |
| 336 | `.padding(.horizontal, -theme.space.rowPadX).padding(.vertical, -theme.space.rowPadY)` | space.row-pad-x, space.row-pad-y |
| 347 | `HStack(spacing: theme.space.swatchInnerGap) {` | space.swatch-inner-gap |
| 348 | `theme.shape(theme.radius.swatch)` | radius.swatch |
| 350 | `.frame(width: theme.swatchSize, height: theme.swatchSize)` | size.swatch |
| 351 | `.overlay(theme.shape(theme.radius.swatch).strokeBorder(Color(rgba: theme.colors.swatchBorder), lineWidth: theme.border.swatch))` | radius.swatch, border.swatch, color.swatch-border |
| 352 | `Text(sample.label.isEmpty ? sample.hex : "\(sample.label) \(sample.hex)").themed(.swatch, theme)` | text.swatch |
| 361 | `Text(text).themed(.notice, theme)` | text.notice |
| 362 | `.padding(.horizontal, theme.space.noticeX).padding(.vertical, theme.space.noticeY)` | space.notice-x, space.notice-y |
| 363 | `.frame(maxWidth: theme.width, alignment: .leading)` | size.width |
| 365 | `.themedSurface(theme, fill: theme.colors.noticeSurface, radius: theme.radius.notice, borderWidth: theme.border.notice, shadow: theme.noticeShadow)` | radius.notice, border.notice, color.notice-surface, shadow.notice, color.surface-blur, border.container/notice (stroke inside the shape), shadow layers |
