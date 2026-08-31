# The section 3 lead order, settled from the logs (DT-03)

Written by `scripts/tune_lead_order_claude.R` on 2026-08-30. decklist2, scenario `clear` unless stated.

Greedy positional search, **2000 replicates per evaluation**, common random numbers within a round. Bronzor is pinned at rank 1 and Meowth ex is excluded: both are rulings in section 3, not defaults for this search to overturn.

**78% of decklist2 opening hands hold no Bronzor** (`C(58,7)/C(60,7)`), so this order binds on most games rather than on the 3% of hands the S-24 position described.

### Going second

| rank | candidate | hit rate |
|---|---|---|
| 1 | Mega Kangaskhan ex | 75.6% |
| 1 | Buneary | 75.0% |
| 1 | Duskull | 75.4% |
| 1 | Budew | 74.9% |
| 1 | Flutter Mane | 75.6% |
| 1 | Latias ex | 75.8% |
| 2 | Mega Kangaskhan ex | 75.8% |
| 2 | Buneary | 75.1% |
| 2 | Duskull | 75.6% |
| 2 | Budew | 75.0% |
| 2 | Flutter Mane | 75.8% |
| 3 | Buneary | 75.8% |
| 3 | Duskull | 76.3% |
| 3 | Budew | 75.3% |
| 3 | Flutter Mane | 75.8% |
| 4 | Buneary | 76.3% |
| 4 | Budew | 76.3% |
| 4 | Flutter Mane | 76.3% |
| 5 | Buneary | 76.3% |
| 5 | Flutter Mane | 76.4% |

### Going first

| rank | candidate | hit rate |
|---|---|---|
| 1 | Mega Kangaskhan ex | 63.7% |
| 1 | Buneary | 62.7% |
| 1 | Duskull | 63.0% |
| 1 | Budew | 63.1% |
| 1 | Flutter Mane | 63.3% |
| 1 | Latias ex | 63.7% |
| 2 | Buneary | 63.7% |
| 2 | Duskull | 64.0% |
| 2 | Budew | 63.4% |
| 2 | Flutter Mane | 63.6% |
| 2 | Latias ex | 64.0% |
| 3 | Buneary | 64.0% |
| 3 | Budew | 64.0% |
| 3 | Flutter Mane | 63.9% |
| 3 | Latias ex | 64.1% |
| 4 | Buneary | 64.1% |
| 4 | Budew | 64.1% |
| 4 | Flutter Mane | 64.0% |
| 5 | Budew | 64.1% |
| 5 | Flutter Mane | 64.0% |

## Out-of-sample confirmation

A greedy search picks the maximum of twenty noisy numbers, which is the procedure that reports a winner when there is none. So the winner is re-run against the incumbent on **5000 replicates from a disjoint seed block** (seeds 100001-105000).

| cell | order | which | hit rate |
|---|---|---|---|
| going second | Mega Kangaskhan ex > Buneary > Duskull > Budew > Flutter Mane > Latias ex | incumbent | 73.4% |
| going second | Latias ex > Mega Kangaskhan ex > Duskull > Budew > Flutter Mane > Buneary | search | 74.7% |
| going first | Mega Kangaskhan ex > Duskull > Budew > Buneary > Flutter Mane > Latias ex | incumbent | 62.8% |
| going first | Mega Kangaskhan ex > Duskull > Latias ex > Buneary > Budew > Flutter Mane | search | 62.9% |

Going first under `item_lock`, which the search never optimised: incumbent 60.5%, search 60.5%.


## A second, paired confirmation, and what was actually adopted

The first confirmation compares two independent rates. A **paired** comparison on
a third disjoint seed block (seeds 200001-205000) is sharper, because under common
random numbers most replicates hit or miss under both orders and only the
discordant ones carry information.

| cell | order | hit rate |
|---|---|---|
| going second | incumbent | 73.22% |
| going second | search winner | 73.90% |
| going first | incumbent | 62.66% |
| going first | going-first search winner | 62.62% |
| going first | going-second search winner | 62.44% |

**Going second: +0.68 points, standard error 0.20**, over 98 discordant
replicates in 5,000. Two independent blocks now agree in sign and rough size, so
the change is adopted:

> **Latias ex > Mega Kangaskhan ex > Duskull > Budew > Flutter Mane > Buneary**

**Going first: nothing.** Three orders, including the one the greedy search
produced for that cell, land within 0.22 points of each other — smaller than the
standard error on a single rate. The incumbent order therefore **stands
unchanged**, rather than being replaced by the largest of twenty noisy numbers.
That is the whole reason for the out-of-sample step (ADR 0008), and it is the
result on one of the two cells.

`item_lock` going first, which the search never optimised: 60.30% incumbent,
60.04% under the going-second winner — also nothing, and the incumbent stays there
too since that cell shares the going-first order.

## The finding that matters more than the ranking

**The lead order is worth about a point.** At rank 1 going second the six
candidates span 74.9% to 75.8%; going first, 62.7% to 63.7%. Against the 23 points
the Supporter rules moved, this is a rounding error, and S-24's intuition that the
lead is where a game is won or lost is not what the logs say.

**Kevin's specific guess was not confirmed.** S-24 read *"overall, opening Duskull
would have been better"* than the Kangaskhan §3 chose. Measured, Kangaskhan is
ahead of Duskull in both cells — 75.6% against 75.4% going second, and 63.7%
against 63.0% going first — so §3's original choice between those two survives.
What did change is the pair Kevin was not asked about: **Latias ex rises from last
to first going second, and Buneary falls from second to last.**

Buneary's fall is the tree disagreeing with itself, resolved. Its whole case as a
lead is Run Around, and §4.2 then classes Run Around as a **last resort** because
it spends the turn's Energy attachment and strands the Energy on the Bench. A lead
whose one virtue the rest of the tree declines to use is not a virtue.
