# iOS Release Packaging v0.9

## Goal

Prepare Twelve Count for a paid iPhone 1.0 release without expanding gameplay scope.

Authoritative base entering this phase: `main@97d843f3b2b23495cbcb29cff072d147464f9758`.

## Locked product boundary

- iOS first
- iPhone native target only
- portrait orientation
- offline single-player
- paid upfront
- no advertisements
- no in-app purchases
- no subscriptions
- no login
- no multiplayer
- no server dependency

## Export contract

Repository authority: `export_presets.cfg`, preset `iOS Release`.

Required structural settings:

- Godot runtime/editor line: 4.7.2 stable
- architecture: arm64
- targeted device family: `0` (iPhone)
- minimum iOS: 15.0
- portrait viewport authority: 430×932
- export mode: Xcode project first (`application/export_project_only=true`)
- Wi-Fi capability: disabled
- Game Center: disabled
- push notifications: disabled
- Files app sharing: disabled
- iTunes file sharing: disabled
- camera/microphone/photo-library usage descriptions: blank because the product does not request those resources

The App Store Team ID and Bundle ID intentionally remain blank until the signing gate. Godot requires both values for a real iOS export, so a blank value must fail before an accidental unsigned/reused-identifier release.

## Repository CI gate

`python3 tools/validate_ios_release_v09.py`

This validates the packaging structure while allowing the account-specific signing fields and final binary art assets to remain HOLD.

Before a real device export, run:

`python3 tools/validate_ios_release_v09.py --require-signing`

That stricter gate must fail until all of these are present:

- 10-character Apple Team ID
- final Bundle ID
- final opaque 1024×1024 App Store icon path

## Binary asset gates

The following cannot be represented by documentation alone and remain mandatory before submission:

1. **Bundled Korean font**
   - Runtime must not depend solely on a system-font fallback for Korean text.
   - Final font license must allow redistribution in the app bundle.
   - Re-run the 430×932 first-five-minutes capture after the bundled font becomes authority.

2. **App icon**
   - Final 1024×1024 source must be opaque and contain no pre-rounded corners.
   - Smaller iPhone icon slots must be mapped from the approved source or supplied explicitly.
   - The icon must be inspected at actual small icon sizes, not only at 1024×1024.

3. **Store screenshots**
   - Use actual product renders, not mock gameplay.
   - Candidate content comes from the already accepted v0.8 flow: Title, Camp, Fight Offer, Scouting/Game Plan, Weigh-in, Fight Night, Result.
   - Final App Store sizes must be generated only after the release font/icon/UI authority is frozen.

## Metadata and privacy

Repository drafts:

- `docs/release/app-store-metadata-ko.md`
- `docs/release/privacy-policy-ko.md`

Current code search found no HTTPRequest, HTTPClient, WebSocket, multiplayer peer, TCP/UDP server, or shell-open integration. The privacy draft therefore describes the current product as offline and not developer-data-collecting. Any future analytics, ads, accounts, network services, or external SDKs invalidate that statement and require a privacy review before submission.

Before App Store submission:

- host the privacy policy on a public HTTPS URL
- provide a support URL with real contact information
- complete App Privacy answers in App Store Connect
- complete age rating and content-rights declarations

## macOS / Xcode gate

A real iOS export requires macOS, Xcode, and installed Godot iOS export templates.

Do not infer success from Linux/headless CI. The release must be exported and linked on macOS.

### Godot 4.7 template risk to verify

As of 2026-09-08, upstream Godot issue `#122549` remains open for an iOS linker failure involving `_SDL_IsIPad` and `_SDL_IsAppleTV` in 4.7/4.7.1 templates. The repository currently uses 4.7.2. The issue report does not establish 4.7.2 as affected or fixed, so the release gate is empirical:

1. install the official 4.7.2 iOS export templates
2. export the Xcode project
3. build an arm64 iPhone target
4. if those undefined symbols appear, stop and decide between an upstream-fixed template/custom template or a validated engine/template fallback before changing production authority

No workaround is considered accepted until it builds and runs on the target iPhone.

## Physical iPhone acceptance

Required before TestFlight:

- launch from a clean install
- Title → New Career works
- first-five-minutes flow completes
- safe areas are correct on the target iPhone
- no essential control is clipped
- portrait orientation stays locked
- suspend during Camp restores correctly
- suspend during Fight restores deterministically
- background/resume does not duplicate exchanges or lose save state
- haptics fire at intended impact profiles
- bell/crowd/hit audio route correctly
- 60 Hz and high-refresh presentation do not change combat outcomes
- force-close/relaunch retains the latest valid save

## TestFlight / submission acceptance

- Xcode archive succeeds
- archive validation succeeds
- build uploads to App Store Connect
- TestFlight build installs on physical iPhone
- smoke test passes from the uploaded build
- metadata, screenshots, privacy URL, support URL, price, age rating, and review contact are complete
- no account/demo credentials are required because the game has no login

## Current status

- v0.8 product flow: GO
- iOS export preset structure: GO after CI
- App Store metadata draft: GO
- privacy policy draft: GO
- Apple Team ID: HOLD
- Bundle ID: HOLD
- bundled Korean font: HOLD
- final app icon: HOLD
- App Store screenshot package: HOLD until font/icon authority freezes
- physical iPhone: NOT VERIFIED
- TestFlight: NOT VERIFIED
- App Store submission: NOT SUBMITTED
