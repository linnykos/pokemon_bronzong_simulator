# Pokémon TCG — Standard Format Rules Reference

**Scope:** the rules this simulator needs to model correctly. Weighted toward setup and the first two turns of a game, since that is what `pokemon_bronzong_simulator` measures. Sections marked **[UNVERIFIED]** could not be confirmed from a primary source and should be checked against actual card text before the simulator relies on them.

Last verified: 2026-08-29.

---

## 1. Format definition

**Standard format, 2026 season.** A card is legal if and only if its **regulation mark** (printed at the bottom of the card, next to the card number) is one of:

| Mark | Roughly covers | Status |
|------|----------------|--------|
| `F` and earlier | SWSH era | rotated out |
| `G` | Scarlet & Violet base through Pokémon 151 | **rotated out** (April 2026) |
| `H` | Paradox Rift / **Temporal Forces (SV05)** through the Prismatic Evolutions era | legal |
| `I` | 2025 sets (Mega Evolution era) | legal |
| `J` | 2026 sets | legal |

Rotation took effect **2026-03-26** on Pokémon TCG Live and **2026-04-10** for in-person Play! Pokémon events.

Note that `G` stops at **Pokémon 151 (SV3.5)**. Temporal Forces is later than that and carries regulation mark **H**, so the whole TEF-era Bronzong line is Standard-legal for 2026.

Legality attaches to the *card*, not the *expansion*. If any printing of a card carries a legal regulation mark, then all printings of that card are legal, including old printings that predate regulation marks entirely. For the simulator, two physical cards with the same name are the same card for deck-construction and game purposes.

Cards with no regulation mark and no legal reprint are not legal.

---

## 2. Deck construction

- A deck is **exactly 60 cards**.
- **Maximum 4 copies** of any card sharing the same name.
  - **Exception:** basic Energy cards (Grass, Fire, Water, Lightning, Psychic, Fighting, Darkness, Metal, Fairy, Dragon, Colorless) have no copy limit.
  - Special Energy cards (Jet Energy, Mist Energy, Enriching Energy, …) are **not** basic Energy and are capped at 4.
