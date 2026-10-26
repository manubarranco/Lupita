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

Removed 2026-10-25 by Manu: holding the shortcut now underlines what can be looked up (D39), so the
inline-code line no longer earns its place, and on screen the code box made lookups less reliable
(D42 addendum 2). The block keeps its three sentences; repos that already carry the old line keep working.

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
The menu header is a view (name, stats), not disabled rows, so it keeps the full text colour. "Show Lupita" (was "Lens while holding") is a switch. Each folder has a switch (search in it or not), a trash button instead of "Remove", and a chevron that opens its repos, each with its own switch. Off means left out of the index but kept in the list, so it can be turned back on; a folder that is off locks its repos' switches without losing their state. The switches are drawn by hand because `NSSwitch` paints grey in a menu. The ⌃⌥R shortcut is gone: only ⌃⌥⌘ and fn⌃⌥ remain, and a saved ⌃⌥R falls back to ⌃⌥⌘ (a custom shortcut comes later). Validated on a real screen by Manu, 2026-10-24.

## D29 — Code layer: symbols, local addresses, CSS tokens, commands, errors and PRs, in that order
The tooltip also explains what agents cite from code, looked up on demand like D19 and never with a language model: a
symbol (function, variable, constant) shows its own comment and where it is defined, or only where it is defined and says
it has no comment; a local address (`localhost:8130`) shows which repo serves it, which page, and whether it is running; a
CSS token or hex colour shows its value, a swatch and where it is defined; a terminal command shows what it does (an
`npm run` script from the repo's `package.json`, common git and shell commands from a fixed dictionary); an error code or
HTML tag gets one line from a fixed dictionary; a PR number (`#123`) shows the title and date of the merge that closed it,
read from the local git history. Open PRs need the network and stay out until a switch per D26 is decided. Packages and
components are left out: almost never cited. Why: in 150 real agent sessions symbols were ~900 citations (45 % defined in
the user's repos, 30 % with a comment), local addresses 94, CSS tokens and colours ~120, commands ~90, errors and HTML
~80, packages, components and PRs ~5 together; PRs are kept because Manu sees them constantly at work. Approved by Manu,
2026-10-24.

## D30 — Code is looked up on demand with no index; the budget is measured
Symbols, tokens, addresses, commands and PRs are searched when the user points (like D19), not indexed: a byte search (`memmem`) skips the files that do not contain the name and only those that do are read as lines. Measured on ~/Repos (7 repos, ~1 800 source files, 150 MB): 15-100 ms when the name is defined in the window's repo, 150-300 ms for a name defined nowhere (cold, the whole disk walked once); file lists and CSS token tables are kept 20 s in memory and never saved. Two fixes were needed to stay under 300 ms: no `git` process to list worktrees (read `.git/worktrees/*/gitdir`, a process cost 90 ms each) and no OCR look-alike search for words over 16 characters (`FontBuilder` cost 0.5 s and found nothing). Revisit with an index beside the .md one if a user's repos are 5× bigger.

## D31 — A word is code only if it looks like code
Symbols: `_` inside, camelCase or PascalCase with two humps, `()` after it or backticks around it; a plain lowercase word (`slider`) is noise otherwise, and a plain capitalised or ALL-CAPS word without `_` too. Names under 4 characters are never looked up. A name that is also a glossary term is a term unless the text has that shape (D22 stays first for plain words); order: ID, repo reference (D19), code, glossary term. Commands whose name is an ordinary English word (`open`, `make`, `find`, `cat`, `node`, `swift`) only count between backticks; `git`, `npm`, `cd`, `rm`… count anywhere. A bare number is an HTTP status only with a hint (`HTTP 401`, `401 Unauthorized`, backticks, or a word like status/error/response just before it). HTML tags need their angle brackets. Why: pointing at ordinary prose must keep doing nothing.

## D32 — Fixed dictionaries live in Swift source, in both languages
The ~60 commands, ~40 errors, 18 HTTP statuses and ~48 HTML tags are tables in `CodeDictionaries.swift`, English and Spanish like `Strings.swift`, not a SwiftPM resource bundle. Why: a resource bundle must be copied next to the executable by `bundle.sh`, the CLI and the tests, and a missing bundle crashes at launch; a table in code cannot go missing. A row with no file (a dictionary answer) is not clickable.

## D33 — A local address says who serves it from the process, then the launch file; it never makes a request
`lsof` tells which process listens on the port and its folder; that folder (or a path in the launch command, or else the repo holding the `.claude/launch.json` that declares the port) names the repo or linked worktree (`nib · qa-baseline`), the route of the URL is the page (found in the repo when it exists), and on/off is whether anything listens. A port nobody declares and nothing listens on answers "No repo declares this address · not running": 28 of the 95 corpus citations, all of them dead dev ports. Why: the corpus has several ports served from worktrees by a launch file in another repo; a click does nothing network-wise.

## D34 — CSS tokens show both themes and follow var() chains
`--name:` is read from .css, .scss, .astro, .tsx, .jsx and .html (comments and strings skipped, braces tracked). A declaration inside `prefers-color-scheme: dark`, `[data-theme=dark]` or `.dark` is the dark value; a token that only points (`--accent: var(--brand)`) shows dark when what it points to has one. Colours: hex, rgb(), hsl() and shadcn bare `H S% L%` get a swatch; the tooltip paints it with its hex. A hex colour lists the tokens that hold it, or says no token does. Why: tokens are the most cited design vocabulary and are always written twice.

## D35 — PRs are read only from the window's repo; only the grays `#000`-`#999` fall back to a colour
`#123`, `PR 123`, `PR #123` search `git log --all` for `Merge pull request #123 …` (title from the body, or the branch if empty) or a squash `Title (#123)` at the end of a subject, in the window's repo only (without a window: all repos, in parallel). No match says "Not in the local history". With no such PR, only the grays `#000`…`#999` (one repeated digit) are colours (`#333` is #333333; `#fff` and other hex with letters are always colours); any other number such as `#123` says "Not in the local history". A word `PR` right before the number wins over the colour. Changed by Manu's request, 2026-10-25. Open PRs need the network (D26) and are not read. Why: another repo's #123 is another PR.

## D36 — The tooltip gallery is a development aid and its sheet stays out of git
`LupitaApp --render-tooltips <dir> [repo::]text…` draws the real tooltip in light and dark; `scripts/contact-sheet.swift` lays the frames out. The sheet shows paths of private repos, so it lives in `reports/` (ignored), not in the repo.

## D37 — Frozen copies of a file are shown only when nothing else defines the symbol
Files named `reference_*`, `*_pre_*`, `*_old`, `*_bak`, `*backup*`, `*copy*` or `*.orig` look like snapshots: their definitions of a symbol are dropped when a live file defines it, so one answer is shown, not three versions. If only snapshots define it, they are shown. Decided by Manu, 2026-10-25, with two more: the command dictionary stays at ~60 entries (D32) and code lookups stay on the main thread (D30) until someone's repos make them slow.

## D38 — The "not known" notice closes 1 s after the lens arrives (refines D18)
Was 2 s. Input that changed: Manu tried it and found the wait long for a five-word notice; the lens reaction already says "not found". Without the lens the notice closes after 2 s (was 3.5 s). Confirmed by Manu after trying it, 2026-10-25.

## D39 — Holding ⌃⌥⌘ underlines what Lupita knows; releasing hides it and looks up as always
Held for 0.25 s, the shortcut stops being a quick press: Lupita reads the whole window under the pointer with Vision `.accurate` (about 0.1 s measured, `docs/spike-highlight-results.md`) and underlines, in a thin line of ink, only what is cheap to check: indexed IDs, glossary terms and the fixed dictionaries (git/shell commands, error names). Symbols, commits, branches, files and PRs are not marked: each costs a search in the repos per word. The lines fill in left to right, word by word, which hides the reading time. Releasing, after a hold or a quick press, hides the marks and looks up the word under the pointer; after a hold the lookup reuses the words the OCR already read for the marks (changed 2026-10-25: Manu found that releasing after a hold did not look up). Scrolling or switching app removes the marks and they stay off until the next hold; another key cancels as it always did. Colour, thickness and timing live in `HighlightStyle` so a later theme changes one place; the ink is light on dark backgrounds and dark on light ones, measured behind each word, and there is one panel per screen (changed 2026-10-26: with an external display the marks showed on the wrong screen or were cut; the read now starts when the keys go down and the hold is 0.25 s, down from 0.35 s, so the marks come sooner). Other looks (marker, gaze, proximity) are in `docs/highlight-prototype.html`, kept for when there are themes. Why: seeing what Lupita can explain before pointing removes the guessing. Chosen by Manu from the prototype, 2026-10-25.

## D40 — The ID report holds shapes, prefixes and file names; the user sends it, Lupita never does
A hidden menu item (shown only while ⌥ is held) builds a report of how the user's repos write IDs, so early users can show Manu formats Lupita misses. Each row: the ID's shape (`E2-S3` → `A9-A9`, `1.2` → `9.9`), its literal prefix (`D`, `ADR`, `QL`), where it is written (heading, table, list, file name, frontmatter), the file name where it is defined or mentioned (name only: no folders and no repo names, which become «repo 1», «repo 2»), counts, and whether Lupita resolves it. It also lists ID-like tokens Lupita does not recognise (`§5`, `1.2`), with the same fields, when they appear at least 3 times. It never holds titles, definitions, lines of text or paths. Before saving, the user sees every row and can remove any of them. Sending: Lupita opens a new email to mbarranco+lupita@gmail.com (a Gmail alias Manu filters) in the user's mail app with the file attached (`NSSharingService` compose email; a `mailto:` link cannot attach files); if the mail app cannot do that, it opens a `mailto:` with the subject filled in and shows the file in Finder to drag into the email. Lupita makes no network call, so D26 holds; the READMEs say the report exists and what it contains. Why: shapes, prefixes and file names say what each kind of ID is (`Q` in `questions.md`) without saying what any ID says. Approved by Manu, 2026-10-25.

## D41 — A range of IDs shows the list of what it spans
`D022-D026` (hyphen or en dash) is a range when both ends resolve as defined IDs with the same prefix; then the tooltip says «Range · 5 decisions» and lists one line per ID, its ID and title, each line clickable to open it, with the repo and file shown once at the bottom when they all share them. An ID missing in the middle keeps its line, marked «not defined». From 7 IDs on, it shows the first 3, «… N more» and the last 2. If either end is not a defined ID (`L0-L3` where there are no lessons `L0` or `L3`), it is not a range and the lookup works as before. Why: a range is cited as a group, so what the reader needs is which items it holds, at a glance; the first ID report found 74 such mentions in Manu's repos. Chosen by Manu from three mockups (list, ends only, first in full), 2026-10-25.

## D42 — Git vocabulary: 40 terms explained in plain language, behind a «Git» switch
The first «vocabulary between trades» package. A closed list of 40 git terms, in Spanish and English (`GitVocabulary.swift`, a table in code per D32, no LLM per D26), explains what colleagues and agents say in prose: one plain line, plus «Ejemplo: …» (the examples are not real quotes). It recognises the bare word, variants and conjugated Anglicised verbs (pushear/pusheado, mergea, rebasear, stasheo, commiteo, cherry-pickear) and phrases (fast-forward merge, rebase interactivo, squash and merge). Words that are also ordinary English or Spanish (push, pull, branch, origin, head, main, master, tag, log, review, stage, reset, fork, clone, fetch, diff, commit, merge, rama, remoto, historial, repo, and also revert, conflicto, discard, ahead/behind, remote, clonar) count only if the same block of text (the line; for OCR, the rows just above and below) holds another word of the package, or they are in backticks; unambiguous ones (rebase, stash, cherry-pick, fast-forward, detached HEAD, upstream, force push, amend, squash, untracked, .gitignore, worktree, the verbs, `HEAD`, `PR`, `CI` in capitals, also as the OCR misreads it in italics, `C/` and `Cl`) count alone. Order: ID > repo reference > code (existing `git x` commands included) > repo glossary (D22) > this package. A «Explain terms of: Git» switch in the menu (on by default, pattern of D28) turns it off, and the ⌃⌥⌘ highlight (D39) underlines these terms too. Why: designers hear «hay que rebasear» and do not understand it; the package works from the first minute without depending on the user's glossaries. Terms chosen and tone validated by Manu, 2026-10-25.

D42 addendum, 2026-10-25 (inline code): in chat apps and markdown previews `main` or `origin` appear in a grey box with no backticks, so a lone one had no git context. Three more things now count as context for a word that is also ordinary English or Spanish. (1) A code box: from the screenshot, if the commonest brightness behind the word differs from what lies above and below the line (`CodeBox`, checked on rendered text, light and dark, at 1×, 2× and 4×), the word counts as if it carried backticks. (2) A monospaced font: where Accessibility reports the font of the text (`AXAttributedStringForTextMarkerRange`), a monospaced run counts the same; this is covered by unit tests but not yet checked against the real apps. (3) A file or branch written in the same block (`src/app.js`, `feature/login`, `README.md`: a `/` joining names with a prefix such as `feature`, `fix`, `src`, `origin`, a `-`, `_`, `.` or digit, three or more parts, or a known file extension): the text is about code. A URL, `and/or`, `input/output`, a date (`10/12`) or an e-mail does not count. Why: Manu found lone `main` in inline code neither underlined nor found on release. The package's own words are not affected: only ambiguous words gain context.

D42 addendum 2, 2026-10-25 (the path matters): measured on the real Claude window with `LupitaApp --diagnose-window` (it captures one window, writes only the watched words and numbers, and asks Accessibility the same question the shortcut asks): the OCR path sees the code box (30 of 435 words flagged, `main` and `origin` in inline code among them, brightness step 0.05 against a 0.02 threshold), but Accessibility mostly answers nothing there, and once answered the estimated offset of a static text (`staticText`) pointed at another word. So on release, when Accessibility answered but nothing was explained (the word is «not a reference», not an undefined ID), Lupita now asks OCR too before saying «not known», and shows the OCR answer if it explains something. Cost: one OCR read (about 0.1 s) before the «not known» notice, only on misses. The box threshold went from 0.035 to 0.02. With `defaults write com.manubarranco.lupita debugLog -bool true` every lookup adds a line to `~/Library/Logs/Lupita/vocabulary.log` (path, word, the line read, why it was or was not git, the fonts Accessibility reported, the box result); it holds the text pointed at, so it stays on the Mac and is deleted afterwards.

## D43 — Three switches turn off fixed dictionaries; what comes from the repos is always on
Under «Explain terms of:» the menu has three switches, on by default and drawn like the lens (D28): **Git** (the git vocabulary in prose, D42, and the `git …` commands of the command dictionary with their flags such as `--rebase`), **Terminal** (the shell commands of the dictionary, `rm`, `chmod`, `cd`, and the common package-manager subcommands, `npm install`) and **Development** (the whole error table, system, JavaScript and Python, the HTTP statuses and the HTML tags). Switching one off stops it resolving and, in the ⌃⌥⌘ highlight, underlining; the other two are untouched (`git stash` still works with Terminal off). Principle: a switch only turns off a fixed dictionary, general knowledge of a trade that the user may already have. Everything that comes from the user's repos (IDs, glossaries, commits, branches, files, PRs, symbols, CSS tokens, local addresses and the `package.json` scripts behind `npm run x`) has no switch and is always on, so `npm run build` still resolves with all three off. `LupitaCore` holds the state (`TermPackages`, with a task-local override so tests do not disturb each other); the app saves it in `vocabulary.git`, `vocabulary.terminal` and `vocabulary.development`. Why: someone who already reads a terminal does not want its basics explained, and each trade can be silenced on its own. Asked by Manu, 2026-10-25.

## D44 — The menu follows what you do: permissions only when missing, folders as a tree
Order: missing permissions first (orange, hidden once granted), then the shortcut and «Show Lupita», then «Folders to search» with the index stats and «Updated» under its title, then «Explain terms of:», then About, Help, updates and Quit. A subfolder that holds repos is its own row with a switch and opens like the folder (`Archivados` inside `Repos`); a folder or subfolder with a single repo shows that repo's row and does not open (`~/Work › site`). A folder's switch is mixed when some of its repos are on and some off; clicking mixed turns them all on; turning an off folder back on restores its repos as they were (all on if none were). Remove is ⊖ and add is ⊕: the trash read as deleting files. A folder that is no longer there shows a warning in place of the switch; clicking it opens a panel next to where it was, and the folder found takes its place with its switches. Why: Manu's notes from a day of use at work, 2026-10-26.

## D45 — Hide a repo from a folder's list; ⌥ shows what is hidden, live
With ⌥ held a ⊖ appears on each repo row; clicking it hides the repo: out of the list and out of the index, its switch kept. Hidden repos wait under «Hidden (N)» at the end of their folder, closed by default, each with a ⊕ to bring it back. ⌥ works with the menu already open (a timer in the tracking run loop watches the modifier), and the hidden «Send ID report…» (D40) follows the same rule. No confirmation: hiding is undone in one click from «Hidden». Why: Manu wanted to declutter long folders without a recovery path that resets everything (remove and re-add the folder), 2026-10-26.

## D46 — IDs underlined solid, terms dashed
While ⌃⌥⌘ is held, an ID defined in the repos (or a range of them) gets the solid line it had; a term (glossary, git vocabulary, commands, error names) gets a dashed one, 3 pt dashes with round ends. Same ink, thickness and per-word colour as before (D39). Why: Manu wanted to tell at a glance what is a reference to a document and what is a word Lupita explains, 2026-10-26. Contact sheet: `LupitaApp --render-underline <dir>`.
