#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${RUNNER_TEMP:-/tmp}/twelve-count-audio"
OUT="$ROOT/assets/audio"
MAP="$OUT/licenses/DERIVED_ASSET_MAP.tsv"
UA="TwelveCountAudioVendor/1.0 (+https://github.com/gycha0109-beep/boxing)"

rm -rf "$WORK"
mkdir -p "$WORK/src" "$WORK/extract/punch" "$WORK/extract/block" "$WORK/extract/swing" "$WORK/extract/voice"
mkdir -p \
  "$OUT/music/character_create" \
  "$OUT/music/camp" \
  "$OUT/music/fight_week" \
  "$OUT/music/fight_night" \
  "$OUT/sfx/punches" \
  "$OUT/sfx/blocks" \
  "$OUT/sfx/swings" \
  "$OUT/sfx/voice" \
  "$OUT/sfx/crowd" \
  "$OUT/sfx/bells" \
  "$OUT/licenses"

printf 'derived_file\tsource_key\toriginal_file\tmodification\n' > "$MAP"

fetch() {
  local url="$1" dest="$2"
  echo "Downloading $url"
  curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 20 \
    --user-agent "$UA" --output "$dest" "$url"
  test -s "$dest"
}

record_map() {
  local dest="$1" source_key="$2" original="$3" modification="$4"
  local rel="${dest#$ROOT/}"
  printf '%s\t%s\t%s\t%s\n' "$rel" "$source_key" "$original" "$modification" >> "$MAP"
}

ff() {
  ffmpeg -hide_banner -loglevel error -nostdin -y "$@"
}

# ---------------------------------------------------------------------------
# Originals — URLs are intentionally pinned in source control for provenance.
# ---------------------------------------------------------------------------
fetch "https://opengameart.org/sites/default/files/character_selection_in_game.ogg" "$WORK/src/character_selection_in_game.ogg"
fetch "https://opengameart.org/sites/default/files/Funked%20Up.mp3" "$WORK/src/Funked Up.mp3"
fetch "https://opengameart.org/sites/default/files/prepare_to_fight.mp3" "$WORK/src/prepare_to_fight.mp3"
fetch "https://opengameart.org/sites/default/files/boxing_ring_-_music.wav" "$WORK/src/boxing_ring_-_music.wav"
fetch "https://opengameart.org/sites/default/files/boxing_match_audience.wav" "$WORK/src/boxing_match_audience.wav"
fetch "https://opengameart.org/sites/default/files/boxing_matchbell.wav" "$WORK/src/boxing_matchbell.wav"
fetch "https://opengameart.org/sites/default/files/crowd_shouting_0.ogg" "$WORK/src/crowd_shouting.ogg"
fetch "https://opengameart.org/sites/default/files/cheers_1.ogg" "$WORK/src/cheers.ogg"
fetch "https://lpc.opengameart.org/sites/default/files/independent_nu_ljudbank-hits_and_punches.7z" "$WORK/src/hits_and_punches.7z"
fetch "https://opengameart.org/sites/default/files/impact_-_starninjas.zip" "$WORK/src/impact_starninjas.zip"
fetch "https://opengameart.org/sites/default/files/swishes.zip" "$WORK/src/swishes.zip"
fetch "https://opengameart.org/sites/default/files/painsounds.zip" "$WORK/src/painsounds.zip"
fetch "https://opengameart.org/sites/default/files/hurt_01_0.mp3" "$WORK/src/hurt_01.mp3"
fetch "https://opengameart.org/sites/default/files/hurt_02.mp3" "$WORK/src/hurt_02.mp3"
fetch "https://opengameart.org/sites/default/files/hurt_03.mp3" "$WORK/src/hurt_03.mp3"
fetch "https://opengameart.org/sites/default/files/hurt_04.mp3" "$WORK/src/hurt_04.mp3"
fetch "https://opengameart.org/sites/default/files/hurt_05.mp3" "$WORK/src/hurt_05.mp3"
fetch "https://opengameart.org/sites/default/files/hurt_06.mp3" "$WORK/src/hurt_06.mp3"

# ---------------------------------------------------------------------------
# Music — all tracks get conservative integrated loudness before runtime mix.
# ---------------------------------------------------------------------------
ff -i "$WORK/src/character_selection_in_game.ogg" -af "loudnorm=I=-23:TP=-2:LRA=10" -c:a libvorbis -q:a 5 "$OUT/music/character_create/character_create_theme.ogg"
record_map "$OUT/music/character_create/character_create_theme.ogg" "oga_character_selection" "character_selection_in_game.ogg" "OGG normalize -23 LUFS; runtime loop"

