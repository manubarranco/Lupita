# Backlog

Stories are grouped by epic. A story ID is `E{epic}-S{story}`.

## E1 — Save and scale recipes
Everything a single cook needs: import, edit, scale and convert units.

| Story | Status | Notes |
|---|---|---|
| **E1-S1 Import a recipe from a link [Must]** | ✅ done | JSON-LD first (D002); keep the source link (Q03) |
| **E1-S2 Edit an imported recipe [Must]** | in progress | Local edits only, stored per D001 |
| **E1-S3 Scale a recipe to N servings [Must]** | next | Metric base units (D003); no early rounding (L02) |
| **E1-S4 Show quantities in the user's units [Should]** | next | Blocked by Q02 for flour and sugar |

## E2 — Share collections
Friends share curated recipe collections; the paid part of the app (D006).

| Story | Status | Notes |
|---|---|---|
| **E2-S1 Create a collection [Must]** | next | Local only until D004 lands |
| **E2-S2 Invite a friend to a collection [Should]** | later | Read-only guests (D005); one-time unlock (D006) |
| **E2-S3 Copy a shared recipe into my pantry [Could]** | later | Answers part of Q05 without shared editing |
