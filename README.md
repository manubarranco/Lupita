<img src="docs/brand/lupita.svg" width="80" alt="Lupita: a magnifying glass with two pill eyes">

# Lupita

**Your agent says `D23`, `L04`, `E2-S4`. Lupita tells you what they mean.**

Point at any reference, in any app, press a shortcut, and read its definition from your repos.

Coding agents (Claude Code, Cursor, Devin, Copilot…) keep their memory in Markdown files
and cite it by ID: *"as decided in D23, and pending Q07, I applied L34"*. The agent knows
what those are. You don't remember. Lupita is a macOS menu bar app that shows the definition
of the reference under your pointer, in any app: an agent chat, an editor, a terminal, a
browser.

![Lupita demo: pointing at D003 in an agent chat shows its definition](docs/demo.gif)

**[⬇ Download Lupita for macOS](https://github.com/manubarranco/lupita/releases/latest/download/Lupita.zip)** (Apple Silicon, macOS 14 or later)

[Leer en español](README.es.md)

## How it works

1. **It indexes your repos.** You register one or more folders (`~/Repos` by default). Lupita
   finds the git repos inside and reads their `.md` files, looking for IDs that are
   **defined** somewhere, not just mentioned. Prefixes are discovered, not configured:
   `D`, `Q`, `ADR`, `QL`, `E2-S3b` or whatever your agents invented.
2. **You point and press ⌃⌥⌘** (the three keys together, then release). Lupita reads the
   word under the pointer: through macOS Accessibility when the app exposes its text, or
   with on-device OCR of a small strip around the pointer when it doesn't (VS Code, Cursor,
   Claude, browsers).
3. **A tooltip shows** the ID, its title, two or three lines of its definition, the repo and
   file, and how many times it is cited. Click to open the file at that line; Esc closes it.

The index stays fresh on its own: a file watcher reindexes the repo that changed, and an
ID that was written seconds ago is found anyway.

### What counts as a definition

| Format | Example |
|---|---|
| Heading | `## D23 — Use SQLite` · `### Q07: How many repos?` |
| List or line start | `- **L34**: never parse HTML with regex` · `Q07: …` |
| First table column | `\| E2-S3 \| Voice input \| … \|` · `\| **E8-S6 Gift coins [Could]** \|` |
| File name | `docs/adr/ADR-004-storage.md` · `decisions/D23.md` |
| Frontmatter | `id: ADR-004` |

Everything else is a mention. Sections *about* an ID (`## D34 part 2`) and priority labels
(`## P1`) are recognised and kept out of the way.

### Beyond IDs: commits, branches, files and commands

Agents also cite things that live in git and on disk. Lupita looks them up at the moment you
point, so they are never stale:

| You point at | The tooltip shows |
|---|---|
| A repo name (`atlas`) | Its README title and first line, current branch, last commit and uncommitted changes |
| A commit (`e455cf7`) | Its message, date, and whether it is in `main`. Click: the commit on GitHub |
| A branch (`fix/search`) | Its last commit and how far ahead of `main` it is, or, if deleted, the merge that closed it |
| A file (`docs/decisions.md:12`) | Its title and first line (Markdown) or its last change. Click: opens it at the line |
| A command (`/retro`) | Its description, from `.claude/commands` or `.claude/skills`, in the repo or in `~/.claude` |
| A glossary term (`settlement`, `the ledger`) | Its definition, from a glossary file (`glossary.md`, `glosario.md`…) in the repo. Click: opens it at the line. Terms of one to four words work; a term from another repo is flagged |

Commits and branches need git (the Command Line Tools); without it they are simply not recognised.

### Which repo, when IDs collide

`D001` usually exists in every repo. Lupita picks the right one by, in order: a repo named
right before the ID, a repo named in the file you are reading, the repo of the active
window, the nearest folder. When the definition comes from another repo, the tooltip says so.

## Make your agents easy to look up

Lupita works without any rule: today it already explains most of what your agents cite. The
rule makes it reach further: what your agents create from now on, and their internal
vocabulary. Lupita never writes in your repos: it gives you a prompt for your own agent. It is
safe by design: if the agent fails, it does nothing; it does not ask for a commit; it asks for
no judgement calls. Paste this to your agent (the prompt is always in English; agents read it):

