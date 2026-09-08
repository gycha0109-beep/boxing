class_name MusicDirector
extends Node

const MIX_RATE := 22050.0
const VALID_MODES := ["silent", "menu", "career", "fight_week", "fight", "legacy"]

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

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func set_mode(mode_id: String) -> void:
    var resolved := mode_id if mode_id in VALID_MODES else "career"
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
    duck_gain = clamp(1.0 - strength, 0.28, 1.0)

func play_ui(cue_id: String = "click") -> void:
    last_ui_cue = cue_id
    ui_cue_count += 1
    _ensure_ui_audio()
    _feed_ui_cue(cue_id)

func _process(delta: float) -> void:
    if suspended or current_mode == "silent":
        return
    _ensure_music_audio()
    current_gain = move_toward(current_gain, 1.0, delta * 3.6)
    duck_gain = move_toward(duck_gain, 1.0, delta * 4.8)
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
    music_player.volume_db = -5.0
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
    ui_generator.buffer_length = 0.16
    ui_player.stream = ui_generator
    ui_player.volume_db = -4.0
    add_child(ui_player)
    ui_player.play()
    ui_playback = ui_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _feed_music() -> void:
    if music_playback == null or music_generator == null:
        return
    var spec := track_profile(current_mode)
    var frames := min(music_playback.get_frames_available(), 1024)
    if frames <= 0:
        return
    var bpm := float(spec.get("bpm", 82.0))
    var root := float(spec.get("root", 98.0))
    var intensity := float(spec.get("intensity", 0.55))
    var pad_level := float(spec.get("pad", 0.30))
    var beat_seconds := 60.0 / bpm
    var progression: Array = spec.get("progression", [0, -3, -5, -7])

    for _i in range(frames):
        var t := float(sample_cursor) / MIX_RATE
        var beat_pos := t / beat_seconds
        var beat_index := int(floor(beat_pos))
        var beat_phase := fmod(beat_pos, 1.0)
        var eighth_phase := fmod(beat_pos * 2.0, 1.0)
        var chord_index := int(floor(beat_pos / 4.0)) % progression.size()
        var chord_root := root * pow(2.0, float(progression[chord_index]) / 12.0)

        var pad := _triad(chord_root, t) * 0.025 * pad_level
        var bass_env := exp(-beat_phase * 5.5)
        var bass := sin(TAU * chord_root * 0.5 * t) * bass_env * 0.034 * intensity

        var kick_env := exp(-beat_phase * 13.0)
        var kick_freq := 48.0 + 34.0 * kick_env
        var kick := sin(TAU * kick_freq * t) * kick_env * 0.052 * intensity

        var pulse_env := exp(-eighth_phase * 9.0)
        var pulse_note := chord_root * (2.0 if (beat_index % 4) in [0, 3] else 1.5)
        var pulse := sin(TAU * pulse_note * t) * pulse_env * 0.017 * intensity

        var hat := 0.0
        if current_mode in ["fight_week", "fight"]:
            var metallic := sin(TAU * 4210.0 * t) + sin(TAU * 6170.0 * t) * 0.55
            hat = metallic * exp(-eighth_phase * 24.0) * 0.0045 * intensity

        var tension := 0.0
        if current_mode == "fight":
            var sixteenth_phase := fmod(beat_pos * 4.0, 1.0)
            tension = sin(TAU * chord_root * 2.0 * t) * exp(-sixteenth_phase * 7.0) * 0.009

        var attack := min(1.0, t / 0.22)
        var gain := current_gain * duck_gain * attack
        var sample := clamp((pad + bass + kick + pulse + hat + tension) * gain, -0.38, 0.38)
        var stereo_wobble := sin(TAU * 0.17 * t) * 0.07
        music_playback.push_frame(Vector2(sample * (1.0 - stereo_wobble), sample * (1.0 + stereo_wobble)))
        sample_cursor += 1

func _feed_ui_cue(cue_id: String) -> void:
    if ui_playback == null or ui_generator == null:
        return
    var frequency := 720.0
    var second_frequency := 960.0
    var duration := 0.035
    var amplitude := 0.10
    match cue_id:
        "confirm":
            frequency = 620.0
            second_frequency = 930.0
            duration = 0.075
            amplitude = 0.13
        "purchase":
            frequency = 760.0
            second_frequency = 1140.0
            duration = 0.09
            amplitude = 0.14
        "back":
            frequency = 510.0
            second_frequency = 390.0
            duration = 0.045
            amplitude = 0.08
        "fight_select":
            frequency = 390.0
            second_frequency = 520.0
            duration = 0.028
            amplitude = 0.07
        _:
            pass

    var frame_count := min(ui_playback.get_frames_available(), int(MIX_RATE * duration))
    for i in range(frame_count):
        var t := float(i) / MIX_RATE
        var progress := t / duration
        var envelope := pow(max(0.0, 1.0 - progress), 2.2)
        var sweep := lerp(frequency, second_frequency, progress)
        var carrier := sin(TAU * sweep * t)
        var overtone := sin(TAU * sweep * 2.0 * t) * 0.24
        var sample := clamp((carrier + overtone) * envelope * amplitude, -0.6, 0.6)
        ui_playback.push_frame(Vector2(sample, sample))

static func _triad(root: float, t: float) -> float:
    var third := root * pow(2.0, 3.0 / 12.0)
    var fifth := root * pow(2.0, 7.0 / 12.0)
    return sin(TAU * root * t) * 0.56 + sin(TAU * third * t) * 0.28 + sin(TAU * fifth * t) * 0.22

static func track_profile(mode_id: String) -> Dictionary:
    match mode_id:
        "menu":
            return {"bpm": 72.0, "root": 110.0, "intensity": 0.36, "pad": 0.75, "progression": [0, -3, -5, -7]}
        "career":
            return {"bpm": 82.0, "root": 98.0, "intensity": 0.48, "pad": 0.55, "progression": [0, 3, -2, -5]}
        "fight_week":
            return {"bpm": 96.0, "root": 82.41, "intensity": 0.66, "pad": 0.38, "progression": [0, -2, -5, -7]}
        "fight":
            return {"bpm": 118.0, "root": 73.42, "intensity": 0.92, "pad": 0.18, "progression": [0, -2, -3, -5]}
        "legacy":
            return {"bpm": 68.0, "root": 110.0, "intensity": 0.30, "pad": 0.85, "progression": [0, 3, -5, -2]}
        _:
            return {"bpm": 80.0, "root": 98.0, "intensity": 0.40, "pad": 0.50, "progression": [0, -3, -5, -7]}

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
