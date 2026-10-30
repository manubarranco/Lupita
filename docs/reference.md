# Lupita: reference

The detail that does not fit in the [README](../README.md): permissions, everything Lupita recognises, its limits and how to build it.

## Updating from 0.8.0 or earlier

Replace the app by hand once. Then, in **Privacy & Security**,
remove the old Lupita from **Accessibility** and **Screen Recording** (the **−** button) and grant
them again. It is the last time.

## Privacy and permissions

Everything happens on your Mac. Nothing is sent anywhere, and nothing you look up is stored.
Lupita keeps only its settings and the index of your Markdown files, in memory.

It asks for two macOS permissions, and uses them only when you press the shortcut:

- **Accessibility**: for the shortcut and to read the exact text under the pointer (10-40 ms in native apps).
- **Screen Recording**: for apps that don't expose their text (VS Code, Cursor, Claude, browsers).
  Lupita reads a 600 × 80 pt strip around the pointer with Apple's on-device Vision OCR. While you
  hold the shortcut, it reads the window under the pointer, to underline what it can explain.

The one network call is **Check for updates…**: it asks GitHub for the latest release, and only
when you click it. **Install and restart** then downloads it. Lupita never checks in the background.

This is a commitment for future versions too. If Lupita ever uses a language model, it will be
Apple's on-device model. If a feature ever needed the network, it would come switched off,
clearly labelled, and would only work if you turn it on.

### ID report (optional, sent only by you)

To help find ID formats Lupita does not know yet, hold **⌥** while you open Lupita's menu and
choose **Create ID report…**. Lupita shows every row before anything is saved, and you can
remove any of them. A row holds only the shape of an ID (letters as `A`, digits as `9`:
`E2-S3` becomes `A9-A9`), its prefix and where it is written (heading, table, list, file name,
frontmatter). It adds the name of the file, counts, and whether Lupita finds it. It never holds titles,
definitions, lines of text, folder paths or repo names (repos are «repo 1», «repo 2»).
You save the file or open a new email with it attached, and **you** press send: Lupita
makes no network call.

## Make your agents easy to look up

Lupita works without any setup: it already explains most of what your agents cite. One rule in
your agent's instructions makes it reach further: everything your agents create from now on, and
their internal vocabulary.

Lupita never writes in your repos. It gives you a prompt for your own agent. If the agent fails,
it does nothing; it asks for no commit and no judgement calls. Paste this to your agent (the
prompt is always in English; agents read it):

```text
Add this block at the end of this repo's agent instructions file (`AGENTS.md`, or `CLAUDE.md` if there is no `AGENTS.md`). Change nothing else. If the block is already there, do nothing.

<!-- lupita -->
Define each new decision, question, lesson or story once as `## ID — Title` plus a one-line summary.
Add each new internal term to the glossary (`docs/glossary.md` if there is none) as `- **term** — definition`.
Where this repo already has a format for these, keep it.
<!-- /lupita -->
```

The **Prepare your repos…** window (menu bar, and on first launch) lists the repos that have an
`AGENTS.md` or `CLAUDE.md`, how many references nothing explains yet, and whether the rule is in
place. **Copy and open** copies the prompt and opens the repo in your editor (Cursor, VS Code,
Windsurf, Zed or Finder), ready to paste.

See [`examples/demo-project`](../examples/demo-project) for a small project that uses every
format.

## Reference

### What counts as a definition

Lupita looks for IDs that are **defined** somewhere, not just mentioned. Prefixes are discovered,
not configured: `D`, `Q`, `ADR`, `QL`, `E2-S3b` or whatever your agents invented.

| Format | Example |
|---|---|
| Heading | `## D23 — Use SQLite` · `### Q07: How many repos?` |
| List or line start | `- **L34**: never parse HTML with regex` · `Q07: …` |
| First table column | `\| E2-S3 \| Voice input \| … \|` · `\| **E8-S6 Gift coins [Could]** \|` |
| File name | `docs/adr/ADR-004-storage.md` · `decisions/D23.md` |
| Frontmatter | `id: ADR-004` |

Everything else is a mention. Sections *about* an ID (`## D34 part 2`) and priority labels
(`## P1`) are recognised and kept out of the way. A file watcher reindexes the repo that
changed, so an ID written seconds ago is found anyway.

