# Store recipes locally in SQLite

Status: accepted. Implements D001.

## Context
Pantry must work in a kitchen with bad Wi-Fi. Recipes are small (a few KB each) and
most people keep fewer than 500.

## Options
- SQLite through GRDB: mature, fast, full-text search for ingredients.
- Core Data: native, but migrations have hurt us before.
- JSON files: simple, but no search and painful to sync later (D004).

## Decision
SQLite through GRDB, one database per user. Full-text search over titles and ingredients.

## Consequences
Sync is a separate layer (D004). Quantities are stored in metric per D003.
