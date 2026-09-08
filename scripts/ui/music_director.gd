class_name MusicDirector
extends Node

const MIX_RATE: float = 22050.0
const VALID_MODES: Array[String] = ["silent", "menu", "career", "fight_week", "fight", "legacy"]
const MUSIC_VOLUME_DB: float = -19.0
const UI_VOLUME_DB: float = -13.0
const MUSIC_ASSETS := {
    "menu": "res://assets/audio/music/character_create/character_create_theme.ogg",
    "career": "res://assets/audio/music/camp/camp_funked_up.ogg",
    "fight_week": "res://assets/audio/music/fight_week/fight_week_prepare.ogg",
    "fight": "res://assets/audio/music/fight_night/fight_night_ring.ogg",
    # The commercial pack currently has four themes. Reuse the subdued
    # character theme for Legacy instead of synthesizing a fifth placeholder.
    "legacy": "res://assets/audio/music/character_create/character_create_theme.ogg",
}

var current_mode: String = "silent"
var last_ui_cue: String = ""
var mode_switch_count: int = 0
var ui_cue_count: int = 0
var sample_cursor: int = 0
var current_gain: float = 0.0
var duck_gain: float = 1.0
var suspended: bool = false
var last_music_asset_path: String = ""

var music_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer
var ui_generator: AudioStreamGenerator
var ui_playback: AudioStreamGeneratorPlayback
var ui_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    ui_rng.seed = 12062026

func set_mode(mode_id: String) -> void:
    var resolved: String = mode_id if mode_id in VALID_MODES else "career"
    if resolved == current_mode:
        return
    current_mode = resolved
    mode_switch_count += 1
    sample_cursor = 0
    current_gain = 0.0
    _ensure_music_audio()
    if current_mode == "silent":
        last_music_asset_path = ""
        music_player.stop()
        return
    _play_mode_stream(current_mode)

func set_suspended(value: bool) -> void:
    suspended = value
    if is_instance_valid(music_player):
        music_player.stream_paused = value
    if is_instance_valid(ui_player):
        ui_player.stream_paused = value

func duck(strength: float = 0.45) -> void:
    duck_gain = float(clamp(1.0 - strength, 0.18, 1.0))
    _apply_music_gain()

func play_ui(cue_id: String = "click") -> void:
    last_ui_cue = cue_id
    ui_cue_count += 1
    _ensure_ui_audio()
    _feed_ui_cue(cue_id)

func _process(delta: float) -> void:
    if suspended or current_mode == "silent":
        return
    _ensure_music_audio()
    current_gain = float(move_toward(current_gain, 1.0, delta * 2.4))
    duck_gain = float(move_toward(duck_gain, 1.0, delta * 3.8))
    _apply_music_gain()

func _ensure_music_audio() -> void:
    if is_instance_valid(music_player):
        return
    music_player = AudioStreamPlayer.new()
    music_player.name = "CommercialBGM"
    music_player.volume_db = MUSIC_VOLUME_DB
    add_child(music_player)

func _play_mode_stream(mode_id: String) -> void:
    _ensure_music_audio()
    var path := music_asset_path(mode_id)
    if path.is_empty() or not ResourceLoader.exists(path):
        push_warning("Missing commercial music asset for mode %s: %s" % [mode_id, path])
        last_music_asset_path = ""
        music_player.stop()
        return
    var stream := ResourceLoader.load(path) as AudioStream
    if stream == null:
        push_warning("Failed to load commercial music asset: %s" % path)
        last_music_asset_path = ""
        music_player.stop()
        return
    stream = stream.duplicate() as AudioStream
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = true
    music_player.stream = stream
    last_music_asset_path = path
    _apply_music_gain()
    music_player.play()

func _apply_music_gain() -> void:
    if not is_instance_valid(music_player):
        return
    var linear_gain := max(0.001, current_gain * duck_gain)
    music_player.volume_db = MUSIC_VOLUME_DB + linear_to_db(linear_gain)