ff -i "$WORK/src/Funked Up.mp3" -af "loudnorm=I=-22:TP=-2:LRA=10" -c:a libvorbis -q:a 5 "$OUT/music/camp/camp_funked_up.ogg"
record_map "$OUT/music/camp/camp_funked_up.ogg" "oga_funked_up" "Funked Up.mp3" "MP3→OGG; normalize -22 LUFS"

ff -i "$WORK/src/prepare_to_fight.mp3" -af "loudnorm=I=-23:TP=-2:LRA=10" -c:a libvorbis -q:a 5 "$OUT/music/fight_week/fight_week_prepare.ogg"
record_map "$OUT/music/fight_week/fight_week_prepare.ogg" "oga_prepare_to_fight" "prepare_to_fight.mp3" "MP3→OGG; normalize -23 LUFS"

ff -i "$WORK/src/boxing_ring_-_music.wav" -af "loudnorm=I=-25:TP=-3:LRA=10" -c:a libvorbis -q:a 4 "$OUT/music/fight_night/fight_night_ring.ogg"
record_map "$OUT/music/fight_night/fight_night_ring.ogg" "oga_boxing_ring" "boxing_ring_-_music.wav" "WAV→OGG; normalize -25 LUFS; combat-bed priority"

# ---------------------------------------------------------------------------
# Arena ambience and real boxing bell.
# ---------------------------------------------------------------------------
ff -i "$WORK/src/boxing_match_audience.wav" -af "highpass=f=90,lowpass=f=9000,loudnorm=I=-27:TP=-4:LRA=12" -c:a libvorbis -q:a 3 "$OUT/sfx/crowd/crowd_ambience.ogg"
record_map "$OUT/sfx/crowd/crowd_ambience.ogg" "oga_boxing_ring" "boxing_match_audience.wav" "WAV→OGG; band-limit; normalize -27 LUFS"

ff -i "$WORK/src/boxing_matchbell.wav" -af "highpass=f=140,lowpass=f=10000,alimiter=limit=0.92" -ac 1 -ar 44100 -c:a pcm_s16le "$OUT/sfx/bells/round_bell.wav"
record_map "$OUT/sfx/bells/round_bell.wav" "oga_boxing_ring" "boxing_matchbell.wav" "mono 44.1k PCM; band-limit; limiter"

ff -i "$WORK/src/boxing_matchbell.wav" -f lavfi -t 0.20 -i "anullsrc=r=44100:cl=mono" -i "$WORK/src/boxing_matchbell.wav" \
  -filter_complex "[0:a]aformat=sample_rates=44100:channel_layouts=mono,highpass=f=140,lowpass=f=10000[a0];[1:a]aformat=sample_rates=44100:channel_layouts=mono[s];[2:a]aformat=sample_rates=44100:channel_layouts=mono,highpass=f=140,lowpass=f=10000[a1];[a0][s][a1]concat=n=3:v=0:a=1,alimiter=limit=0.92[out]" \
  -map "[out]" -c:a pcm_s16le "$OUT/sfx/bells/final_bell.wav"
record_map "$OUT/sfx/bells/final_bell.wav" "oga_boxing_ring" "boxing_matchbell.wav" "two-strike final-bell derivative; mono PCM"

# Distinct crowd reaction segments. These are event accents, not ambience loops.
for spec in \
  "reaction_small_01.ogg|0.0|1.15|-5|1.00" \
  "reaction_small_02.ogg|1.35|1.15|-5|0.97" \
  "reaction_big_hit_01.ogg|2.80|1.55|-2|1.00" \
  "reaction_big_hit_02.ogg|4.60|1.55|-2|1.03" \
  "reaction_knockdown_01.ogg|6.50|2.10|0|0.98" \
  "reaction_knockdown_02.ogg|8.90|2.10|0|1.02"; do
  IFS='|' read -r name start duration gain tempo <<< "$spec"
  ff -ss "$start" -t "$duration" -i "$WORK/src/crowd_shouting.ogg" \
    -af "atempo=$tempo,highpass=f=120,lowpass=f=9000,volume=${gain}dB,alimiter=limit=0.90" \
    -c:a libvorbis -q:a 4 "$OUT/sfx/crowd/$name"
  test -s "$OUT/sfx/crowd/$name"
  record_map "$OUT/sfx/crowd/$name" "oga_crowd_shouting" "crowd_shouting.ogg" "segment start=${start}s duration=${duration}s tempo=${tempo} gain=${gain}dB"
done

