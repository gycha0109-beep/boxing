# Twelve Count — Commercial Audio Sources

Verified and integrated for commercial redistribution in the game on **2026-09-09**.

## Policy

Only source material whose original page explicitly offers **CC0 / public-domain dedication** is accepted in this audio pass. The game may redistribute and modify CC0 material without attribution; source credits are still retained here for release provenance. No YouTube rips, unknown mirrors, Mixkit music, non-commercial material, or "royalty free" assets with unclear game-embedding rights are used.

The checked-in files are normalized/trimmed derivatives created by `tools/vendor_audio_assets.sh`. Exact derived-file → original-file mappings are written to `DERIVED_ASSET_MAP.tsv` by that script.

## Music

### `assets/audio/music/character_create/character_create_theme.ogg`
- Source: OpenGameArt — **Character Selection Theme Loop**
- Author: beardalaxy
- Original page: https://opengameart.org/node/165328
- Original file: `character_selection_in_game.ogg`
- Download URL: https://opengameart.org/sites/default/files/character_selection_in_game.ogg
- License: **CC0 1.0**
- Source-page note: credit appreciated but not necessary.
- Usage: career start, boxing-style selection, natural-talent reveal.
- Modification: copied as OGG; runtime loop flag is enabled in Godot.

### `assets/audio/music/camp/camp_funked_up.ogg`
- Source: OpenGameArt — **Funked Up**
- Author: Joth
- Original page: https://opengameart.org/content/funked-up
- Original file: `Funked Up.mp3`
- Download URL: https://opengameart.org/sites/default/files/Funked%20Up.mp3
- License: **CC0 1.0**
- Source-page note: attribution appreciated but not required; source describes the track as a groovy loop suitable for customization/garage contexts.
- Usage: camp, training week, equipment/gym investment, ordinary career progression.
- Modification: transcoded to OGG/Vorbis; conservative loudness normalization for mobile playback.

### `assets/audio/music/fight_week/fight_week_prepare.ogg`
- Source: OpenGameArt — **Prepare to fight**
- Author: Basil
- Original page: https://opengameart.org/content/prepare-to-fight
- Original file: `prepare_to_fight.mp3`
- Download URL: https://opengameart.org/sites/default/files/prepare_to_fight.mp3
- License: **CC0 1.0**
- Usage: fight offer, scouting, tactical prep, game plan, weigh-in.
- Modification: transcoded to OGG/Vorbis and normalized below combat-SFX level.

### `assets/audio/music/fight_night/fight_night_ring.ogg`
- Source: OpenGameArt — **Boxing Ring**
- Author: Umplix
- Original page: https://opengameart.org/content/boxing-ring-0
- Original file: `boxing_ring_-_music.wav`
- Download URL: https://opengameart.org/sites/default/files/boxing_ring_-_music.wav
- License: **CC0 1.0**
- Source-page note: credit not required; the separated music version is supplied by the author.
- Usage: fight-night entrance / low-level arena bed. During exchanges it is deliberately mixed behind punches, bell, and crowd.
- Modification: transcoded to OGG/Vorbis and loudness-reduced. The source page warns that the piece is not an ideal seamless loop, so runtime does not rely on aggressive looping during short fights.

## Punch impacts

### `assets/audio/sfx/punches/*.wav`
- Source: Liberated Pixel Cup / OpenGameArt — **37 hits/punches**
- Original author: Independent.nu; submitted by qubodup
- Original page: https://lpc.opengameart.org/content/37-hitspunches
- Original archive: `independent_nu_ljudbank-hits_and_punches.7z`
- Download URL: https://lpc.opengameart.org/sites/default/files/independent_nu_ljudbank-hits_and_punches.7z
- License: **CC0 1.0**
- Usage pools: jab ×3, normal head ×4, heavy head ×3, counter crack ×3, body ×3.
- Modification: leading silence removed; short transient trim; mono 44.1 kHz PCM; phone-oriented high-pass/low-pass/EQ/limiter treatment. Heavy/counter/body categories receive different EQ rather than a single repeated sample.
- Per-file original mapping: see `DERIVED_ASSET_MAP.tsv`.

## Guard / block

### `assets/audio/sfx/blocks/*.wav`
- Source: OpenGameArt — **10 Impact/Shield Blocks**
- Author: StarNinjas
- Original page: https://opengameart.org/content/10-impactshield-blocks
- Original archive: `impact_-_starninjas.zip`
- Download URL: https://opengameart.org/sites/default/files/impact_-_starninjas.zip
- License: **CC0 1.0**
- Source-production note: the author states these impacts were made by hitting cardboard, not by recording metal shields.
- Usage: glove/forearm guard impacts.
- Modification: trimmed, mono-converted, low-pass/EQ treatment to suppress hard/metallic top-end and bias the result toward glove/arm impact.
- Per-file original mapping: see `DERIVED_ASSET_MAP.tsv`.

