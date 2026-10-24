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
summarizing. Premium candidate, out of the MVP. (The Haiku part is replaced by D26.)

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

## D19 — Commits, branches, files and commands are looked up on demand, not indexed
Besides defined IDs, the tooltip resolves what agents cite from git and disk: a repo name, a commit SHA, a
branch, a file path (`docs/a.md:12`) and a Claude Code command or skill (`/retro`). They are
looked up when the user points, never indexed, so there is nothing to keep fresh and the
`.claude` folders stay out of the index. Why: in 80 real agent sessions these were ~570
citations against ~250 ID citations; 68 % now resolve (the rest are deleted branches with no
trace, localhost URLs and built-in commands). Approved by Manu, 2026-10-24.

## D20 — Git only when the Command Line Tools are installed
Commits and branches are read by running `git` (Homebrew's, or the Command Line Tools'). Without
it `/usr/bin/git` is a stub that opens an install dialog, so it is never called and commits and
branches are simply not recognised. Reading `.git` by hand (packfiles, zlib) is not worth it:
people who use coding agents have git. Approved by Manu, 2026-10-24.

## D21 — The rule is offered as a minimal English prompt for the user's own agent; Lupita never writes in their repos (refines D9)
Lupita does not edit a repo's `AGENTS.md`. The "Prepare your repos" window lists only the repos that have an `AGENTS.md` or
`CLAUDE.md` in the root (Cursor, Windsurf and Copilot rules are not listed; the `<!-- lupita -->` marker is still looked up in
those two files), shows the prompt once, and per repo a "Copy and open" button that copies it and opens the folder in the user's
editor (Cursor, VS Code, Windsurf, Zed or Finder). The prompt is always in English (agents read it), three sentences plus the
marked block, and safe by design: if the agent fails it does nothing, it does not ask for a commit, and it has no judgement steps
("if the block is already there, do nothing"; "where this repo already has a format, keep it"). There is no conversion prompt:
it touched several files and asked the agent for criterion. The header is honest: Lupita works without the rule (it already
explains the share of citations that something defines, shown as a percentage over the listed repos); the rule acts forward, on
what agents create from now on and on their internal vocabulary. Why: trust (a lookup tool that writes in your repos is a
different product) and the agent knows the repo. The app only checks the marker, every 3 s while the window is visible.
"Unexplained citations" counts mentions of keys nothing defines in any repo (weak sections, `P0`-`P9` labels and ranges
excluded). Approved by Manu, 2026-10-24.

The block also asks agents to write the IDs and glossary terms they mention to the user as
inline code (`D23`, `golden path`): the style does not help OCR, but it shows the reader what can be
looked up, and it is the style paths, commits and commands already have. Approved by Manu, 2026-10-24.

## D22 — Glossary terms: which files, which formats
Terms come from glossary files: any `.md` whose name contains `glossary`, `glosario`, `nomenclatura` or `terminolog`.
Four formats: `- **term** — definition`, `**term**: definition`, `| **term** | definition |` and `### term` (a heading
counts only when the file has no list or table entries, otherwise headings are its sections). Aliases are separated by
` / `; `(…)`, `*(canónico)*`, backticks and `[?]` are dropped from the name. A term ranks below every ID definition, and
the order is ID, then repo reference, then term. The generic pattern (`- **term** — definition` in any `.md`) stays
**off**: in a fixed sample of 40 hits outside glossaries (seed 42) only 23 (58 %) were real term definitions against the
95 % bar; the rest were rules, principles, log entries and sentences that happen to start with bold text. A glossary file
is the signal; the line shape alone is not. Switch: `Glossary.looseTerms`; `lupita terms <dir>` prints the sample.

## D23 — Multi-word terms and normalization
The lookup key is the same when indexing and when pointing: lowercase, no accents, no backticks, no leading article
(`el/la/los/las/the`), and a simple plural removed from the last word (`remates` → `remate`; a plural in `-es` is
tried second, `ciudades` → `ciudad`). Words that end in `s` after `s`, `u`, `i` or `y` keep it (`census`, `glass`). When the
pointed word is not an ID or a repo reference, windows of 4 to 1 words that contain it are tried, longest first, over the
Accessibility line and over the OCR row; a word ending in punctuation closes the phrase. The CLI takes the phrase whole:
`lupita "golden path" --repo harbor`. A term in the window's repo comes first; one from another repo is flagged. Why: the
terms agents coin are often two or three words (`Mesa de Trazo`), and pointing at any one of them should find it.

## D24 — The first run asks for the repo folders
Lupita no longer assumes `~/Repos`. With no saved folders nothing is indexed, and the first window offers the usual candidates
that exist on that Mac (`~/Repos`, `~/repos`, `~/code`, `~/Code`, `~/dev`, `~/Developer`, `~/Projects`, `~/projects`, `~/GitHub`,
`~/Documents/GitHub`, `~/src`) with how many git repos each holds (two levels deep, to be fast), plus "Add another folder…".
An install from before this, where "onboardingShown" is already set and no folders were saved, keeps `~/Repos`. Order at launch:
permissions, then this window. Approved by Manu, 2026-10-24.

## D25 — Updates are checked only when the user asks
"Check for updates…" in the menu makes one GET to GitHub's latest-release endpoint and compares `tag_name` with the installed
version (numeric semver). Never in the background, so "nothing leaves your Mac" stays true except when the user asks. When a newer
release is found the item becomes "Download Lupita X.Y.Z…" until restart. Automatic installation with Sparkle is postponed until the
app is notarized. Approved by Manu, 2026-10-24.

## D26 — Local only, now and in future versions; any language model runs on the Mac
Replaces the Haiku part of D4. Nothing the user looks up leaves the Mac. If Lupita uses a language model, it is Apple's on-device
model (Foundation Models), working only on what Lupita already found: the literal source stays visible and generated text is
marked as such. A feature that needs the network ships switched off, clearly labelled, and works only after the user turns it on;
the update check (D25) is the only network call today. The promise is in both READMEs. Why: users must be able to trust that their
text never goes to a cloud service, and the on-device model covers the uses we foresee without one. Approved by Manu, 2026-10-24.

## D27 — The tooltip can be looked up: pointing at it reads it by OCR
With the cursor over the tooltip, the shortcut skips Accessibility, lets the OCR capture include the tooltip window (the lens stays excluded) and prefers the repo and file of the definition shown, so `answered by D006` in a `Q01` tooltip resolves in the same repo. Why: the tooltip's text is not reachable through Accessibility and OCR used to exclude every own window. Validated on a real screen by Manu, 2026-10-24.

## D28 — The menu has switches: lens, folders and each repo inside them
The menu header is a view (name, stats), not disabled rows, so it keeps the full text colour. "Show Lupita" (was "Lens while holding") is a switch. Each folder has a switch (search in it or not), a trash button instead of "Remove", and a chevron that opens its repos, each with its own switch. Off means left out of the index but kept in the list, so it can be turned back on; a folder that is off locks its repos' switches without losing their state. The switches are drawn by hand because `NSSwitch` paints grey in a menu. The ⌃⌥R shortcut is gone: only ⌃⌥⌘ and fn⌃⌥ remain, and a saved ⌃⌥R falls back to ⌃⌥⌘ (a custom shortcut comes later). Pending Manu's check on screen.
