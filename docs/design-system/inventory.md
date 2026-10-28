# Tooltip inventory: every style line → token

Source: `Sources/LupitaApp/TooltipPanel.swift` (`TooltipView`, `Swatch`, `NoticeView`), version 0.9.0.
Checked by `node scripts/design-system/check-inventory.mjs`: each style line has exactly one row, and the quoted code must still be on that line.
Tokens are named in [tokens.json](tokens.json). `structural` = layout behaviour with no visual value to theme.
Values marked *system* come from macOS (materials, semantic colours, text styles) and are modelled with an approximation, see [README](README.md).

## Text roles (what each piece of text is)

| Role | Used for | Today (SwiftUI) |
|---|---|---|
| `text.title` | what the thing is / means | `.body.weight(.medium)` |
| `text.id` | the cited name: ID, symbol, file | `.callout` monospaced semibold, secondary |
| `text.description` | the explanation | `.callout`, secondary |
| `text.repo` | where it comes from | `.caption` semibold, accent |
| `text.location` | `path:line` | `.caption` monospaced, secondary |
| `text.badge` | kind («término», «rama») and «de otro repo» | `.caption2` semibold |
| `text.eyebrow` | «¿Querías decir…?», «Lectura dudosa», header of a range | `.caption`, secondary |
| `text.footnote` | «+2 más», «citado 12 veces» | `.caption`, secondary |
| `text.placeholder` | «sin definición», «sin comentario» | `.body` italic, secondary |
| `text.swatch` | colour label | `.caption` monospaced, secondary |
| `text.notice` | the small notices | `.callout`, secondary |

## Rows

| Line | Code | Token(s) |
|---|---|---|
| 140 | `VStack(alignment: .leading, spacing: 8)` | space.range-gap |
| 141 | `.font(.caption).foregroundStyle(.secondary)` | text.eyebrow |
| 142 | `VStack(alignment: .leading, spacing: 5)` | space.range-line-gap |
| 145 | `.font(.callout).foregroundStyle(.secondary)` | text.description (today «+N más» of a range is a callout, not a footnote: kept for parity, see pending decisions) |
| 151 | `HStack(spacing: 6)` | space.inline-gap |
| 152 | `.font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)` | text.repo |
| 153 | `.font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)` | text.location, lines.location, truncation: structural |
| 157 | `.padding(14)` | space.padding |
| 158 | `.frame(width: 440, alignment: .leading)` | size.width |
| 159 | `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))` | color.surface, color.surface-blur, radius.container |
| 160 | `.overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))` | color.border, border.container, radius.container |
| 166 | `HStack(alignment: .firstTextBaseline, spacing: 8)` | space.entry-gap |
| 167 | `.font(.system(.callout, design: .monospaced).weight(.semibold)).foregroundStyle(.secondary)` | text.id |
| 168 | `.font(.body.weight(.medium)).lineLimit(1).truncationMode(.tail)` | text.title, lines.range-title |
| 176 | `HStack(alignment: .firstTextBaseline, spacing: 8)` | space.entry-gap |
| 177 | `.font(.system(.callout, design: .monospaced).weight(.semibold)).foregroundStyle(.secondary)` | text.id |
| 178 | `.font(.body.italic()).foregroundStyle(.secondary)` | text.placeholder |
| 184 | `VStack(alignment: .leading, spacing: 10)` | space.block-gap |
| 187 | `.font(.caption).foregroundStyle(.secondary)` | text.eyebrow |
| 190 | `.font(.caption).foregroundStyle(.secondary)` | text.eyebrow |
| 194 | `.opacity(resolution.isSuggestion ? 0.75 : 1)` | color.suggestion-opacity |
| 198 | `.font(.caption).foregroundStyle(.secondary)` | text.footnote |
| 202 | `.font(.caption).foregroundStyle(.secondary)` | text.footnote |
| 205 | `.padding(14)` | space.padding |
| 206 | `.frame(width: 440, alignment: .leading)` | size.width |
| 207 | `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))` | color.surface, color.surface-blur, radius.container |
| 208 | `.overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))` | color.border, border.container, radius.container |
| 223 | `VStack(alignment: .leading, spacing: 4)` | space.row-gap |
| 225 | `VStack(alignment: .leading, spacing: 2)` | space.name-gap |
| 228 | `.font(.system(.callout, design: .monospaced).weight(.semibold)).foregroundStyle(.secondary)` | text.id |
| 229 | `.lineLimit(2).truncationMode(.middle)` | lines.id, truncation: structural |
| 232 | `.font(.body.italic()).foregroundStyle(.secondary)` | text.placeholder |
| 234 | `.font(.body.weight(.medium)).lineLimit(4).fixedSize(horizontal: false, vertical: true)` | text.title, lines.title, fixedSize: structural |
| 238 | `HStack(spacing: 10)` | space.swatch-gap |
| 241 | `.font(.callout).foregroundStyle(.secondary).lineLimit(4).fixedSize(horizontal: false, vertical: true)` | text.description, lines.description, fixedSize: structural |
| 243 | `HStack(spacing: 6)` | space.inline-gap |
| 245 | `.font(.caption2.weight(.semibold))` | text.badge |
| 246 | `.padding(.horizontal, 5).padding(.vertical, 1)` | space.badge-x, space.badge-y |
| 247 | `.background(.secondary.opacity(0.15), in: Capsule())` | color.badge-bg, radius.badge |
| 249 | `.font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)` | text.repo |
| 251 | `.font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)` | text.location, lines.location, truncation: structural |
| 254 | `.font(.caption2.weight(.semibold))` | text.badge |
| 255 | `.padding(.horizontal, 5).padding(.vertical, 1)` | space.badge-x, space.badge-y |
| 256 | `.background(.orange.opacity(0.2), in: Capsule())` | color.origin-bg, radius.badge |
| 260 | `.frame(maxWidth: .infinity, alignment: .leading)` | structural |
| 310 | `HStack(spacing: 5)` | space.swatch-inner-gap |
| 311 | `RoundedRectangle(cornerRadius: 4)` | radius.swatch |
| 313 | `.frame(width: 20, height: 20)` | size.swatch |
| 314 | `.overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.25)))` | color.swatch-border, border.swatch, radius.swatch |
| 316 | `.font(.caption.monospaced()).foregroundStyle(.secondary)` | text.swatch |
| 338 | `.font(.callout).foregroundStyle(.secondary)` | text.notice |
| 339 | `.padding(.horizontal, 12).padding(.vertical, 8)` | space.notice-x, space.notice-y |
| 340 | `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))` | color.notice-surface, color.surface-blur, radius.notice |

## Not in a style line but part of the look

| What | Where | Token |
|---|---|---|
| Panel shadow | `panel.hasShadow = true` (TooltipPanel.present) | shadow.container, shadow.notice (*system*; the port draws its own, see README) |
| Title / description colour | no `foregroundStyle` → `.primary` | color.text-primary |
| Badge text colour | no `foregroundStyle` → `.primary` | color.badge-fg, color.origin-fg |
| Row hover | none today | color.row-hover (transparent in Lupita) |
