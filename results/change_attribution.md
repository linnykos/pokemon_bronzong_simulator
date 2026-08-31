# What each change is worth

Written by `scripts/attribute_changes_claude.R` on 2026-08-30. **1000 replicates per cell**, seeds 1-1000 in every cell.

Each row is that change **neutralised on its own**, against the otherwise-current policy, so the rows do not add up to the total movement and are not meant to. A negative number is a change that COSTS points and is kept anyway, because it is a ruling rather than an optimisation and the documents are the specification.

Every patch is an exact line-block substitution asserted to have matched exactly once, so a patch that matches nothing stops the script rather than reporting 0.0. **A row is measured on the list that runs the card**, since a rule about Gwynn measures exactly zero on a list with no Gwynn -- and a zero meaning *not exercised* looks identical to a zero meaning *worth nothing*.

**Read the noise floor before reading the rows.** At 1000 paired replicates the standard error on one of these differences is roughly **0.2 to 0.4 points**, so a row under about 0.6 is not distinguishable from zero and should be read as *this change did not move the metric* rather than as a measured small gain. Several rows below are exactly that, and two of them are supposed to be: S-18 and S-19 change the **board the window closes on**, not whether the attack happens, so a 0.0 there is the answer rather than a disappointment.

**The headline for this round: Kevin's twelve answers were worth about 1.7 points**, 75.8% to 77.5% going second — against the 23 points the previous bank of fourteen moved. That is the shape of a policy that is mostly right: the first bank found structural gaps (a Supporter slot left idle every turn), and this one found refinements and one position the tree could win and did not (S-20).

## decklist2

Current policy: **77.5%** going second, **64.3%** going first, **61.6%** going first under `item_lock`.

| change | going second | going first | `item_lock` first |
|---|---|---|---|
| S-22: Enriching Energy takes an unclaimed attachment (PB-09) | 0.6 | 0.9 | 0.6 |
| S-24 / ADR 0008: the measured lead order, going second | 0.4 | 0.0 | 0.0 |
| S-20: Dusknoir on the want-list for the escape (PB-17) | 0.3 | 0.2 | 0.0 |
| S-21: Ultra Ball protects every Bronzong, not the last copy | 0.3 | 0.0 | 0.0 |
| S-18: a spare `[P]` goes to a second Bronzong | 0.0 | 0.0 | 0.0 |
| S-19: Rare Candy once Bronzong is settled (§8) | 0.0 | 0.0 | 0.0 |
| S-21: ...and every Bronzor, without a Salvatore in hand | 0.0 | 0.0 | 0.0 |
| the kill line re-checks it still holds the Salvatore | 0.0 | 0.0 | 0.0 |
| S-22: every Poké Pad in hand is played | -0.1 | -0.6 | 0.6 |

## decklist7

Current policy: **79.0%** going second, **65.8%** going first, **63.7%** going first under `item_lock`.

| change | going second | going first | `item_lock` first |
|---|---|---|---|
| Risky Ruins is declined as disruptive to us (decklist7) | 0.3 | 0.2 | 0.1 |
| Gwynn is played at all (decklist7) | -0.3 | 0.3 | -0.2 |

