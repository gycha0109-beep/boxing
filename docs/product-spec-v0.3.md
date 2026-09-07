# Product Spec v0.3 — Fighter Identity + Matchup Adaptation

Date: 2026-09-07
Branch: `feat/fighter-identity-gameplan-v0.3`

## Objective

Make the opponent matter before the first bell.

v0.2 proved that a complete career can run from camp to retirement. v0.3 adds only the smallest systems required to make two careers and two opponents feel strategically different.

## Product promise

> One boxer. One career. Opponents force you to adapt how that boxer fights.

## New loop

`Camp → Fight Offer → Scouting → Game Plan → Weigh-in → Tactical Fight → Result → Event → Next Camp`

The important change is that accepting a fight no longer jumps directly to the weigh-in/fight. The player first gets information and commits to a bout-specific plan.

## Fighter Identity

New careers roll one of four meaningful identities plus a balanced compatibility fallback:

- Pressure Fighter
- Out-boxer
- Slugger
- Counter Puncher
- Balanced (migration/fallback)

Identity gives small stat deltas and a one-line signature. It should shape preference, not hard-lock decisions.

### Requirement

No identity bonus may be so large that changing game plan becomes irrational.

## Opponent Scouting

All 12 current opponents contain data-driven action tendencies that sum to 100%, plus:

- strength
- weakness
- tell
- suggested plans

The combat AI reads the tendency data directly. The UI reports the same data, so scouting text and runtime behavior originate from one source of truth.

## Game Plans

### Balanced

No special modification. Baseline option.

### Outside Boxing

Bias toward jab, speed, accuracy, and safer exchanges while sacrificing some power.

### Body Breakdown

Bias toward body work and conditioning pressure to damage an opponent's later exchanges.

### Pressure

Bias toward power/body offense at the cost of defense and conditioning margin.

### Counter Trap

Conditional plan. The meaningful counter bonus activates only when the opponent commits to Power or Body. This prevents the plan from becoming a universal accuracy/damage upgrade.

## Combat relationship

Game plan does not autoplay the bout.

The player still chooses every exchange from:

- Jab
- Power
- Body
- Guard
- Counter

The plan changes the efficiency/risk of those choices. This preserves the distinction between **pre-fight strategy** and **in-fight tactics**.

## Save compatibility

The save envelope remains schema v2 because the new fields are additive payload fields:

- boxer identity metadata
- `selected_game_plan`

Old v0.2 saves normalize to:

- identity: Balanced without retroactive stat changes
- an already-active fight: Balanced game plan

No existing career should be invalidated solely by upgrading to v0.3.

## QA gates

v0.3 cannot merge unless all of the following pass on the exact head:

1. JSON/data validation
2. project architecture sanity
3. legacy career invariants
4. opponent ladder simulation
5. plan-vs-matchup simulation
6. 10,000-career simulation
7. verified Godot 4.7.2 project parse/import with script-error log gate
8. headless main-scene boot
9. save/backup/v1 migration/RNG resume runtime fixture
10. fighter identity/scouting/game-plan runtime fixture

## Balance anti-patterns

Immediate FAIL conditions:

- one game plan is best against every representative opponent style
- plan spread is so small that the choice is cosmetic
- a scouting recommendation is consistently misleading
- an identity is so strong that matchup adaptation becomes unnecessary
- player loses meaningful in-fight agency because the plan effectively autoplays the bout

## Explicitly deferred

- multiple fighter roster
- gym management
- equipment inventory
- coaches as a deep staff system
- rival story chains
- more identities/plans for quantity's sake
- additional weight classes

Those are not allowed to distract from proving that the new matchup choice is actually fun.
