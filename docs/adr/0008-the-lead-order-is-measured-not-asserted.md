# 0008 — The §3 lead order is a measured parameter, not an asserted ranking

`docs/03_decision_tree.md` §3 ranks which Basic leads when the opening hand holds
no Bronzor. That ranking decides most games — on decklist2, `C(58,7)/C(60,7)` =
**78% of opening hands hold no Bronzor at all** — and it was written before any
game had been simulated. Kevin flagged it as a default rather than a ruling from
the start (DT-03), and when the bank finally put it as a concrete position he
declined to answer from intuition: *"this is something we would need the Monte
Carlo simulator to answer decisively."*

**So the order is a parameter of the policy, and it is chosen by measurement.**
`LEAD_ORDER_LIST` in `R/decision_claude.R` holds it, `make_policy_placement()`
supplies it through the `placement_fn` hook `setup_game()` actually calls, and
`scripts/tune_lead_order_claude.R` is what varies it. §3 then states the measured
order and cites this record rather than re-arguing it.

**The per-lead table cannot answer this, and using it would be the easy mistake.**
`summarise_run()`'s `lead_hit_df` groups every replicate by the Basic that led,
and it looks like exactly the right table. It is confounded: the hand that
contains a Mega Kangaskhan ex is not the hand that contains a Duskull, so the
table compares leads *across different hands* and reports a property of the hands
as though it were a property of the order. The lead is not randomised; it is
chosen, and it is chosen by the very rule under test. `lead_hit_df` remains
useful as a description of what the policy did, and is read as a fact about the
policy — never as the answer to DT-03.

**The experiment.** Vary the order, which is the thing the policy controls, and
measure the cell rate.

- **Common random numbers.** Every candidate order is evaluated on the same
  seeds, so a difference between two orders is a difference in play rather than a
  difference in shuffles.
- **Greedy positional search**, not a full permutation sweep. Six candidate names
  is 720 orders; filling rank 1 from six, then rank 2 from the remaining five,
  and so on is 20 evaluations for the same answer. This is valid here because only
  the top-ranked Basic *actually present in the hand* is ever used, so the order
  acts as a ranking rather than as a sequence with interactions.
- **Bronzor is pinned at rank 1 and Meowth ex is excluded.** Both are rulings in
  §3 — Bronzor satisfies sub-goal C outright at no cost, and leading Meowth ex
  wastes Last-Ditch Catch — and a search is not the place to overturn a ruling.
- **Out-of-sample confirmation.** A greedy search picks the maximum of twenty
  noisy numbers, which is precisely the procedure that reports a winner when
  there is none. The winner is therefore re-run against the incumbent on a
  **disjoint seed block**, and the order changes only if it wins there too.
- **Going first and going second are searched separately** (ADR 0002), and the
  `item_lock` cell — which the search never optimises — is reported alongside, so
  a gain paid for under the lock is visible rather than assumed.

**Considered and rejected:** (a) reading the order off `lead_hit_df`, for the
confounding above; (b) a full 720-order sweep, which costs 36× more for an answer
the greedy search reaches whenever the ranking is transitive; (c) asking Kevin
again in a different form — he had already answered, and the answer was to
measure it.

**Consequences.** §3's order is now empirical and will move again when the policy
moves: a lead is only as good as the plays the policy knows how to make from it.
Mega Kangaskhan ex sat at 40.9% until Run Errand was implemented and then reached
55.8%, on the same sixty cards — **a lead order measured with a card's Ability
switched off is measuring the policy, not the deck.** So the order is re-derived
after any change that alters what a turn can do, and `results/lead_order_tuning.md`
records the date and the policy it was measured under.