## Miss / air swing

### `assets/audio/sfx/swings/*.wav`
- Source: OpenGameArt — **Swishes Sound Pack**
- Author: artisticdude
- Original page: https://opengameart.org/content/swishes-sound-pack
- Original archive: `swishes.zip`
- Download URL: https://opengameart.org/sites/default/files/swishes.zip
- License: **CC0 1.0**
- Source-production note: 13 recorded swishes, including four lighter variants.
- Usage: missed jab/punch air movement.
- Modification: light variants are preferred, shortened and attenuated so a miss never competes with a landed punch.
- Per-file original mapping: see `DERIVED_ASSET_MAP.tsv`.

## Voice / pain

### `assets/audio/sfx/voice/*.ogg`
- Primary source: OpenGameArt — **Pain sounds by EmoPreben**
- Author: EmoPreben / Lasse Bührmann
- Original page: https://opengameart.org/content/pain-sounds-by-emopreben
- Original archive: `painsounds.zip`
- Download URL: https://opengameart.org/sites/default/files/painsounds.zip
- License: **CC0 1.0**
- Source-page note: explicitly described as public-domain pain sounds usable for whatever; attribution is not required.

Supplemental source, used only when needed to provide enough distinct short variations:
- Source: OpenGameArt — **Hurt Sound Effects**
- Author: EZduzziteh
- Original page: https://opengameart.org/content/hurt-sound-effects
- Files: `hurt_01.mp3` … `hurt_06.mp3`
- Download URLs are recorded in `tools/vendor_audio_assets.sh`.
- License: **CC0 1.0**

Usage pools: light grunt ×4, heavy grunt ×3, body pain ×2, knockdown grunt ×2. Voice playback is probabilistic and is not emitted on every landed hit.
- Modification: shortest usable vocal clips are preferred, trimmed, mono-converted and normalized below punch transient level.
- Per-file original mapping: see `DERIVED_ASSET_MAP.tsv`.

## Arena ambience / reactions / bell

### `assets/audio/sfx/crowd/crowd_ambience.ogg`
- Source: OpenGameArt — **Boxing Ring**
- Author: Umplix
- Original page: https://opengameart.org/content/boxing-ring-0
- Original file: `boxing_match_audience.wav`
- Download URL: https://opengameart.org/sites/default/files/boxing_match_audience.wav
- License: **CC0 1.0**
- Usage: continuous low-level arena crowd.
- Modification: transcoded to OGG/Vorbis and reduced for phone-speaker mix headroom.

### `assets/audio/sfx/bells/round_bell.wav`, `final_bell.wav`
- Source: OpenGameArt — **Boxing Ring**
- Author: Umplix
- Original page: https://opengameart.org/content/boxing-ring-0
- Original file: `boxing_matchbell.wav`
- Download URL: https://opengameart.org/sites/default/files/boxing_matchbell.wav
- License: **CC0 1.0**
- Usage: round start/end and final bell.
- Modification: round bell is normalized/trimmed; final bell is a deliberate multi-strike derivative of the same real boxing bell recording.

### `assets/audio/sfx/crowd/reaction_*.ogg`
- Source A: OpenGameArt — **Crowd Shouting/Speaking Ambience**
- Author: StarNinjas
- Original page: https://opengameart.org/content/crowd-shoutingspeaking-ambience
- Original file: `crowd_shouting.ogg`
- Download URL: https://opengameart.org/sites/default/files/crowd_shouting_0.ogg
- License: **CC0 1.0**
- Source B: OpenGameArt — **Cheers**
- Author: Nocturnal_Vanguard / AuraVoice
- Original page: https://opengameart.org/content/cheers-0
- Original file: `cheers.ogg`
- Download URL: https://opengameart.org/sites/default/files/cheers_1.ogg
- License: **CC0 1.0**
- Usage: small hit reaction, big-hit reaction, knockdown roar, win cheer.
- Modification: distinct temporal segments and mild pitch/loudness variants are exported so the same full recording is not replayed identically for every event.

## Excluded after review

- Mixkit music: excluded from this game pass.
- Freesound `PUNCH-BOXING-01/02/03/04` by newagesoup and `Crowd Cheer` by FoolBoyMedia: their pages were verified as CC0, but automated original-file acquisition requires a Freesound account/session. They are **not** silently mirrored or ripped; the integration uses directly downloadable CC0 OpenGameArt sources instead.
- `grunts of male death and pain`: excluded from this pass despite the page currently displaying CC0 because historical comments create avoidable licensing ambiguity and the vocal tone is more death/RPG-oriented than this boxing mix needs.

## Release provenance

- Verification date: 2026-09-09
- Integration branch: `feat/legacy-state-foundation-v1.2`
- PR: #13 (Draft / HOLD; audio work does not authorize merge)
- Acquisition/transformation authority: `tools/vendor_audio_assets.sh`