for spec in "reaction_win_01.ogg|0.97|-1" "reaction_win_02.ogg|1.03|-1"; do
  IFS='|' read -r name tempo gain <<< "$spec"
  ff -i "$WORK/src/cheers.ogg" -t 2.40 -af "atempo=$tempo,highpass=f=120,lowpass=f=9000,volume=${gain}dB,alimiter=limit=0.90" -c:a libvorbis -q:a 4 "$OUT/sfx/crowd/$name"
  record_map "$OUT/sfx/crowd/$name" "oga_cheers" "cheers.ogg" "trim <=2.4s tempo=${tempo} gain=${gain}dB"
done

# ---------------------------------------------------------------------------
# Punches — select distinct originals; category-specific EQ makes them read
# correctly on a phone speaker without synthesizing any transient.
# ---------------------------------------------------------------------------
7z x -y "$WORK/src/hits_and_punches.7z" "-o$WORK/extract/punch" >/dev/null
mapfile -d '' PUNCH_FILES < <(find "$WORK/extract/punch" -type f \( -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp3' \) -print0 | sort -z)
if (( ${#PUNCH_FILES[@]} < 16 )); then
  echo "Expected at least 16 distinct punch files, found ${#PUNCH_FILES[@]}" >&2
  exit 1
fi

punch_filter() {
  case "$1" in
    jab) echo "silenceremove=start_periods=1:start_duration=0.003:start_threshold=-42dB,highpass=f=120,lowpass=f=6500,equalizer=f=1800:t=q:w=1:g=2,volume=-1dB,alimiter=limit=0.92" ;;
    head) echo "silenceremove=start_periods=1:start_duration=0.003:start_threshold=-42dB,highpass=f=105,lowpass=f=7000,equalizer=f=2200:t=q:w=1:g=2.5,volume=1dB,alimiter=limit=0.94" ;;
    heavy) echo "silenceremove=start_periods=1:start_duration=0.003:start_threshold=-42dB,highpass=f=90,lowpass=f=7200,equalizer=f=190:t=q:w=1:g=3,equalizer=f=2600:t=q:w=1:g=3,volume=2dB,alimiter=limit=0.96" ;;
    counter) echo "silenceremove=start_periods=1:start_duration=0.003:start_threshold=-42dB,highpass=f=100,lowpass=f=7600,equalizer=f=3000:t=q:w=1:g=4,volume=2dB,alimiter=limit=0.96" ;;
    body) echo "silenceremove=start_periods=1:start_duration=0.003:start_threshold=-42dB,highpass=f=75,lowpass=f=4500,equalizer=f=170:t=q:w=1:g=4,volume=1dB,alimiter=limit=0.95" ;;
  esac
}

idx=0
for category_count in "jab:3" "head:4" "heavy:3" "counter:3" "body:3"; do
  category="${category_count%%:*}"
  count="${category_count##*:}"
  for ((n=1; n<=count; n++)); do
    src="${PUNCH_FILES[$idx]}"
    dest="$OUT/sfx/punches/${category}_$(printf '%02d' "$n").wav"
    ff -i "$src" -t 0.72 -af "$(punch_filter "$category")" -ac 1 -ar 44100 -c:a pcm_s16le "$dest"
    record_map "$dest" "oga_37_hits_punches" "$(basename "$src")" "trim <=0.72s; category=$category; mono 44.1k PCM; phone EQ/limiter"
    ((idx+=1))
  done
done

