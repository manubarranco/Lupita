# Decisions

> Newest at the bottom. Format: `## D{N} — Title`, then a one-line summary,
> then details. Do not reopen without stating which input changed.

## D1 — Mac only, native Swift
Native app in Swift (SwiftUI + AppKit). No Tauri, no Electron.

## D2 — Tool-agnostic by reading the screen, not the apps
We cannot inject into Cursor or Copilot chats, so we work at OS level.

## D3 — Capture via global hotkey + local Apple Vision OCR
OCR a strip around the cursor, locally. No images to the cloud, no vision model.
Later improvement: selected text or the Accessibility API.

## D4 — Deterministic resolution by default
Haiku (Anthropic API) only when there is no clear definition or a long text needs
summarizing. Premium candidate, out of the MVP.

## D5 — Pre-built index of defined IDs, not blind grep
A background scan builds a dictionary of **defined** IDs. This gives us:
- agent-invented prefixes discovered, not hardcoded;
- OCR error correction against real IDs (`QL2S` → `QL25`, `0`/`O`);
- pointing at a non-ID → do nothing or "not a known reference".

## D6 — Distinguish definition from mention
Definition heuristics:
- headings `## Q07`, `### Q07 — Title`;
- line or list start: `Q07:`, `- **Q07**:`, first table column `| Q07 |`;
- file name: `Q07-*.md`, `decisions/D23.md`;
- frontmatter `id: Q07`.
Everything else is a mention ("cited in N files").

## D7 — Freshness: FSEvents watcher + live-search fallback
Reindex only changed files. On an index miss, run a live search (ripgrep) before
saying "not found".

## D8 — Which repo: registered roots + `.git` discovery + active-window priority
User registers 1-3 root folders (`~/code`, `~/dev`…); `.git` folders inside are
discovered. Repo priority comes from the active window (VS Code/Cursor title,
browser URL). An ID defined in several repos shows all, each with a repo label.

## D9 — Optional enhanced mode (post-MVP): ask for a format, never a sidecar
The app OFFERS to add a rule to the repo's AGENTS.md: "define every reference with
`## ID — Title` + one-line summary". Never a separate `refs.json`: two sources of
truth drift. Heuristics stay the foundation.

## D10 — macOS permissions are acceptable
Screen Recording and Accessibility are fine, explained clearly in the README.

## D11 — IDs keep their leading zeros
`L007` (a lesson) and `L7` (a job level) are different IDs; only the hyphen is normalized
(`ADR-004` ≡ `ADR004`). Data from the heuristics spike: padded IDs are never cited unpadded
(1316 to 0 for `D0nn`).

## D12 — Repo priority: text → file path → active window → others
A repo named within 80 characters before the ID wins; then a repo named in the file path
(`domains/harbor-log.md`); then the active window (D8); then the rest, flagged
"defined in another repo". Inside a repo, a definition in the reader's folder or a parent
wins. Weak sections (`## P1`, repeated `## D034 …` headings) from other repos are never shown.

## D13 — Short OCR-corrected IDs are suggestions, not answers
When the OCR text matched only after correction **and** the ID is shorter than 4 characters,
the tooltip says "Did you mean D5? (read: DS)" in a muted style. Exact matches and longer
corrections (`QL2S` → `QL25`) are shown normally. Data: every false correction in the spike
was a 2-character ID (`DS→D5`, `L7→L1`, `A7→A1`).

## D14 — Accessibility first, OCR as fallback (refines D3)
The text under the cursor comes from the Accessibility API when the app exposes it (exact,
instant, no screen capture). Vision OCR of a strip around the cursor runs only when it does
not. Why: macOS 15+ periodically re-asks for Screen Recording; with AX first, that
permission is optional. Approved with the step 3 plan, 2026-10-22.

## D15 — OCR is the main path for Electron and web apps (refines D14)
Electron apps (Claude Desktop, VS Code, Cursor, Obsidian) and browsers expose text markers
but answer "no value" for the text under the cursor (AX error -25212, 2026-10-22). Most
agent tools are Electron or web, so in practice OCR is the main path there; Accessibility
stays first and serves native apps. Consequence: Screen Recording is required, not optional.

## D16 — No ripgrep: rescan the repo in Swift on a miss (replaces the ripgrep part of D7)
The FSEvents watcher reindexes only the changed repo, batching changes for 1.5 s. When a
lookup finds an ID-shaped token that nothing defines, the window's repo is rescanned once
before saying "not known" (34-90 ms per repo measured; skipped when a repo costs > 300 ms).
Why: ripgrep is not on macOS and bundling it adds weight, licensing and signing; the
existing indexer gives the same answer. Approved with the step 4 plan, 2026-10-22.

## D17 — The lens is a character: pill eyes, no mouth, bigger
The cursor lens becomes Lupita's character: a magnifier with two pill eyes that follow the
pointer, rest facing forward, narrow when the string is taut and blink. No mouth: at lens
size it turns to a smudge, and the eyes alone keep it apart from Copilot's face. It grows to
about 42 pt so the eyes read. Spec and prototype in docs/lens-behavior.md. Approved by Manu,
2026-10-24; reactions to the lookup result are not approved yet.

## D18 — The lens stays until the tooltip closes
After the shortcut fires the lens searches with narrowed eyes, reacts on top of the tooltip
(found: hop and blink; not found: looks around), moves to the tooltip's side, reads it, and
leaves when it closes. The tooltip shows at once: the reaction never delays the answer.
The "not known" notice closes 2 s after the lens reaches its side (3.5 s without the lens).
Sequence in docs/lens-behavior.md. Approved by Manu, 2026-10-24.
