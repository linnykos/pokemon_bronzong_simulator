# 0006 — Decision traces are a small stratified sample, not every replicate

A run of 10,000 replicates per cell produces one number. That number ranks
decklists, but it cannot tell you whether a *decision* was wrong, and 10,000
traces would be unreadable by a person or an agent. So each run also writes a
small trace file — a configurable quota, default 150 misses and 50 hits — giving
a compact account of setup through the end of turn 2.

**The sample is stratified toward misses on purpose.** A uniform sample of a
decklist that hits 70% of the time would be mostly hits, and hits teach nothing
about what to change. Misses are the evidence.

**Considered and rejected:** (a) storing every trace — unusable at 10,000, and
the file would be read by nobody; (b) a uniform random subsample — representative
but mostly uninformative; (c) storing only misses — loses the ability to check
that hits happen for the intended reason rather than by luck.

**Consequences, and the trap this creates.** The trace file is deliberately
**not representative of the outcome distribution**, so no rate may ever be
computed from it. The written file therefore leads with the true aggregate rates
over every replicate, and carries an explicit warning, because the natural thing
for a reader — or an agent asked to "look at the traces" — to do is count them.

Each trace also carries two fields that exist specifically to separate a deck
problem from a decision problem:

- `blocking_subgoal` — which of the four sub-goals in
  `docs/03_decision_tree.md` §1 was unmet when the window closed.
- `unused_out_vec` — cards **still in hand** that could have advanced that
  sub-goal. A miss blocked on "Bronzong not Active" with a Switch sitting in
  hand is not a deck failure; it is a bug in the decision tree, and it should be
  fixed in `docs/03_decision_tree.md` rather than by changing the 60 cards.

Every replicate records its seed, so any trace can be replayed exactly.