```text
Add this block at the end of this repo's agent instructions file (`AGENTS.md`, or `CLAUDE.md` if there is no `AGENTS.md`). Change nothing else. If the block is already there, do nothing.

<!-- lupita -->
Define each new decision, question, lesson or story once as `## ID — Title` plus a
one-line summary. Add each new internal term to the glossary (`docs/glossary.md` if
there is none) as `- **term** — definition`. Where this repo already has a format
for these, keep it.
<!-- /lupita -->
```

The **Prepare your repos…** window (menu bar, and on first launch) lists the repos that have an
`AGENTS.md` or `CLAUDE.md`, how many citations nothing explains yet, and whether the rule is in
place. **Copy and open** copies the prompt and opens the repo in your editor (Cursor, VS Code,
Windsurf, Zed or Finder), ready to paste.

See [`examples/demo-project`](examples/demo-project) for a small project that uses every
format.

## Install

Requires macOS 14 or later. The release build is for Apple Silicon; on an Intel Mac, build from source.

**From a release.** Download `Lupita.zip` from [Releases](../../releases), unzip it and move
`Lupita.app` to Applications. The app is not notarized yet, so the first time macOS blocks it: open
**System Settings → Privacy & Security**, scroll down and click **Open Anyway**.

**From source.** With Xcode or just the Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/manubarranco/lupita.git
cd lupita
./scripts/bundle.sh
open build/Lupita.app
```

## Permissions and privacy

Lupita asks for two macOS permissions, and uses them only when you press the shortcut:

- **Accessibility**: for the shortcut and to read the exact text under the pointer.
- **Screen Recording**: to read a 600 × 80 pt strip around the pointer with Apple's Vision
  OCR, in apps that don't expose their text.

Everything happens on your Mac. Nothing is sent anywhere, and nothing you look up is
stored. The one exception is **Check for updates…** in the menu: it asks GitHub for the latest
release, and only when you click it. Lupita never checks in the background. Lupita only keeps its settings and the index of your Markdown files, in memory.

If you build from source, macOS forgets the permissions on every build unless the app is
signed with a stable certificate: create a self-signed **Code Signing** certificate named
`Lupita Dev` in Keychain Access, and `scripts/bundle.sh` will use it.

## Known limits

- In Electron apps and browsers the text comes from OCR (150-300 ms). Native apps answer
  through Accessibility (10-40 ms).
- Very short IDs read by OCR (`D5` from "DS") are shown as a suggestion, "Did you mean D5?",
  never as the answer.
- An ID cited from another repo without naming it resolves to the local one.
- Only Markdown files are indexed for IDs. Files, commits and branches are looked up on demand.
- A deleted branch is found only if a commit message names it (a merge usually does).

## Similar tools

- **macOS Look Up** (⌃⌘D) and [Lookupper](https://apps.apple.com/app/lookupper/id1667225994):
  the same gesture, for dictionary words.
- **[GitHub autolinks](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/configuring-autolinks-to-reference-external-resources)**
  and **JetBrains issue navigation**: turn fixed prefixes into links, inside their own tool.
- **[VS Code ADR Manager](https://github.com/adr/vscode-adr-manager)**, **[Backlog.md](https://github.com/MrLesk/Backlog.md)**:
  keep decisions and tasks in Markdown for agents.

Lupita is for the moment in between: you are reading an agent's output, anywhere, and need to
know what it is citing.

## Development

```bash
./scripts/test.sh                 # tests (works without Xcode)
swift run lupita index ~/Repos      # index and print stats
swift run lupita D23 --repo myrepo  # resolve an ID from the terminal
swift run lupita report ~/Repos     # accuracy report (HTML, stays local)
```

Design decisions: [`docs/decisions.md`](docs/decisions.md), written in the same format Lupita reads.
Debug logging (what was looked up, by which method): `defaults write com.manubarranco.lupita debugLog -bool true`.

## License

[MIT](LICENSE)
