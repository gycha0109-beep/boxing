# Product Spec v0.2 — Full Career Spine

Date: 2026-09-07
Codename: Twelve Count

## Scope decision

v0.2 expands the vertical slice only far enough to prove that a complete boxer career can create repeated trade-offs. It deliberately does **not** expand to release-volume content, art production, equipment inventory, multiple weight classes, achievements, online services, or metagame power grinding.

## Career loop

Camp choice → fight offers → weigh-in → tactical fight → purse/ranking/health/injury outcome → post-fight event → recovery → next camp → retirement/title ending.

A single camp action is allowed per cycle. The player therefore cannot simultaneously maximize growth, recovery, and weight control.

## Persistent pressures

### Trainable boxing stats

- Power
- Speed
- Technique
- Defense
- Conditioning

### Career state

- Age in months
- Fatigue
- Health
- Weight
- Current injury
- Money
- Reputation
- Career points / tier / displayed rank
- Record

## Weight system

The first class is a fictionalized lightweight progression using a 61.2 kg limit.

- At/below limit: pass
- Small miss: emergency cut; player makes weight but takes health/fatigue cost
- Larger miss: fight proceeds to avoid a progression dead-end, but reputation and purse are reduced

This is a game abstraction, not a simulation of any specific sanctioning body's rules.

## Injury system

Only one active injury is tracked in v0.2. It has a remaining-camp duration and direct stat penalties. Training risk, high fatigue, and KO losses increase injury probability. Rehab can shorten the duration at a meaningful cash/opportunity cost.

Initial injury set:

- Hand soreness
- Rib bruise
- Eye cut
- Shoulder strain

## Traits

Six starting traits modify raw stats or system multipliers without creating permanent metagame power creep:

- Iron Chin
- Glass Cannon
- Workhorse
- Technician
- Crowd Favorite
- Quick Healer

## Ranking progression

Career points create six tiers:

Prospect → Regional → National → Continental → World → Title.

Fight offers are constrained to nearby tiers. A lower-tier fight can provide safety, a peer fight provides efficient progression, and a higher-tier fight provides an upset route. Title opponents do not appear until the boxer is within reach of the title tier.

## Economy

Displayed contract purses are gross. A data-driven net-purse multiplier represents manager/trainer/tax leakage and every tier has a recurring fight-cycle cost. This was added because simulation showed the original economy made money meaningless after a few wins.

Money should affect whether the player can choose expensive sparring/rehab without turning the game into a poverty simulator.

## Fight persistence

The fight seed and complete active combat snapshot are saved after each exchange. Force-closing during a fight must resume the same bout state rather than granting a free restart.

## End states

Implemented:

- World champion
- Health retirement
- Loss retirement
- Bankruptcy
- Age retirement
- Maximum-fight retirement

Not every ending needs equal frequency. Simulation is used to detect effectively unreachable endings and progression locks before content expansion.

## Content included in v0.2

- 12 opponents across all tiers
- 4 styles
- 8 camp actions
- 6 traits
- 8 events
- 4 injuries
- 5 combat actions
- 6 career tiers

This is **system-proof content**, not launch content.
