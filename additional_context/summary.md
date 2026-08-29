# additional_context/ — Reference Material Index

Reference material for the Pokémon TCG Bronzong simulator. Read this file before
opening anything in this folder — it exists so that future sessions do not
re-read the same source twice.

**This project is not literature-driven**, so this folder holds rules artifacts
rather than papers: official rulebook PDFs, ruling-compendium excerpts, tournament
reports, or saved card-database pages worth keeping offline. Verbatim card text
does **not** live here — it lives in `docs/cards/`, one file per card.

Entries are grouped by topic, not by date. Superseded material is marked
`[SUPERSEDED by X]` rather than deleted.

Last updated: 2026-08-29

---

## Status

**Empty.** Nothing has been saved here yet. Every source consulted so far was
fetched live and its URL plus verification date recorded at the bottom of the
document that used it — see `docs/01_rules_standard.md` (§Sources) and the
per-card files in `docs/cards/`.

Add material here when a source is (a) load-bearing for a rules decision and
(b) at risk of moving or disappearing. The two current candidates:

- An authoritative ruling on **whether Salvatore permits evolving on your first
  turn**. This is the single highest-stakes rules fact in the project — it
  decides whether the target event is turn 1 or turn 2 for five of six
  decklists. It is currently recorded as *confirmed by Kevin* (2026-08-29) with
  no citable source; web sources actively contradicted each other. See
  `docs/adr/0002-salvatore-enables-turn-1-evolution.md`.
- Corroboration for **Nighttime Mine's** effect text, which is uncorroborated
  and internally implausible (it hoses Tera Pokémon; no decklist runs any).

## Entry format

```
### <citation key or short slug>
**Source**: <URL or document title>
**Retrieved**: YYYY-MM-DD
**Why it is here**: <the specific claim this source backs>
**Summary**: <2–4 sentences>
```
