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
- ETC2/ASTC texture import enabled for Apple embedded export
- export mode: Xcode project first (`application/export_project_only=true`)
- export path: `build/ios/TwelveCount.xcodeproj`
- Wi-Fi capability: disabled
- Game Center: disabled
- push notifications: disabled
- Files app sharing: disabled
- iTunes file sharing: disabled
- camera/microphone/photo-library usage descriptions: blank in the committed preset because the product does not request those resources

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

## Generated Xcode privacy sanitation

Godot 4.7.2's Apple embedded export template always emits the camera, microphone, and photo-library usage-description placeholders into the generated iOS `Info.plist`. With the corresponding preset values intentionally blank, Xcode reports that these usage descriptions must be non-empty even though Twelve Count does not use those protected resources.

Apple requires these purpose strings when an app accesses the associated protected resource. Twelve Count currently does not use camera, microphone, or photo-library APIs, so release packaging must omit the unused blank keys rather than invent a purpose string.

Repository authority:

`python3 tools/sanitize_ios_xcode_project_v09.py <generated-ios-root>`

The sanitizer:

- removes only blank `NSCameraUsageDescription`
- removes only blank `NSMicrophoneUsageDescription`
- removes only blank `NSPhotoLibraryUsageDescription`
- preserves any non-empty purpose string if a future product change intentionally adds one
- removes matching blank entries from generated `InfoPlist.strings`
- fails if any blank protected-resource usage value remains

The macOS native CI invokes this sanitizer immediately after Godot creates the Xcode project and rejects any recurrence of the blank-purpose-string warnings during Xcode build.

Any future camera, microphone, or photo-library feature invalidates the current privacy boundary and requires both a real purpose string and a privacy review before submission.

## Binary asset gates

The following remain mandatory before submission:

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

## macOS / Xcode native gate

Linux/headless QA is necessary but not sufficient. The repository also owns `.github/workflows/ios-export-link-v09.yml`, which performs a real Godot iOS project export and unsigned arm64 iPhone Release link on macOS.

### Empirical toolchain result — 2026-09-08

The release gate was exercised with the official Godot 4.7.2 macOS editor and official 4.7.2 export templates.

1. `macos-15`, Xcode 16.4 / iPhoneOS 18.5:
   - Godot Xcode project generation succeeded after enabling ETC2/ASTC import.
   - arm64 iPhone link failed on Apple SDK symbols including `_CADynamicRangeAutomatic` and `_MTLTensorDomain`.
   - the previously reported `_SDL_IsIPad` / `_SDL_IsAppleTV` signature was not the failure.

2. `macos-26`, Xcode 26.6 / iPhoneOS 26.5:
   - Godot 4.7.2 editor checksum verification succeeded.
   - official 4.7.2 export-template checksum verification succeeded.
   - `TwelveCount.xcodeproj` generation succeeded.
   - generated Xcode target/scheme `TwelveCount` was discovered successfully.
   - Release build used `arm64-apple-ios15.0` against the iPhoneOS 26.5 SDK.
   - unsigned arm64 iPhone link **BUILD SUCCEEDED**.
   - `_SDL_IsIPad`, `_SDL_IsAppleTV`, `_CADynamicRangeAutomatic`, and `_MTLTensorDomain` were not unresolved linker blockers.

Successful native evidence:

- workflow run: `34155384027`
- artifact: `10030815549` / `twelve-count-v09-ios-export-link-evidence`

Therefore the release toolchain authority for this Godot 4.7.2 line is **Xcode 26 or newer**. Do not validate a production archive with Xcode 16.x and interpret SDK-symbol linker failures as a Twelve Count game-code defect.

A final native run must additionally pass the generated privacy-key sanitizer introduced after the above evidence run.

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
- iOS export preset structure: GO
- Godot 4.7.2 → Xcode project generation: GO
- unsigned arm64 iPhone link on Xcode 26+: GO
- generated blank privacy purpose strings: remediation in exact-head native CI
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