# ---------------------------------------------------------------------------
# Blocks — cardboard recordings, softened toward glove/forearm impacts.
# ---------------------------------------------------------------------------
unzip -q -o "$WORK/src/impact_starninjas.zip" -d "$WORK/extract/block"
mapfile -d '' BLOCK_FILES < <(find "$WORK/extract/block" -type f \( -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp3' \) -print0 | sort -z)
if (( ${#BLOCK_FILES[@]} < 5 )); then
  echo "Expected at least 5 block files, found ${#BLOCK_FILES[@]}" >&2
  exit 1
fi
for ((n=1; n<=5; n++)); do
  src="${BLOCK_FILES[$((n-1))]}"
  dest="$OUT/sfx/blocks/block_$(printf '%02d' "$n").wav"
  ff -i "$src" -t 0.50 -af "silenceremove=start_periods=1:start_duration=0.003:start_threshold=-42dB,highpass=f=100,lowpass=f=3300,equalizer=f=220:t=q:w=1:g=2,equalizer=f=2200:t=q:w=1:g=-3,volume=-1dB,alimiter=limit=0.90" -ac 1 -ar 44100 -c:a pcm_s16le "$dest"
  record_map "$dest" "oga_impact_blocks" "$(basename "$src")" "trim <=0.50s; mono 44.1k PCM; metallic-top suppression; glove-body EQ"
done

# ---------------------------------------------------------------------------
# Miss swings — use distinct recorded swishes, attenuated below contact SFX.
# ---------------------------------------------------------------------------
unzip -q -o "$WORK/src/swishes.zip" -d "$WORK/extract/swing"
mapfile -d '' SWING_FILES < <(find "$WORK/extract/swing" -type f \( -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp3' \) -print0 | sort -z)
if (( ${#SWING_FILES[@]} < 3 )); then
  echo "Expected at least 3 swish files, found ${#SWING_FILES[@]}" >&2
  exit 1
fi
for ((n=1; n<=3; n++)); do
  src="${SWING_FILES[$((n-1))]}"
  dest="$OUT/sfx/swings/swing_$(printf '%02d' "$n").wav"
  ff -i "$src" -t 0.46 -af "silenceremove=start_periods=1:start_duration=0.003:start_threshold=-45dB,highpass=f=180,lowpass=f=8500,volume=-6dB,alimiter=limit=0.82" -ac 1 -ar 44100 -c:a pcm_s16le "$dest"
  record_map "$dest" "oga_swishes" "$(basename "$src")" "trim <=0.46s; mono 44.1k PCM; -6dB event attenuation"
done

# ---------------------------------------------------------------------------
# Voice — prefer short clips so punches sound like boxing, not RPG deaths.
# ---------------------------------------------------------------------------
unzip -q -o "$WORK/src/painsounds.zip" -d "$WORK/extract/voice"
for n in 01 02 03 04 05 06; do
  cp "$WORK/src/hurt_${n}.mp3" "$WORK/extract/voice/ez_hurt_${n}.mp3"
done

VOICE_LIST="$WORK/voice_duration.tsv"
: > "$VOICE_LIST"
while IFS= read -r -d '' src; do
  duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$src" 2>/dev/null || true)"
  if [[ -n "$duration" ]]; then
    printf '%012.6f\t%s\n' "$duration" "$src" >> "$VOICE_LIST"
  fi
done < <(find "$WORK/extract/voice" -type f \( -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp3' \) -print0)
mapfile -t VOICE_FILES < <(sort -n "$VOICE_LIST" | cut -f2-)
if (( ${#VOICE_FILES[@]} < 11 )); then
  echo "Expected at least 11 distinct voice clips, found ${#VOICE_FILES[@]}" >&2
  exit 1
fi

voice_idx=0
for category_count in "light:4" "heavy:3" "body:2" "knockdown:2"; do
  category="${category_count%%:*}"
  count="${category_count##*:}"
  for ((n=1; n<=count; n++)); do
    src="${VOICE_FILES[$voice_idx]}"
    dest="$OUT/sfx/voice/${category}_$(printf '%02d' "$n").ogg"
    gain="-7"
    [[ "$category" == "heavy" ]] && gain="-5"
    [[ "$category" == "body" ]] && gain="-5"
    [[ "$category" == "knockdown" ]] && gain="-4"
    ff -i "$src" -t 1.15 -af "silenceremove=start_periods=1:start_duration=0.005:start_threshold=-42dB,highpass=f=90,lowpass=f=8500,volume=${gain}dB,alimiter=limit=0.88" -ac 1 -ar 44100 -c:a libvorbis -q:a 4 "$dest"
    source_key="oga_pain_emopreben"
    [[ "$(basename "$src")" == ez_hurt_* ]] && source_key="oga_hurt_ezduzziteh"
    record_map "$dest" "$source_key" "$(basename "$src")" "shortest-clip selection; trim <=1.15s; mono OGG; gain=${gain}dB"
    ((voice_idx+=1))
  done
done

# Remove stale Godot import metadata if the script is rerun on a checked-out tree.
find "$OUT" -name '*.import' -delete

# Final deterministic inventory guards.
[[ $(find "$OUT/sfx/punches" -maxdepth 1 -name '*.wav' | wc -l) -eq 16 ]]
[[ $(find "$OUT/sfx/blocks" -maxdepth 1 -name '*.wav' | wc -l) -eq 5 ]]
[[ $(find "$OUT/sfx/swings" -maxdepth 1 -name '*.wav' | wc -l) -eq 3 ]]
[[ $(find "$OUT/sfx/voice" -maxdepth 1 -name '*.ogg' | wc -l) -eq 11 ]]
[[ $(find "$OUT/sfx/crowd" -maxdepth 1 -name 'reaction_*.ogg' | wc -l) -eq 8 ]]

find "$OUT" -type f -size 0 -print -quit | grep -q . && {
  echo "Zero-byte audio asset found" >&2
  exit 1
} || true

echo "Commercial CC0 audio inventory created:"
find "$OUT" -type f | sort