func _ensure_ui_audio() -> void:
    if is_instance_valid(ui_player):
        return
    # UI clicks remain the only procedural audio in v1. They are tiny tactile
    # cues; all score, fight impacts, voice, bell and crowd audio is recorded.
    ui_player = AudioStreamPlayer.new()
    ui_player.name = "UISound"
    ui_generator = AudioStreamGenerator.new()
    ui_generator.mix_rate = MIX_RATE
    ui_generator.buffer_length = 0.12
    ui_player.stream = ui_generator
    ui_player.volume_db = UI_VOLUME_DB
    add_child(ui_player)
    ui_player.play()
    ui_playback = ui_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _feed_ui_cue(cue_id: String) -> void:
    if ui_playback == null or ui_generator == null:
        return
    var frequency: float = 220.0
    var duration: float = 0.024
    var amplitude: float = 0.12
    var noise_mix: float = 0.24
    match cue_id:
        "confirm":
            frequency = 250.0
            duration = 0.040
            amplitude = 0.15
            noise_mix = 0.18
        "purchase":
            frequency = 285.0
            duration = 0.048
            amplitude = 0.16
            noise_mix = 0.20
        "back":
            frequency = 185.0
            duration = 0.028
            amplitude = 0.10
            noise_mix = 0.22
        "fight_select":
            frequency = 170.0
            duration = 0.018
            amplitude = 0.075
            noise_mix = 0.26
        _:
            pass

    ui_playback.clear_buffer()
    var frame_count: int = int(min(ui_playback.get_frames_available(), int(MIX_RATE * duration)))
    for i in range(frame_count):
        var t: float = float(i) / MIX_RATE
        var progress: float = t / duration
        var envelope: float = pow(max(0.0, 1.0 - progress), 3.4)
        var knock: float = sin(TAU * frequency * t) * 0.72
        var grit: float = ui_rng.randf_range(-1.0, 1.0) * noise_mix
        var sample: float = float(clamp((knock + grit) * envelope * amplitude, -0.35, 0.35))
        ui_playback.push_frame(Vector2(sample, sample))

static func music_asset_path(mode_id: String) -> String:
    return str(MUSIC_ASSETS.get(mode_id, ""))

static func track_profile(mode_id: String) -> Dictionary:
    # These values remain product/mix metadata used by QA to ensure phase
    # contrast. Playback itself now comes from the licensed recorded assets.
    match mode_id:
        "menu":
            return {"bpm": 66.0, "root": 98.0, "intensity": 0.26, "pad": 0.62, "progression": [0, -3, -5, -7]}
        "career":
            return {"bpm": 74.0, "root": 87.31, "intensity": 0.34, "pad": 0.48, "progression": [0, 3, -2, -5]}
        "fight_week":
            return {"bpm": 84.0, "root": 82.41, "intensity": 0.46, "pad": 0.30, "progression": [0, -2, -5, -7]}
        "fight":
            return {"bpm": 96.0, "root": 73.42, "intensity": 0.58, "pad": 0.16, "progression": [0, -2, -3, -5]}
        "legacy":
            return {"bpm": 62.0, "root": 98.0, "intensity": 0.22, "pad": 0.72, "progression": [0, 3, -5, -2]}
        _:
            return {"bpm": 72.0, "root": 87.31, "intensity": 0.30, "pad": 0.42, "progression": [0, -3, -5, -7]}

static func mode_for_phase(phase: String, launch_gate: bool = false) -> String:
    if launch_gate or phase.is_empty():
        return "menu"
    match phase:
        "style_select", "talent_reveal": return "menu"
        "camp", "equipment_shop", "result", "event": return "career"
        "fight_offer", "tactical_prep", "condition_prep", "game_plan", "weigh_in": return "fight_week"
        "fight": return "fight"
        "career_summary": return "legacy"
        _: return "career"
