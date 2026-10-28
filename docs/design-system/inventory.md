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
| 148 | `VStack(alignment: .leading, spacing: theme.space.rangeGap) {` | space.range-gap |
| 149 | `Text(S.rangeHeader(list.count, noun: list.noun)).themed(.eyebrow, theme)` | text.eyebrow |
| 150 | `VStack(alignment: .leading, spacing: theme.space.rangeLineGap) {` | space.range-line-gap |
| 153 | `case .more(let n): Text(S.rangeMore(n)).themed(.description, theme)` | text.description |
| 159 | `HStack(spacing: theme.space.inlineGap) {` | space.inline-gap |
| 160 | `if let repo = list.sharedRepo { Text(repo).themed(.repo, theme) }` | text.repo |
| 161 | `if let path = list.sharedPath { Text(path).themed(.location, theme).lineLimit(theme.limits.locationLines).truncationMode(.middle) }` | text.location, limits.location-lines, truncation: structural |
| 165 | `.padding(theme.space.padding)` | space.padding |
| 166 | `.frame(width: theme.width, alignment: .leading)` | size.width |
| 167 | `.themedSurface(theme, fill: theme.colors.surface, radius: theme.radius.container, borderWidth: theme.border.container, shadow: theme.containerShadow)` | radius.container, border.container, color.surface, shadow.container, color.surface-blur, border.container/notice (stroke inside the shape), shadow layers |
| 173 | `HStack(alignment: .firstTextBaseline, spacing: theme.space.entryGap) {` | space.entry-gap |
| 174 | `Text(e.id).themed(.id, theme)` | text.id |
| 175 | `Text(d.title).themed(.title, theme).lineLimit(theme.limits.rangeTitleLines).truncationMode(.tail)` | text.title, limits.range-title-lines, truncation: structural |
| 183 | `HStack(alignment: .firstTextBaseline, spacing: theme.space.entryGap) {` | space.entry-gap |
| 184 | `Text(e.id).themed(.id, theme)` | text.id |
| 185 | `Text(S.notDefined).themed(.placeholder, theme)` | text.placeholder |
| 191 | `VStack(alignment: .leading, spacing: theme.space.blockGap) {` | space.block-gap |
| 193 | `Text(S.didYouMean(resolution.key ?? "", read: resolution.query)).themed(.eyebrow, theme)` | text.eyebrow |
| 195 | `Text(S.unclearReading(resolution.query)).themed(.eyebrow, theme)` | text.eyebrow |
| 199 | `.opacity(resolution.isSuggestion ? theme.suggestionOpacity : 1)` | color.suggestion-opacity |
| 202 | `Text(S.moreDefinitions(resolution.definitions.count - theme.limits.maxRows)).themed(.footnote, theme)` | text.footnote, limits.max-rows |
| 205 | `Text(S.cited(m.count, files: m.files.count)).themed(.footnote, theme)` | text.footnote |
| 208 | `.padding(theme.space.padding)` | space.padding |
| 209 | `.frame(width: theme.width, alignment: .leading)` | size.width |
| 210 | `.themedSurface(theme, fill: theme.colors.surface, radius: theme.radius.container, borderWidth: theme.border.container, shadow: theme.containerShadow)` | radius.container, border.container, color.surface, shadow.container, color.surface-blur, border.container/notice (stroke inside the shape), shadow layers |
| 226 | `VStack(alignment: .leading, spacing: theme.space.rowGap) {` | space.row-gap |
| 228 | `VStack(alignment: .leading, spacing: theme.space.nameGap) {` | space.name-gap |
| 231 | `Text(d.id).themed(.id, theme)` | text.id |
| 232 | `.lineLimit(theme.limits.idLines).truncationMode(.middle)` | limits.id-lines, truncation: structural |
| 235 | `Text(S.noComment).themed(.placeholder, theme)` | text.placeholder |
| 237 | `Text(d.title).themed(.title, theme).lineLimit(theme.limits.titleLines).fixedSize(horizontal: false, vertical: true)` | text.title, limits.title-lines |
| 241 | `HStack(spacing: theme.space.swatchGap) { ForEach(Array(colors.enumerated()), id: \.offset) { _, c in Swatch(sample: c, theme: theme) } }` | space.swatch-gap |
| 244 | `Text(d.summary).themed(.description, theme).lineLimit(theme.limits.descriptionLines).fixedSize(horizontal: false, vertical: true)` | text.description, limits.description-lines |
| 246 | `HStack(spacing: theme.space.inlineGap) {` | space.inline-gap |
| 250 | `if !d.repo.isEmpty { Text(d.repo).themed(.repo, theme) }` | text.repo |
| 252 | `Text(location).themed(.location, theme).lineLimit(theme.limits.locationLines).truncationMode(.middle)` | text.location, limits.location-lines, truncation: structural |
| 258 | `.padding(.top, theme.space.metaGap)` | space.meta-gap |
| 265 | `Text(text).themed(.badge, theme).foregroundStyle(Color(rgba: fg))` | text.badge |
| 266 | `.padding(.horizontal, theme.space.badgeX).padding(.vertical, theme.space.badgeY)` | space.badge-x, space.badge-y |
| 267 | `.background(Color(rgba: bg), in: theme.shape(theme.radius.badge))` | radius.badge |
| 323 | `.padding(.horizontal, theme.space.rowPadX).padding(.vertical, theme.space.rowPadY)` | space.row-pad-x, space.row-pad-y |
| 324 | `.background(hovered.wrappedValue ? Color(rgba: theme.colors.rowHover) : Color.clear, in: theme.shape(theme.radius.row))` | radius.row, color.row-hover |
| 325 | `.padding(.horizontal, -theme.space.rowPadX).padding(.vertical, -theme.space.rowPadY)` | space.row-pad-x, space.row-pad-y |
| 336 | `HStack(spacing: theme.space.swatchInnerGap) {` | space.swatch-inner-gap |
| 337 | `theme.shape(theme.radius.swatch)` | radius.swatch |
| 339 | `.frame(width: theme.swatchSize, height: theme.swatchSize)` | size.swatch |
| 340 | `.overlay(theme.shape(theme.radius.swatch).strokeBorder(Color(rgba: theme.colors.swatchBorder), lineWidth: theme.border.swatch))` | radius.swatch, border.swatch, color.swatch-border |
| 341 | `Text(sample.label.isEmpty ? sample.hex : "\(sample.label) \(sample.hex)").themed(.swatch, theme)` | text.swatch |
| 350 | `Text(text).themed(.notice, theme)` | text.notice |
| 351 | `.padding(.horizontal, theme.space.noticeX).padding(.vertical, theme.space.noticeY)` | space.notice-x, space.notice-y |
| 352 | `.frame(maxWidth: theme.width, alignment: .leading)` | size.width |
| 354 | `.themedSurface(theme, fill: theme.colors.noticeSurface, radius: theme.radius.notice, borderWidth: theme.border.notice, shadow: theme.noticeShadow)` | radius.notice, border.notice, color.notice-surface, shadow.notice, color.surface-blur, border.container/notice (stroke inside the shape), shadow layers |