- **ACE SPEC:** at most **1 ACE SPEC card total** in the deck, across all ACE SPEC names combined (e.g. Prime Catcher, Maximum Belt, Hero's Cape).
- The deck must contain **at least one Basic Pokémon**. A deck with too few Basics loses to mulligans, which is part of what this simulator measures.
- No sideboard. The same 60 cards are used for every game of a match.

### Card categories

Every card is exactly one of:

1. **Pokémon** — Basic, Stage 1, Stage 2, or a Mega Evolution / special mechanic that specifies its own evolution line.
2. **Trainer** — subdivided into **Item**, **Supporter**, **Stadium**, and **Pokémon Tool**.
3. **Energy** — subdivided into **basic Energy** and **Special Energy**.

---

## 3. Setup

Setup happens before either player's first turn and is deterministic given the shuffled deck orders and the coin flip. The simulator models this sequence exactly.

1. Each player shuffles their 60-card deck.
2. **Coin flip.** The winner **chooses whether to go first or second**. Under current rules going second is generally preferred, because the player going first can neither attack nor play a Supporter.
3. Each player draws **7 cards**.
4. **Mulligan check.** A player whose opening 7 contains **no Basic Pokémon** must mulligan:
   - Reveal the hand to the opponent.
   - Shuffle it back into the deck.
   - Draw a new hand of 7.
   - Repeat until the hand contains at least one Basic Pokémon.
   - For **each** mulligan a player took, the opponent may draw **1 extra card**. The opponent chooses how many of the entitled extra cards to actually draw, and draws them after both players have finished mulliganing.
5. Each player places **1 Basic Pokémon face down as their Active Pokémon**.
6. Each player may place **up to 5 additional Basic Pokémon face down on their Bench**. Bench maximum is 5.
   - Only **Basic** Pokémon may be placed during setup. Evolution cards cannot be played during setup.
7. Each player takes the **top 6 cards** of their deck and sets them aside face down as **Prize cards**, without looking.
8. Both players turn their Active and Benched Pokémon face up. The game begins.

### Prize cards — why they matter here

The 6 Prizes are removed from the deck *before* the first draw and are unknown to the player. Any card can be prized. A deck's consistency is therefore a function of both draw order and the probability that a critical low-count card is sitting in the prize pile, unavailable for the entire early game.

The simulator must model prizes as **6 specific cards removed from the deck at setup**, not as an abstraction — otherwise it will overstate consistency.

---

## 4. Turn structure

1. **Draw step.** Draw 1 card from the top of your deck.
   - If your deck is empty and you must draw, **you lose**, checked at the moment of drawing.
2. **Main step.** In any order, any number of times unless limited:
   - Play Basic Pokémon from hand to the Bench (Bench limit 5).
   - **Evolve** Pokémon (see §5).
   - Attach **1 Energy** from hand to one of your Pokémon — **once per turn**.
   - Play any number of **Item** cards.
   - Play **1 Supporter** card — **once per turn**.
   - Play **1 Stadium** card — **once per turn**, and only if it does not share a name with the Stadium already in play.
   - Attach **Pokémon Tools** (any number, but max 1 Tool per Pokémon unless the card says otherwise).
   - Use **Abilities**, subject to each Ability's own text and frequency.
   - **Retreat** the Active Pokémon — **once per turn** — by discarding Energy equal to its Retreat Cost, then swapping with a Benched Pokémon.
3. **Attack step.** Declare one attack with your Active Pokémon, if it has the required Energy attached and is not prevented from attacking.
   - **Your turn ends immediately after you attack.**
   - You may decline to attack; your turn then ends when you say so.

### Per-turn limits

| Action | Limit per turn |
|--------|----------------|
| Draw (draw step) | 1 (automatic) |
| Energy attachment from hand | 1 |
| Supporter | 1 |
| Stadium | 1 |
| Retreat | 1 |
| Attack | 1, and it ends the turn |
| Items | unlimited |
| Benching Basics | unlimited, up to Bench size 5 |
| Evolutions | unlimited, subject to §5 |

---

## 5. Evolution rules

These rules set the floor on how fast an evolving attacker can attack, and they are the crux of this project.

- To evolve, play an Evolution card from hand onto the Pokémon named in its **"Evolves from"** line. Damage counters, attached Energy, and attached Tools **stay**; Special Conditions are **removed**.
- **You cannot evolve a Pokémon on the turn it came into play.** A Basic benched this turn cannot evolve this turn.
- **You cannot evolve any Pokémon on your first turn of the game.** This applies to both players, and applies to Pokémon placed during setup.
- **You cannot evolve a Pokémon twice in one turn**, nor evolve a Pokémon that evolved or devolved earlier that same turn.
- Evolving works whether the Pokémon is Active or Benched.
- Certain cards explicitly override these restrictions. **One is in these decklists and it matters enormously: [Salvatore](cards/TEF-160-salvatore.md) (TEF 160).** It overrides *both* the played-this-turn restriction and the **first-turn** restriction — confirmed with the player, 2026-08-29. See §5.1.

### Rare Candy

**Rare Candy** (Item) evolves a **Basic** Pokémon directly into its **Stage 2**, skipping Stage 1. It is still an evolution, so every restriction above still applies: not on your first turn, and not on the turn the Basic came into play.

## 5.1 The earliest possible Evolution Jammer

**Without Salvatore**, combining §4 and §5:

- A Basic placed during **setup** cannot evolve on your **turn 1**.
- So the earliest a Stage 1 (or a Stage 2 via Rare Candy) can be **in play**, and therefore the earliest it can **attack**, is your **turn 2**.
- This holds whether you go first or second. Going second only removes the "cannot attack on turn 1" restriction — on its own it does not permit evolving on turn 1.

**With Salvatore**, the first-turn evolution ban is lifted. Going **second** — where you may play a Supporter *and* attack on turn 1 — the full line fits inside turn 1:

1. Bronzor in the Active spot (led from setup, or switched into during turn 1);
2. play **Salvatore**, searching out **Bronzong** and evolving Bronzor;
3. attach a `[P]` Energy (basic Psychic, or Telepathic Psychic);
4. attack **Evolution Jammer**.

Going **first** this is impossible: no Supporter and no attack on turn 1.

### The earliest achievable turn, per cell

| | Salvatore lists (2,3,4,5,7) | No-Salvatore lists (1,6,8) |
|---|---|---|
| **Going second** | **turn 1** | turn 2 |
| **Going first** | turn 2 | turn 2 |

The "first turn possible" is therefore a property of the *(decklist, coin flip)* pair, not a constant. **Part 6 must report per cell and must not pool across them** — pooling would make a Salvatore list look worse simply because half its games go first.

The simulator should record the **actual turn** Evolution Jammer was achieved (or never), so both "hit the theoretical earliest" and "hit by turn 2 regardless" can be read off the same runs.

### The target event

At the attack step of the relevant turn, all of the following hold —

1. A **Bronzor** is in play, and is eligible to evolve:
   - by the **normal** route, it must have been in play since before this turn began — i.e. from setup or from the previous turn — and this must not be the player's first turn; or
   - via **Salvatore**, in which case none of that applies: it may have been placed at setup, or benched this very turn, and it may be the player's first turn.
2. **Bronzong (TEF #69)** is on that Bronzor — played from hand, or fetched straight out of the deck by Salvatore.
3. That Bronzong is in the **Active** spot.
4. It has at least **one `[P]` Energy** attached — basic Psychic, or Telepathic Psychic Energy. **Enriching Energy does not qualify**: it provides `[C]`.
5. Nothing prevents it from attacking, and this is not the player's first turn *going first*.

Three constraints follow, and the decision tree must treat each as a first-class branch:

- **Only one Energy attachment per turn.** The `[P]` may go onto the Bronzor on an earlier turn (it carries through evolution) or onto the Bronzong on the turn it attacks. Attaching earlier is more flexible, since it frees the later attachment for Enriching Energy's draw 4.
- **Bronzong must be Active** (requirement 3). If Bronzor is on the Bench the player must move the current Active out of the way. Note that **retreating costs the retreat cost of the Pokémon leaving the Active spot**, not the one being promoted — so Bronzor's own retreat cost of 3 is irrelevant here; what matters is what is currently Active. The outs are: lead Bronzor from setup (free); **Latias ex's Skyliner**, which makes *any Basic* Active retreat for free, and on turn 1 the Active is almost always a Basic; **Switch**; or **Buneary's Run Around** (an attack, so going second only).
- **Salvatore does not solve the Active problem** — it evolves a Bronzor anywhere on the board. It removes the timing constraint, not the positioning one.

---

## 6. First-turn restrictions

Player going **first**, on their first turn only:

- They **do** take a draw step and draw 1 card.
- They **cannot play a Supporter card.**
- They **cannot attack**; the attack step is skipped and the turn ends.
- Everything else is permitted: bench Basics, attach 1 Energy, play Items, play a Stadium, use Abilities, retreat.

Player going **second**, on their first turn:

- Draws, with **no** Supporter restriction and **no** attack restriction.

Both players are subject to the no-evolution-on-your-first-turn rule in §5.

### Turn numbering convention used in this project

Turns are numbered **per player**:

- `P1T1` = first player's first turn, `P2T1` = second player's first turn, `P1T2` = first player's second turn, etc.
- Global order is P1T1 → P2T1 → P1T2 → P2T2 → …
- "Turn 1" in casual phrasing means **the player's own first turn**.
- The Evolution Jammer target is **P1T2** or **P2T2** depending on which side we simulate.

---

## 7. Attacking and damage

- To attack, the Active Pokémon must have at least the Energy shown in the attack's cost. Colorless (`C`) may be paid by any Energy type.
- Apply **Weakness** (×2 in current Standard), then **Resistance** (−30), then other effects, in that order.
- If damage on a Pokémon is ≥ its HP it is **Knocked Out**: it and everything attached go to the discard pile, and the attacking player **takes 1 Prize card** — or more if the Knocked Out Pokémon's rule box says so (Pokémon *ex* give up **2 Prizes**).
- After a Knock Out, the player with no Active Pokémon promotes a Benched Pokémon.

---

## 8. Win conditions

A player wins immediately when:

1. They have taken **all 6 of their Prize cards**; or
2. Their opponent has **no Pokémon in play** when a replacement Active is required; or
3. Their opponent **cannot draw** at the start of their draw step (deck-out).

If multiple win conditions are met simultaneously, the game is a tie.

---

## 9. Special Conditions

| Condition | Effect |
|-----------|--------|
| Asleep | Cannot attack or retreat. Flip a coin between turns; heads wakes up. |
| Burned | 2 damage counters between turns; flip a coin, tails deals it again. |
| Confused | Flip to attack; tails deals 3 damage counters to itself and the attack fails. Cannot retreat normally. |
| Paralyzed | Cannot attack or retreat. Removed at the end of that player's next turn. |
| Poisoned | 1 damage counter between turns. |

All Special Conditions are removed when the Pokémon **evolves**, **retreats**, or otherwise leaves the Active spot.

Special Conditions are largely irrelevant to a turn-1/turn-2 setup simulator and may be stubbed in the first version.

---

## 10. Abilities

- Abilities come from the Pokémon's printed Ability text and are **not** attacks. Using an Ability does not end your turn.
- Unless the text says otherwise, an Ability works whether the Pokémon is Active or Benched.
- Frequency follows the card text: "once during your turn", "as often as you like", or a passive/continuous effect.
- Abilities on a Pokémon that is Asleep, Confused, or Paralyzed still work unless stated otherwise.
- An Evolution Pokémon's Ability is available **the turn it evolves** — there is no summoning sickness for Abilities. (This is the single biggest asymmetry between Abilities and attacks for turn-2 lines.)

---

## 11. Rules relevant to search and draw consistency

These mechanics determine whether a decklist "gets there", and the simulator's decision logic must reason about them.

- **Deck order is unknown to the player.** A search card (Nest Ball, Ultra Ball, Buddy-Buddy Poffin) lets the player see the whole deck and pick optimally. A draw card (Iono, etc.) yields a random result.
- **Prizes are unknown.** A search card cannot find a prized card. The simulator must return "not found" when the only copies are prized. A human player learns a card is prized only by failing to find it — the decision logic must not cheat by peeking at the prize pile.
- **Shuffle-draw vs. draw-off-the-top** matters: an effect that shuffles before drawing re-randomizes the remaining unknown cards; an effect that draws off the top does not.
- **Discard costs** (e.g. Ultra Ball's "discard 2 cards from your hand") can make a search card unplayable or cost a resource needed later. The decision logic must decide what it is willing to discard.

---

## 12. Open items to confirm against card text

**[UNVERIFIED]** — resolve these in `docs/cards/` (part 2) before the simulator depends on them.

1. ~~Which Bronzong printing has Evolution Jammer, and is it Standard-legal?~~ **RESOLVED.** It is **Bronzong, Temporal Forces (TEF) #69, regulation mark H** — Standard-legal for 2026. Full text in `docs/cards/`. Two other Bronzong printings exist in Standard and are *not* the one we want: PFL #72 (reg I, Triple Draw / Tool Drop) and PBL #64 (reg J, Gentle Slap / Metal Block).
2. **Mega Evolution (`Mega … ex`) mechanics.** Whether "Mega Lopunny ex" is a Stage 1 evolving from Buneary or uses a distinct Mega mechanic, whether Rare Candy can reach it, and what its rule box does (Prizes given up, any evolution-timing exceptions).
3. Whether the **"player going first cannot play a Supporter"** rule (introduced 2020-02-21) is still in force in the 2026 season. Assumed yes.
4. Exact text of every card in the decklist, once provided.

---

## Sources

- 2026 Standard rotation and regulation marks — [pokemon.com rotation announcement](https://www.pokemon.com/us/pokemon-news/2026-pokemon-tcg-standard-format-rotation-announcement)
- Evolution timing restrictions — [Bulbapedia, "Evolution (TCG)"](https://bulbapedia.bulbagarden.net/wiki/Evolution_(TCG))
- First-turn Supporter/attack restrictions — [PokeGuardian, 2020 rule-change announcement](https://www.pokeguardian.com/386462_first-turn-no-supporter-rule-regulation-marks-has-been-officially-announced-fairy-type-no-longer-supported)
- Card text — [limitlesstcg.com](https://limitlesstcg.com)
