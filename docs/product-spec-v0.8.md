# Product Spec v0.8 — First Five Minutes Release Polish

## Goal

v0.8 makes the first playable loop read like a shippable premium boxing game rather than a development shell.

The release-critical first-five-minutes path is:

> Title / New Career → first Camp → Fight Offer → Scouting → Game Plan → Weigh-in → Fight Night → Result

v0.8 does not add a new combat system, progression system, weight class, economy, or online feature. Existing v0.3–v0.7 career/combat authority remains intact; v0.8 is a presentation and flow-polish layer.

The authoritative runtime is Godot 4.7.2 stable. The primary visual verification viewport is 430×932 portrait.

## Launch contract

A fresh untouched career presents a product-facing title gate before Camp:

- TWELVE COUNT / Boxing Rebirth identity.
- one-fighter / one-career premise.
- commercial fighter portrait.
- premium/offline/no-ads positioning.
- a clearly visible `프로 커리어 시작` CTA at 430×932.

The launch acknowledgement is persisted so existing or already-started careers do not repeatedly enter the title gate.

## First camp contract

The first camp is framed as `PRO DEBUT · CAMP 01` and explains that one preparation choice leads into the debut contract stage.

Camp cards must expose player-facing Korean stat language rather than raw data keys:

- 파워
- 스피드
- 테크닉
- 수비
- 체력
- 피로
- 건강
- 체중
- 부상 기간

Raw keys such as `power`, `technique`, `fatigue`, or `weight` must not be shown as the primary camp-effect copy.

## Contract and scouting contract

Fight Offers are framed as a fight-week contract board. Opponent tiers/styles use product labels rather than raw IDs.

Examples:

- prospect → 프로스펙트
- regional → 지역 랭커
- swarmer → 인파이터
- out_boxer → 아웃복서
- slugger → 슬러거
- counter → 카운터 펀처

Opponent cards present portrait, rank, purse/career stakes, readable five-stat summary, and a single analysis CTA.

Scouting keeps the opponent dossier structure and uses the same localized style labels. Internal underscore-style IDs are not acceptable visible copy.

## Game Plan and Weigh-in contract

The Game Plan stage remains the existing one-fight tactical selection system. Text may describe boxing actions, but raw internal action IDs are not used as unexplained UI copy.

Selecting a game plan still uses the existing `GameState.select_game_plan()` authority. v0.8 adds a persisted presentation acknowledgement so the already-resolved weigh-in is shown as an explicit interstitial before Fight Night.

The Weigh-in screen must show:

- player and opponent portraits.
- official limit and current fight weight.
- pass / emergency-cut / miss verdict.
- applicable penalty explanation.
- locked game plan.
- a visible `FIGHT NIGHT 입장` CTA.

No second weigh-in simulation is added; v0.8 presents the result already produced by the existing career rules.

## Fight Night contract

Fight Night preserves v0.4–v0.7 combat, telegraph, hit-stop, shake, audio, haptic, safe-area, and commercial asset behavior.

At the first exchange:

- both fighters remain readable on the shared ring plane.
- telegraph/read copy remains visible.
- HP/STA gauges remain legible.
- raw style IDs are not exposed; the first swarmer opponent is presented as `인파이터`.
- jab contact and recovery remain visually connected.

Broadcast-language labels such as `ROUND`, `RING`, and `OPPONENT READ` are intentional presentation language and are not treated as raw implementation IDs.

## Result contract

The first result is a dedicated official-result presentation rather than a plain debug/stat dump.

It must show:

- localized official result (for example `판정승`).
- opponent.
- locked game plan and purse.
- career update: record, rank, career points, health/fatigue/weight.
- a visible `커리어 계속` CTA.

## Visual acceptance contract

At 430×932, the following nine actual Godot captures form the v0.8 release vertical slice:

1. Title
2. Camp
3. Fight Offers
4. Game Plan / Scouting
5. Weigh-in
6. Fight opening
7. Jab contact
8. Jab recovery
9. Result

Acceptance requires:

- no missing Korean glyphs.
- no horizontal overflow or essential right-edge clipping.
- primary CTA visible/readable in Title, Weigh-in, and Result.
- no raw underscore-style IDs or raw camp stat keys in the first-five-minutes flow.
- portraits remain correctly framed.
- Fight Night visual quality remains at least v0.7 quality.
- the overall flow no longer reads as an automatically booted development prototype.

## Verification boundary

Automated CI is necessary but insufficient. Approval additionally requires direct inspection of actual Godot 4.7.2 screenshots at 430×932.

The accepted visual evidence for the implementation state is release capture R3, produced from product head `88480c49a0a248286bf5b4b02078022d8a73fc04` plus capture-only files:

- workflow run `34153800561`
- artifact `twelve-count-v08-first-five-r3-visuals`
- artifact id `10030262582`
- 9/9 captures generated and directly inspected

Changes after that product head must be documentation-only for this visual evidence to remain valid.