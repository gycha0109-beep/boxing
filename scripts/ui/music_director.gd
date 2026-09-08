class_name MusicDirector
extends Node

const MIX_RATE: float = 22050.0
const VALID_MODES: Array[String] = ["silent", "menu", "career", "fight_week", "fight", "legacy"]
const MUSIC_VOLUME_DB: float = -19.0
const UI_VOLUME_DB: float = -13.0

var current_mode: String = "silent"
var last_ui_cue: String = ""
var mode_switch_count: int = 0
var ui_cue_count: int = 0
var sample_cursor: int = 0
var current_gain: float = 0.0
var duck_gain: float = 1.0
var suspended: bool = false

var music_player: AudioStreamPlayer
var music_generator: AudioStreamGenerator
var music_playback: AudioStreamGeneratorPlayback
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
    if current_mode != "silent":
        _ensure_music_audio()

func set_suspended(value: bool) -> void:
    suspended = value
    if is_instance_valid(music_player):
        music_player.stream_paused = value
    if is_instance_valid(ui_player):
        ui_player.stream_paused = value

func duck(strength: float = 0.45) -> void:
    duck_gain = float(clamp(1.0 - strength, 0.18, 1.0))

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
    _feed_music()

func _ensure_music_audio() -> void:
    if is_instance_valid(music_player):
        return
    music_player = AudioStreamPlayer.new()
    music_player.name = "ProceduralBGM"
    music_generator = AudioStreamGenerator.new()
    music_generator.mix_rate = MIX_RATE
    music_generator.buffer_length = 0.45
    music_player.stream = music_generator
    music_player.volume_db = MUSIC_VOLUME_DB
    add_child(music_player)
    music_player.play()
    music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _ensure_ui_audio() -> void:
    if is_instance_valid(ui_player):
        return
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

func _feed_music() -> void:
    if music_playback == null or music_generator == null:
        return
    var spec: Dictionary = track_profile(current_mode)
    var frames: int = int(min(music_playback.get_frames_available(), 1024))
    if frames <= 0:
        return
    var bpm: float = float(spec.get("bpm", 82.0))
    var root: float = float(spec.get("root", 98.0))
    var intensity: float = float(spec.get("intensity", 0.45))
    var pad_level: float = float(spec.get("pad", 0.35))
    var beat_seconds: float = 60.0 / bpm
    var progression: Array = spec.get("progression", [0, -3, -5, -7])

    for _i in range(frames):
        var t: float = float(sample_cursor) / MIX_RATE
        var beat_pos: float = t / beat_seconds
        var beat_phase: float = fmod(beat_pos, 1.0)
        var half_phase: float = fmod(beat_pos * 0.5, 1.0)
        var chord_index: int = int(floor(beat_pos / 4.0)) % progression.size()
        var chord_root: float = root * pow(2.0, float(progression[chord_index]) / 12.0)

        # Keep the placeholder score deliberately dark and low-mid. The old
        # high sine pulses/metallic hats read as arcade laser sounds on phones.
        var pad: float = _soft_chord(chord_root, t) * 0.018 * pad_level
        var bass_env: float = 0.42 + 0.58 * exp(-beat_phase * 4.0)
        var bass: float = sin(TAU * chord_root * 0.5 * t) * bass_env * 0.026 * intensity

        var thump_env: float = exp(-beat_phase * 11.0)
        var thump: float = sin(TAU * (72.0 + 18.0 * thump_env) * t) * thump_env * 0.028 * intensity

        var second_thump: float = 0.0
        if current_mode in ["fight_week", "fight"]:
            var second_phase: float = fmod(beat_pos + 0.5, 1.0)
            var second_env: float = exp(-second_phase * 13.0)
            second_thump = sin(TAU * 126.0 * t) * second_env * 0.012 * intensity

        var pressure: float = 0.0
        if current_mode == "fight":
            var pressure_env: float = exp(-half_phase * 5.0)
            pressure = sin(TAU * chord_root * 1.5 * t) * pressure_env * 0.006

        var attack: float = min(1.0, t / 0.45)
        var gain: float = current_gain * duck_gain * attack
        var sample: float = float(clamp((pad + bass + thump + second_thump + pressure) * gain, -0.22, 0.22))
        music_playback.push_frame(Vector2(sample, sample))
        sample_cursor += 1

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

static func _soft_chord(root: float, t: float) -> float:
    var fifth: float = root * pow(2.0, 7.0 / 12.0)
    return sin(TAU * root * t) * 0.62 + sin(TAU * root * 0.5 * t) * 0.42 + sin(TAU * fifth * t) * 0.16

static func track_profile(mode_id: String) -> Dictionary:
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
