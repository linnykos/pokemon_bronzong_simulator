# Card Index — decklist1

Verbatim card text lives one file per card in `docs/cards/`. This page is the
index and the at-a-glance summary. Every card was transcribed from
limitlesstcg.com on 2026-08-29; cards whose details drive the decision tree were
queried a second time with a pointed question, because the first pass
mis-transcribed two attacks as Abilities.

`decklists/decklist1.txt` is a legal 60: 24 Pokémon, 31 Trainer, 5 Energy.
(The section headers in that file count distinct *lines*, not cards.)

## Pokémon (24)

| n | Card | Set | Stage | Role in the turn-2 line |
|---|------|-----|-------|--------------------------|
| 4 | [Duskull](cards/PRE-035-duskull.md) | PRE 35 | Basic | Dusknoir line; fine free-retreat lead |
| 2 | [Dusclops](cards/PRE-036-dusclops.md) | PRE 36 | Stage 1 | mostly skipped via Rare Candy |
| 4 | [Dusknoir](cards/PRE-037-dusknoir.md) | PRE 37 | Stage 2 | competes for the turn-2 evolution |
| 2 | [Bronzor](cards/TEF-068-bronzor.md) | TEF 68 | Basic | **must be in play by turn 1** |
| 2 | [Bronzong](cards/TEF-069-bronzong.md) | TEF 69 | Stage 1 | **the target card** |
| 2 | [Buneary](cards/PFL-083-buneary.md) | PFL 83 | Basic | Run Around switches for free (going 2nd) |
| 2 | [Mega Lopunny ex](cards/PFL-084-mega-lopunny-ex.md) | PFL 84 | Stage 1 | competes for the turn-2 evolution |
| 2 | [Mega Kangaskhan ex](cards/MEG-104-mega-kangaskhan-ex.md) | MEG 104 | **Basic** | Run Errand draws 2 from Active |
| 1 | [Meowth ex](cards/POR-062-meowth-ex.md) | POR 62 | Basic | benching it tutors a Supporter |
| 1 | [Latias ex](cards/SSP-076-latias-ex.md) | SSP 76 | Basic | **Skyliner: free retreat for Basics** |
| 1 | [Flutter Mane](cards/TEF-078-flutter-mane.md) | TEF 78 | Basic | off-plan; must be Active to matter |
| 1 | [Budew](cards/ASC-016-budew.md) | ASC 16 | Basic | Itchy Pollen = the item-lock scenario |

## Trainers (31)

| n | Card | Set | Kind | Role |
|---|------|-----|------|------|
| 4 | [Lillie's Determination](cards/MEG-119-lillies-determination.md) | MEG 119 | Supporter | **draws 8** on turns 1-2 |
| 4 | [Hilda](cards/WHT-084-hilda.md) | WHT 84 | Supporter | **fetches Bronzong + Energy** |
| 3 | [Ciphermaniac's Codebreaking](cards/TEF-145-ciphermaniacs-codebreaking.md) | TEF 145 | Supporter | stacks 2 on top of deck |
| 2 | [Boss's Orders](cards/MEG-114-bosss-orders.md) | MEG 114 | Supporter | opponent-only; dead for our metric |
| 4 | [Rare Candy](cards/MEG-125-rare-candy.md) | MEG 125 | Item | Dusknoir only |
| 4 | [Switch](cards/MEG-130-switch.md) | MEG 130 | Item | **gets Bronzor Active** |
| 4 | [Ultra Ball](cards/MEG-131-ultra-ball.md) | MEG 131 | Item | any Pokémon; costs 2 discards |
| 4 | [Poké Pad](cards/POR-081-poke-pad.md) | POR 81 | Item | free search, **no Rule Box** only |
| 1 | [Night Stretcher](cards/ASC-196-night-stretcher.md) | ASC 196 | Item | recovery |
| 1 | [Nighttime Mine](cards/ASC-197-nighttime-mine.md) | ASC 197 | Stadium | inert for our metric |

## Energy (5)

| n | Card | Set | Kind | Role |
|---|------|-----|------|------|
| 4 | [Basic Psychic Energy](cards/SVE-005-psychic-energy.md) | SVE 5 | Basic | **the only `[P]` source** |
| 1 | [Enriching Energy](cards/SSP-191-enriching-energy.md) | SSP 191 | Special | provides `[C]`; draws 4 on attach |

---

## Things this transcription pass established

1. **Evolution Jammer is an attack costing `[P]`, 30 damage.** Not an Ability.
   Bronzong must be **Active** with a **Psychic** Energy on it.
2. **Enriching Energy provides `[C]`, not `[P]`** — it cannot pay for Evolution
   Jammer. Basic Psychic Energy (4 copies) is the deck's only `[P]` source, and
   Hilda is its only Energy search.
3. **Latias ex's Skyliner reads "Your Basic Pokémon in play have no Retreat
   Cost."** It is passive, works from the Bench, and is live from setup. This is
   the cheapest way to get Bronzor into the Active spot on turn 1 — but there
   is only **1 copy**, and **Poké Pad cannot find it** (Rule Box). Only Ultra
   Ball can.
4. **Buneary's Run Around** switches into Bronzor for free — but it is an
   attack, so it is available **only when going second**.
5. **Mega Kangaskhan ex is a Basic**, so decklist1 correctly runs no Kangaskhan,
   and its Run Errand draw-2 is live on turn 1 — but only while it is Active,
   which conflicts with Bronzor being Active.
6. **Mega Lopunny ex is a Stage 1**, so Rare Candy serves Dusknoir only.
7. **Budew's Itchy Pollen is an attack**, so the player going *first* can never
   use it on turn 1. The item-lock scenario only exists against an opponent who
   went second.

## Open items

- **Nighttime Mine's effect text is not corroborated.** The reported text hoses
  Tera Pokémon, but decklist1 runs none. Re-check before encoding an effect.
- **ASC regulation marks are inconsistent** across the source's answers (H for
  Budew and Night Stretcher, I for Nighttime Mine, in the same set). All
  candidates are Standard-legal, so this does not affect the simulation.
- **Prize counts for the `ex` cards** (Mega Lopunny ex, Mega Kangaskhan ex,
  Meowth ex) were not shown. Irrelevant to the turn-2 target event.