### Everything Lupita explains

Commits, branches, files and the rest are looked up at the moment you point, so they are never stale.

<details>
<summary>All 13 kinds of reference, with what the tooltip shows</summary>

| You point at | The tooltip shows |
|---|---|
| A repo name (`atlas`) | Its README title and first line, current branch, last commit and uncommitted changes |
| A commit (`e455cf7`) | Its message, date, and whether it is in `main`. Click: the commit on GitHub |
| A branch (`fix/search`) | Its last commit and how far ahead of `main` it is, or, if deleted, the merge that closed it |
| A file (`docs/decisions.md:12`) | Its title and first line (Markdown) or its last change. Click: opens it at the line |
| A command (`/retro`) | Its description, from `.claude/commands` or `.claude/skills`, in the repo or in `~/.claude` |
| A glossary term (`settlement`, `the ledger`) | Its definition, from a glossary file (`glossary.md`, `glosario.md`…) in the repo. Click: opens it at the line. Terms of one to four words work; a term from another repo is flagged |
| A symbol (`build_glyphs`, `ARM_TENSION`, `test_engine`, `"panza_a"`) | Its own comment (first 3 lines) and where it is defined, or "no comment". Window repo first; another repo is flagged. A plain word needs `()` or backticks |
| A local address (`localhost:8130`, `http://127.0.0.1:8131/x.html`) | Which repo serves it (from the listening process or `.claude/launch.json`), which page, and whether it is on. No request is made |
| A CSS token (`--accent`, `var(--accent)`) or a hex colour (`#0E5400`) | Its value in light and dark, a colour swatch, and where it is defined (or which tokens hold that colour) |
| A terminal command (`npm run build`, `git reset --hard`) | What the script does (from `package.json`) or a one-line explanation of git and common shell commands, with a warning on risky flags |
| An error (`ENOENT`, `TypeError`, `HTTP 401`) or an HTML tag (`<dialog>`) | One line from a fixed dictionary |
| A git word in prose (`rebase`, `fast-forward`, `detached HEAD`, `pushear`) | A plain-language line and an example. A word that is also everyday English (`main`, `push`, `branch`) counts only next to another git word, in inline code, or next to a file or branch name |
| A PR (`#123`, `PR 123`) | Title and merge date, read from the local git history of the window's repo; or "Not in the local history" |

</details>

Commits, branches and PRs need git (the Command Line Tools); without it they are simply not recognised.

**Switch off the jargon you already know.** Under **Explain terms of:** in the menu, each fixed
dictionary is on by default: **Git** (git words in prose and `git …` commands), **Terminal**
(shell commands such as `rm` or `chmod`) and **Development** (errors, HTTP statuses and HTML
tags). Whatever comes from your repos (IDs, glossaries, commits, branches, files, PRs, symbols,
tokens, local addresses and `package.json` scripts) is always on.

### Which repo, when IDs collide

`D001` usually exists in every repo. Lupita picks the right one by, in order: a repo named
right before the ID, a repo named in the file you are reading, the repo of the active
window, the nearest folder. When the definition comes from another repo, the tooltip says so.

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

Build from source with Xcode or just the Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/manubarranco/Lupita.git
cd Lupita
./scripts/bundle.sh
open build/Lupita.app
```

macOS forgets the permissions on every build unless the app is signed with a stable
certificate: create a self-signed **Code Signing** certificate named `Lupita Dev` in Keychain
Access, and `scripts/bundle.sh` will use it. Without it the script stops; to build anyway with
an ad-hoc signature, run `LUPITA_SIGN_IDENTITY=- ./scripts/bundle.sh`.

```bash
./scripts/test.sh                 # tests (works without Xcode)
swift run lupita index ~/Repos      # index and print stats
swift run lupita D23 --repo myrepo  # resolve an ID from the terminal
swift run lupita report ~/Repos     # accuracy report (HTML, stays local)
```

Design decisions: [`docs/decisions.md`](decisions.md), written in the same format Lupita reads.
Debug logging (what was looked up, by which method): `defaults write com.manubarranco.lupita debugLog -bool true`.

## License

[MIT](../LICENSE)
