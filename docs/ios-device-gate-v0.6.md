# Twelve Count v0.6 — iOS Archive / Device Gate

## Current status

Repository CI proves code-level mobile readiness only. It does not prove a signed iOS build, device rendering, haptic feel, speaker mix, or App Store uploadability.

As of 2026-09-07, App Store Connect uploads must be built with Xcode 26 or later using the iOS/iPadOS 26 SDK or later.

Godot iOS export also requires a real 10-character Apple Team ID and a unique reverse-DNS bundle identifier. These values are intentionally not invented or committed here.

## Required local inputs

Provide on the release Mac:

```bash
export APPLE_TEAM_ID="<REAL_10_CHAR_TEAM_ID>"
export BUNDLE_ID="<UNIQUE_REVERSE_DNS_ID>"
```

Do not commit signing certificates, provisioning profiles, export credentials, or private keys.

## Toolchain gate

Required before archive:

```bash
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
```

Acceptance:

- Xcode >= 26
- iPhoneOS SDK >= 26
- Godot 4.7.2 stable
- matching Godot 4.7.2 export templates installed

## Godot export gate

On macOS in Godot:

1. Project -> Export -> Add -> iOS.
2. Set Application / App Store Team ID to `$APPLE_TEAM_ID`.
3. Set Application / Bundle Identifier to `$BUNDLE_ID`.
4. Export an Xcode project to a clean directory such as `build/ios/TwelveCount`.

A successful editor/headless Linux run is not a substitute for this export.

## Xcode archive gate

After Godot export, archive the generated project with the actual generated scheme name. Example shape:

```bash
xcodebuild \
  -project build/ios/TwelveCount/TwelveCount.xcodeproj \
  -scheme TwelveCount \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/ios/TwelveCount.xcarchive \
  archive
```

Acceptance:

- archive command exits 0
- no missing signing/provisioning error
- no missing framework/plugin error
- generated app uses the intended bundle identifier
- archive is inspectable in Xcode Organizer

## Physical-device smoke

Run at minimum on one notched/Dynamic-Island iPhone and one 120 Hz ProMotion device if available.

Verify:

- launch -> new/continued career works
- no interactive control enters unsafe screen areas
- every action button is easy to hit one-handed
- Jab/Power/Body/Guard/Counter remain responsive
- hit-stop feels intentional rather than laggy
- shake never moves controls enough to impair interaction
- body/head/block impact cues remain distinguishable on device speakers
- crowd/bell/corner layer does not mask impact feedback
- haptic intensity ordering is perceptible: medium < heavy < counter < knockdown
- 60 Hz and 120 Hz presentation timing feels equivalent
- background/suspend during camp persists state
- background/suspend during an active fight persists the pending telegraph/RNG state
- resume does not duplicate an exchange, reroll an opponent read, or reset the fight
- incoming call/control-center/app switch does not corrupt save state

## TestFlight gate

After signed archive succeeds:

- upload to App Store Connect/TestFlight
- install from TestFlight on physical hardware
- repeat first-five-minutes flow and one complete fight
- force-close/relaunch during fight and confirm deterministic resume

## Hard BLOCKED items until external evidence exists

The repository must continue to report these as open until real evidence is attached:

- signed Xcode archive
- physical iPhone safe-area screenshots
- physical haptic tuning notes
- 60/120 Hz device comparison
- iOS suspend/resume hardware result
- TestFlight install/run result
