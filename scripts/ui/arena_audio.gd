class_name ArenaAudio
extends Node

var crowd_active: bool = false
var suspended: bool = false
var last_cue: String = ""
var cue_count: int = 0

var crowd_player: AudioStreamPlayer
var crowd_generator: AudioStreamGenerator
var crowd_playback: AudioStreamGeneratorPlayback
var cue_player: AudioStreamPlayer
var cue_generator: AudioStreamGenerator
var cue_playback: AudioStreamGeneratorPlayback
var noise_rng := RandomNumberGenerator.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    noise_rng.seed = 12062026

func start_fight() -> void:
    crowd_active = true
    _ensure_crowd_audio()
    _play_cue("round_bell")

func round_break(next_round: int) -> void:
    _play_cue("round_bell")
    if next_round > 1:
        _play_cue("corner_call")

func finish_fight() -> void:
    _play_cue("final_bell")
    crowd_active = false

func set_suspended(value: bool) -> void:
    suspended = value
    if is_instance_valid(crowd_player):
        crowd_player.stream_paused = value
    if is_instance_valid(cue_player):
        cue_player.stream_paused = value

func _process(_delta: float) -> void:
    if crowd_active and not suspended:
        _ensure_crowd_audio()
        _feed_crowd()

func _ensure_crowd_audio() -> void:
    if is_instance_valid(crowd_player):
        return
    crowd_player = AudioStreamPlayer.new()
    crowd_player.name = "CrowdAmbience"
    crowd_generator = AudioStreamGenerator.new()
    crowd_generator.mix_rate = 22050.0
    crowd_generator.buffer_length = 0.35
    crowd_player.stream = crowd_generator
    add_child(crowd_player)
    crowd_player.play()
    crowd_playback = crowd_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _ensure_cue_audio() -> void:
    if is_instance_valid(cue_player):
        return
    cue_player = AudioStreamPlayer.new()
    cue_player.name = "ArenaCueAudio"
    cue_generator = AudioStreamGenerator.new()
    cue_generator.mix_rate = 22050.0
    cue_generator.buffer_length = 0.25
    cue_player.stream = cue_generator
    add_child(cue_player)
    cue_player.play()
    cue_playback = cue_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _feed_crowd() -> void:
    if crowd_playback == null or crowd_generator == null:
        return
    var frames: int = min(crowd_playback.get_frames_available(), 768)
    for i in range(frames):
        var noise: float = noise_rng.randf_range(-1.0, 1.0) * 0.022
        var rumble: float = sin(TAU * 74.0 * (float(i) / crowd_generator.mix_rate)) * 0.010
        var sample: float = clamp(noise + rumble, -0.08, 0.08)
        crowd_playback.push_frame(Vector2(sample, sample))

func _play_cue(cue_id: String) -> void:
    last_cue = cue_id
    cue_count += 1
    _ensure_cue_audio()
    if cue_playback == null or cue_generator == null:
        return
    var spec: Dictionary = cue_profile(cue_id)
    var duration: float = float(spec.duration)
    var frequency: float = float(spec.frequency)
    var amplitude: float = float(spec.amplitude)
    var frames: int = min(cue_playback.get_frames_available(), int(cue_generator.mix_rate * duration))
    for i in range(frames):
        var t: float = float(i) / cue_generator.mix_rate
        var envelope: float = max(0.0, 1.0 - t / duration)
        var carrier: float = sin(TAU * frequency * t)
        var overtone: float = sin(TAU * frequency * 2.01 * t) * 0.45
        var sample: float = clamp((carrier + overtone) * amplitude * envelope, -1.0, 1.0)
        cue_playback.push_frame(Vector2(sample, sample))

static func cue_profile(cue_id: String) -> Dictionary:
    match cue_id:
        "round_bell": return {"frequency": 1180.0, "amplitude": 0.20, "duration": 0.16}
        "final_bell": return {"frequency": 930.0, "amplitude": 0.24, "duration": 0.20}
        "corner_call": return {"frequency": 520.0, "amplitude": 0.08, "duration": 0.08}
        _: return {"frequency": 440.0, "amplitude": 0.05, "duration": 0.05}
