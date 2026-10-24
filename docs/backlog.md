# Backlog

> Ideas not yet decided. Format: `## B{N} — Title`, then a one-line summary, then details.
> When one is built, it becomes a decision in `decisions.md` and is removed from here.

## B1 — Git vocabulary for people who do not use git: explain the words, not only the commands
Pointing at `fast-forward`, `stash`, `rebase`, `squash`, `detached HEAD`, `upstream` or `conflict` explains the idea in plain language, for designers and other non-developers who read what agents write.
Today D29 explains git *commands* (`git stash`, `git rebase`) from a fixed dictionary, but not the bare words, their conjugations (`stashear`, `rebasear`, `hacer rebase`, `mergear`, `pushear`) or the concepts that have no command (fast-forward, detached HEAD, upstream, origin, HEAD, working tree, conflict markers).
Open questions: bare words are ordinary English (`merge`, `stash`, `squash`, `head`), so they need a rule against noise (backticks only, as D31 does for `open`/`make`, or a short list of words that are safe alone: `rebase`, `fast-forward`, `stash`); Spanish forms and the verbs agents write in a chat; one-line meaning plus a tiny everyday comparison ("a stash is a drawer where you put your unfinished work"); keep it a fixed dictionary, no language model (D26, D32).
Source of the idea: Manu, 2026-10-25; shared by designers who read agent output.
