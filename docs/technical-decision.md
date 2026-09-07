# Technical Decision Record — 2026-09-07

## Decision

Use **Godot 4.7.2 stable + GDScript** for the first commercial SKU.

## Why

| Criterion | Godot 4.7.2 | Unity 6.3 LTS | Flutter 3.47 + Flame | React Native 0.87 | Swift / SpriteKit |
|---|---|---|---|---|---|
| 2D game loop | Excellent | Excellent | Good | Requires extra game layer | Excellent |
| UI iteration | Good | Good | Excellent | Excellent | Excellent |
| iOS export | Official Xcode export | Mature | Mature | Mature | Native |
| Small offline SKU overhead | Low | Higher | Low | Medium | Low |
| Android reuse | Strong | Strong | Strong | Strong | Weak |
| License/runtime fee risk | MIT | Proprietary terms | BSD ecosystem | MIT ecosystem | Apple platform |
| AI-agent editability | High for GDScript/text scenes/data | Good but larger project surface | High | High | High |

Godot minimizes production surface while still being a real game engine. It keeps 2D animation, audio, input, save files, scene/state flow, and future Android reuse in one stack. C# is deliberately avoided because Godot's iOS C# path remains more constrained/experimental than GDScript.

## Current external requirements checked

- Godot 4.7.2 is the current stable Godot release as of 2026-09-07.
- iOS export requires macOS with Xcode; Godot exports an Xcode project.
- Since 2026-04-28, App Store Connect requires uploads built with Xcode 26 or later and the iOS/iPadOS 26 SDK or later.
- Privacy manifests and Required Reason API declarations must be reviewed before submission; adding third-party SDKs increases this compliance surface.
- Final age rating is determined by the current App Store questionnaire. Boxing violence must be answered accurately; do not hard-code a rating assumption now.

## Architecture boundaries

- `scripts/core`: deterministic game rules and state transitions
- `data`: balance/content JSON editable without code changes
- `scenes`: presentation and interaction only
- `tools`: external simulation/data validation
- no backend and no runtime network dependency

Game Factory reuse is intentionally limited to obvious boundaries (data-driven opponents, actions, events, save envelope). Do not build a generic multi-sport engine before this SKU proves itself.

## Production gate still outstanding

This execution environment has no Godot binary or Xcode, so the source has not yet passed an actual Godot parser/runtime launch or an iOS export. Those are required before the technical choice becomes a production-verified release baseline.
