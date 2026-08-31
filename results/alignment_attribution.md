# What each `/align-decision-tree` fix is worth

Written by `scripts/attribute_changes_claude.R` on 2026-08-30. **1000 replicates per cell**, seeds 1-1000 in every cell.

Each row is that change **neutralised on its own**, against the otherwise-current policy, so the rows do not add up to the total movement and are not meant to. A negative number is a change that COSTS points and is kept anyway, because it is a ruling rather than an optimisation and the documents are the specification.

Every patch is an exact line-block substitution asserted to have matched exactly once, so a patch that matches nothing stops the script rather than reporting 0.0. **A row is measured on the list that runs the card**, since a rule about Gwynn measures exactly zero on a list with no Gwynn -- and a zero meaning *not exercised* looks identical to a zero meaning *worth nothing*.

**Read the noise floor before reading the rows.** At 1000 paired replicates the standard error on one of these differences is roughly **0.2 to 0.4 points**, so a row under about 0.6 is not distinguishable from zero and should be read as *this change did not move the metric* rather than as a measured small gain.

**Most of these rows are supposed to be zero.** They are **correctness** fixes found by auditing the code against the documents, not optimisations: a rule that stops the policy making a play the documents forbid has done its job whether or not the rate moves, and several of them govern the board the window closes on rather than whether the attack happens. Read a 0.0 here as *the code now does what the document says, at no cost*.

## The whole movement, and what is left unattributed

| cell | before | after | attributed |
|---|---|---|---|
| decklist7, going second | 79.0% | **80.5%** | +1.4 of +1.5 |
| decklist7, going first | 65.8% | **67.2%** | +1.6 of +1.4 |
| decklist7, `item_lock` first | 63.7% | **65.1%** | +1.3 of +1.4 |
| decklist2, going second | 77.5% | **77.8%** | 0.0 of +0.3 |
| decklist2, going first | 64.3% | **63.9%** | 0.0 of −0.4 |
| decklist2, `item_lock` first | 61.6% | **61.2%** | 0.0 of −0.4 |

**decklist7's gain is one fix.** Want-list item 4's second clause — "Latias ex, if not in play and **Bronzor is not Active**" — was coded as "and sub-goal C is not met", i.e. *Bronzong* not Active. With a Bronzor Active the policy therefore kept chasing a mover it did not need, and on the going-first branch that is worth **2.0 points**. Everything else on the list is correctness at no cost.

**decklist2's movement is unattributed and is noise.** Both fixes measured on it come out at 0.0, and the residual (+0.3, −0.4, −0.4) sits inside the ±0.4 standard error on a single rate difference. Nothing in the alignment is expected to move decklist2: seven of the nine fixes need two Bronzor printings, two Latias ex or a basic Darkness Energy, and decklist2 has none of those.

**One fix costs points and stays.** Protecting one Duskull and one Rare Candy from the discard is worth +0.4 going second and **−0.6 / −0.7 going first**, because a protected Duskull more often leaves Ultra Ball with fewer than two spare cards and therefore unplayable. It stays because the playbook's discard order says "surplus Duskull beyond 1" and "surplus Rare Candy", and because decklist7 and decklist8 run **one** Rare Candy — the card the §4.3 rung-5 escape cannot be run without. That is a ruling about how the deck should be played, not an optimisation.

## decklist7

Current policy: **80.5%** going second, **67.2%** going first, **65.1%** going first under `item_lock`.

| change | going second | going first | `item_lock` first |
|---|---|---|---|
| want-list item 4's second clause is about a **Bronzor** Active | 0.8 | 2.0 | 1.8 |
| "in play" includes the Active spot, not just the Bench | 0.4 | 0.2 | 0.2 |
| one Duskull and one Rare Candy are protected from the discard | 0.4 | -0.6 | -0.7 |
| only one Latias ex is benched | 0.2 | 0.0 | 0.0 |
| the Telepathic goes to the `[P]` printing, not to Bench order | 0.0 | 0.0 | 0.0 |
| one multi-target search never fetches two Bronzor printings | 0.0 | 0.0 | 0.0 |
| Hilda's Energy search takes **any** Energy, Darkness included | 0.0 | 0.0 | 0.0 |
| Meowth ex leaves the want-list once no Supporter can be played | 0.0 | 0.0 | 0.0 |
| "a Bronzor is missing" counts one in hand | 0.0 | 0.0 | 0.0 |
| the Stadium and the leftover Rare Candy precede the fallback | 0.0 | 0.0 | 0.0 |

## decklist2

Current policy: **77.8%** going second, **63.9%** going first, **61.2%** going first under `item_lock`.

| change | going second | going first | `item_lock` first |
|---|---|---|---|
| "in play" includes the Active spot (decklist2) | 0.0 | 0.0 | 0.0 |
| the Stadium and the Rare Candy precede the fallback (decklist2) | 0.0 | 0.0 | 0.0 |

