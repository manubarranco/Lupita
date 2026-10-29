<img src="docs/brand/lupita.svg" width="80" alt="Lupita: a magnifying glass with two pill eyes">

# Lupita

**Lupita explains the references AI agents use, right where you read them.**

[Leer en español](README.es.md)

LLMs have no persistent memory. They make up for it by writing everything down in the repo's
files and leaving themselves references, so they can find and load what they need later. But
when they talk to you, they forget you don't have their context or their working memory, and
they say things like:

> *Logged L023 and D042. Open questions Q34-36 are still pending. Shall we start with E3S1?*

Lupita is a macOS menu bar app that looks those references up in your repos, the same way your
agents do, and explains them on the spot.

![Lupita demo: pointing at D003 in an agent chat shows its definition](docs/demo.gif)

**[⬇ Download Lupita for macOS](https://github.com/manubarranco/Lupita/releases/latest/download/Lupita.zip)**

Free and open source · Everything stays on your Mac · macOS 14 or later, Apple Silicon

## How it works

1. You tell it which folders hold your repos, and switch on the ones you're working in.
2. Lupita finds the references in their `.md` files and indexes them.
3. Hold ⌃⌥⌘ and it underlines everything on screen it can explain.
4. Let go with the pointer over a reference and it explains it in a tooltip, right there.

It works in any app: Cursor, Claude, Obsidian, Slack, a note, a document, an email… Wherever
there's a reference, Lupita reads it from your screen.

And not just IDs like `D042`: commits, branches, files, commands and the glossary terms of
your repos too.

## When things get technical

Besides references, Lupita comes with plain-language dictionaries for development, the terminal
and Git. If someone mentions a `rebase`, an `HTTP 401` or a `chmod`, it explains it in one line.
They are there to close the gap between design, development and business, and you can switch
them off from the menu if you already know your way around.

## Everything stays on your Mac

Lupita is deterministic: it uses no AI and needs no internet to work. Nothing is sent to the
cloud, and nothing you look up is stored. The only connection is checking for updates, and only
when you ask.

To read your screen it asks for two macOS permissions, and uses them only when you press the
shortcut:

- **Accessibility**: for the shortcut, and to read text in apps that allow it.
- **Screen Recording**: to read apps that don't (Cursor, Claude or your browser) with macOS's
  own OCR.

## Install

Download `Lupita.zip`, unzip it and move `Lupita.app` to Applications.

It isn't notarized by Apple yet, so macOS will block it the first time. To open it, go to
**System Settings → Privacy & Security**, scroll down to **Security** and click **Open Anyway**.

To update, open Lupita's menu and choose **Check for updates…**. It installs in one click and
keeps its permissions.

## Help your agents be clearer

Lupita works with no setup. But if you want it to understand everything your agents create from
now on, ask them to write it in a format Lupita can read. The **Prepare your repos…** window
gives you the prompt and opens each repo in your editor, ready to paste.

## More details

Everything Lupita recognises, how it picks between repos, its limits and how to build it from
source are in the [reference](docs/reference.md).

## Support the project

If you like Lupita, give it a star on GitHub ⭐️ And if you find something it doesn't explain,
[tell me](../../issues).

[MIT](LICENSE) licence.
