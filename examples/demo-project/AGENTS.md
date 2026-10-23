# Pantry — agent context

Pantry is a small recipe-sharing app: people save recipes from the web, scale them,
and share collections with friends. iOS first, web reader second. This file is the
canonical context for coding agents working in this repo.

## Where things live

```
docs/decisions.md   ← decision log (D001…)
docs/questions.md   ← open questions for the product owner (Q01…)
docs/lessons.md     ← lessons learned the hard way (L01…)
docs/backlog.md     ← epics and stories (E1-S1…)
docs/adr/           ← architecture decision records, one file each (ADR-001…)
docs/experiments/   ← short experiments, identified by frontmatter `id:`
```

## Current state

- Storage is local-first SQLite (D001, ADR-001); sync comes later (D004).
- Recipe import parses schema.org data before anything clever (D002, L01).
- Units are stored metric and converted on display (D003). Q02 is still open.
- Next up in the backlog: E1-S2 and E2-S1.

## Rules for agents

**Define every reference before citing it.** Every decision, question, lesson or
story you create gets a definition in this exact shape, so humans can look it up:

```
## D007 — Short title
One-line summary of what was decided and why.
```

Rules that follow from this:

- One definition per ID, in the file that owns its series (`docs/decisions.md` for `D…`).
- IDs keep their leading zeros: write `D003`, never `D3`.
- Cite IDs freely anywhere else; a citation is not a definition.
- Do not reopen a decision without saying which input behind it changed.
