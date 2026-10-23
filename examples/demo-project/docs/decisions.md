# Decisions

> Newest at the bottom. Format: `## D{NNN} — Title`, then a one-line summary,
> then details. Do not reopen without stating which input changed.

## D001 — Local-first storage in SQLite
Recipes live on the device in SQLite; the app works fully offline.
Details and alternatives in ADR-001. Sync is a separate problem (D004).

## D002 — Import recipes from schema.org data first
When a user pastes a link, read the page's `Recipe` JSON-LD before trying any
heuristic scraping. About 80% of recipe sites publish it (see EXP-01).
Heuristics only run when JSON-LD is missing, which L01 taught us to log.

## D003 — Store quantities in metric, convert on display
Every ingredient quantity is stored in grams or millilitres; the display layer
converts to cups, ounces or spoons following the user's locale.
Why: scaling a recipe (E1-S3) is plain multiplication when the base unit is fixed.
Open edge case: volume-to-weight for flour and sugar, tracked in Q02 (blocks E1-S4).

## D004 — Sync through CloudKit, not our own server
Sharing collections between friends uses CloudKit shared databases. No backend to run
or pay for while the app is small. Revisit if Q04 (Android) gets a yes.

## D005 — Shared collections are read-only for guests
A collection owner can invite friends; guests can read and copy recipes but not edit
the owner's copy. Avoids merge conflicts in v1 (see L03) and keeps D004 simple.

## D006 — No ads, one-time unlock for collections
The app is free to save and scale recipes; sharing collections is a one-time unlock.
Answers Q01. Pricing details stay out of the code (ADR-002 covers the purchase flow).
