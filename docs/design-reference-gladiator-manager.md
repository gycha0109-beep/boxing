# Design Reference — Gladiator Manager

Date: 2026-09-07
Status: Product reference, not a replication target

## Why it is relevant

Twelve Count and Gladiator Manager share a useful structural idea: the player should feel that a match was partly won or lost before the match started. Preparation, risk acceptance, fighter condition, opponent reading, and long-term consequences should matter as much as the immediate combat choice.

The reference is valuable because Twelve Count is not trying to compete with real-time 3D boxing games. It is a short-session sports career simulation where decisions create the drama.

## Principles we intentionally borrow at a high level

1. **Preparation must alter match outcomes.** Training and match preparation cannot be cosmetic stat screens.
2. **Opponents should force adaptation.** A single universal build or strategy is a balance failure.
3. **A fighter needs identity beyond numbers.** The player should remember what kind of boxer this career became.
4. **Bad outcomes should create a story.** A loss, injury, weight miss, or money problem should usually create a new decision rather than instantly invalidate the run.
5. **Long-term resources and short-term victory should conflict.** Winning tonight may damage health, money, or career longevity.
6. **Information should be contextual.** Show the data needed for the current decision instead of placing every career number on every screen.

## What Twelve Count must remain

Twelve Count is a **one-boxer career game**, not a roster-management game.

The player fantasy is:

> I am responsible for this boxer's career, style, risks, rivalries, wins, losses, decline, and retirement.

It is not:

> I own a stable of fighters and optimize a sports organization.

Therefore the following remain out of scope for the first commercial SKU:

- multiple active fighters under management
- buying/selling/recruiting a roster
- team salary management
- gym empire management
- staff organization charts
- fighter marketplace systems
- copying another game's UI, text, events, balance tables, names, artwork, or proprietary rules

## v0.3 translation into boxing

The reference is translated into boxing through three small systems only.

### Fighter Identity

Each new career begins with an archetype such as pressure fighter, out-boxer, slugger, or counter puncher. It gives small strengths and weaknesses and, more importantly, gives the career a readable personality.

Identity is not a permanent commandment. A slugger can still choose an outside-boxing game plan when the matchup demands it.

### Opponent Scouting

Every opponent exposes:

- strength
- weakness
- behavioral tell
- data-driven action tendencies
- two suggested plans

The recommendation is deliberately not guaranteed to be optimal. It is evidence that helps the player make a decision.

### Pre-fight Game Plan

After accepting a contract, the player chooses one of:

- Balanced
- Outside Boxing
- Body Breakdown
- Pressure
- Counter Trap

The plan changes the efficiency of specific actions during that bout. `Counter Trap`, for example, receives its meaningful bonus only when the opponent commits to Power or Body; it is not a universal counter buff.

Flow:

`Camp → Fight Offer → Scouting → Game Plan → Weigh-in → Fight → Result`

## Anti-copy rule

When a reference feature is considered, ask:

1. What player problem does this feature solve?
2. Can that problem be solved with boxing-native rules?
3. Does it reinforce the one-boxer career fantasy?
4. Is the implementation independently designed from our own data and combat model?

If the answer to 2–4 is no, do not implement it.

## Acceptance criterion

A successful version of this design should produce the statement:

> "I fought this opponent differently because I understood who he was and what kind of boxer I had become."

If players instead say:

> "I always pick the same plan and then press the same attacks,"

this system has failed regardless of how much content exists.
