# Product Spec v0.4 — Combat UX + Telegraph

Date: 2026-09-07
Branch: `feat/combat-ux-telegraph-v0.4`

## Objective

Turn the tactical combat layer from a text-heavy calculation screen into a readable decision loop:

`Observe opponent → infer intent → choose action → see why it worked or failed → choose again`

v0.3 made the opponent matter before the bell. v0.4 makes the opponent's tendencies matter during each exchange without changing the game into a reflex-action boxer.

## Product promise

> The player should be able to explain why they chose Jab, Power, Body, Guard, or Counter before seeing the result.

The game remains a choice-driven tactical sim. Telegraph information informs a decision; it does not replace the decision.

## Implemented fight presentation

The fight screen now renders:

- round and exchange position
- player/opponent name card
- HP and stamina gauges
- selected game plan
- weigh-in status
- latest exchange feedback
- round summary when a round closes
- current opponent-read card
- opponent body/stamina condition
- five action buttons in a compact grid
- game-plan emphasis on actions modified by the selected plan

Internal P/S/T/D/C values are intentionally de-emphasized during the fight. The immediate decision should depend on combat state and observed cues rather than raw spreadsheet inspection.

## Telegraph semantics

Before every player action, the combat engine locks one opponent action and exposes a broad visual/read cue derived from that action:

- Jab → lead-hand movement
- Power → committed shoulder/weight load
- Body → level change
- Guard → defensive shell
- Counter → waiting/reactive posture

The displayed read contains a confidence value. It is decision support, not a guaranteed literal action label in the intended final presentation.

### Critical save invariant

Once the player has seen a telegraph, the opponent action is already locked.

`pending_opponent_action` and `pending_telegraph` are persisted inside the active-fight save. Force-closing after seeing a cue must not allow the player to reopen the game and reroll the opponent's intent.

## Structured exchange result

`CombatEngine.resolve_exchange()` now emits a structured `exchange_result` in addition to the normal combat snapshot. Presentation code must consume this result rather than re-running combat calculations.

The result contains:

- player/opponent action
- initiative order
- telegraph used for that exchange
- per-actor event details
- hit/miss/guard
- damage
- stamina cost and body stamina damage
- matchup identifier
- Counter Trap read success/failure
- knockout flag
- HP/stamina deltas
- body-state labels
- round-end flag and round card
- final fight result when applicable

This keeps deterministic combat authority inside `CombatEngine` and presentation semantics inside `CombatPresentation`.

## Counter feedback

Counter Trap has two explicit presentation outcomes:

### Read success

A reactive Counter against committed Power/Body is marked as a successful read. If it lands, the presentation can show `COUNTER!` and explain that the committed attack was correctly read.

### Read failure

Using Counter Trap against a non-committed action is marked `READ FAILED`. The presentation explains that the player waited for a large attack that did not come and that the plan's miss-read penalty applied.

The player should never need to infer this from hidden modifiers.

## Body feedback

Body attacks already reduce stamina in the combat model. v0.4 exposes that effect directly.

Opponent body state is derived from current stamina:

- Stable: >65
- Strained: 41–65
- Hurt: 21–40
- Critical: ≤20

Presentation labels translate these into readable conditions such as breathing instability, accumulated body damage, and near-exhaustion.

## Round summary

At the end of each three-exchange round the UI exposes the round card and a short corner note. The corner note is explanatory feedback, not a hidden combat modifier.

## Determinism and resume

v0.4 preserves the existing lossless RNG-state resume guarantee and extends it to the pre-action read state.

Automated runtime coverage proves that:

1. preparing a telegraph locks an opponent action once
2. rendering it again does not consume additional RNG
3. JSON save/load preserves the locked action and semantic telegraph fields
4. resolving after restore consumes the same action
5. structured exchange feedback survives in the active-fight save

## Automated QA gates

v0.4 cannot merge unless all of the following pass on the exact head:

1. existing data/game-plan/project/career checks
2. opponent ladder simulation
3. game-plan matchup simulation
4. 10,000-career simulation
5. verified Godot 4.7.2 parse/import
6. headless main-scene boot
7. save/backup/v1 migration/RNG resume fixture
8. v0.3 identity/scouting/game-plan fixture
9. v0.4 telegraph/structured-result/presentation fixture
10. v0.4 fight-phase UI fixture that instantiates the real Main scene, verifies the gauges/read/action controls, consumes a rendered locked action, and verifies the saved structured result

## Exact-head evidence before documentation update

Run `34095864816` on head `40f3b44df6e594d577d37a0ffb6335335aecdef6` passed both jobs, including the real fight-phase UI smoke.

The deterministic career evidence on that head remained:

- 10,000 careers
- champion rate: 22.5%
- average fights: 28.90
- average wins: 11.55
- average final money: ₩3,581,436
- injured-fight share: 9.0%
- career simulation: PASS

This evidence becomes historical when the head changes; final merge authority must use the later exact-head and merged-main CI runs.

## Explicitly not verified by v0.4 headless QA

- physical iPhone/iPad rendering
- safe-area behavior on real devices
- touch ergonomics
- frame pacing on device
- actual punch animation assets
- SFX mix
- haptic feel
- screen shake/impact polish
- iOS suspend/resume behavior
- Xcode/iOS export and App Store archive

Headless UI execution proves the scene and interaction path execute; it does not prove that the screen is commercially polished on a physical device.

## Deferred scope

Do not expand v0.4 into:

- real-time movement
- joystick controls
- 3D boxing
- deep animation systems
- new weight classes
- more fighters solely for quantity
- equipment inventory
- gym/roster management

The next visual slice should improve perception and impact on top of this deterministic presentation contract, not replace the combat model.
