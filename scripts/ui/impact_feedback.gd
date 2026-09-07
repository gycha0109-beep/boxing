class_name ImpactFeedback
extends Node

var last_profile: String = "idle"
var last_sfx_cue: String = ""
var last_haptic_ms: int = 0
var audio_player: AudioStreamPlayer
var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback

func trigger(exchange: Dictionary) -> String:
    last_profile = profile(exchange)
    last_sfx_cue = sfx_cue(last_profile)
    last_haptic_ms = haptic_duration_ms(last_profile)
    _ensure_audio()
    _play_procedural_impact(last_profile)
    if OS.has_feature("mobile") and last_haptic_ms > 0:
        Input.vibrate_handheld(last_haptic_ms)
    return last_profile

func _ensure_audio() -> void:
    if is_instance_valid(audio_player):
        return
    audio_player = AudioStreamPlayer.new()
    audio_player.name = "ImpactAudio"
    generator = AudioStreamGenerator.new()
    generator.mix_rate = 22050.0
    generator.buffer_length = 0.12
    audio_player.stream = generator
    add_child(audio_player)
    audio_player.play()
    playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _play_procedural_impact(profile_id: String) -> void:
    if not is_instance_valid(playback) or not is_instance_valid(generator):
        return
    var duration: float = 0.035
    var frequency: float = 105.0
    var amplitude: float = 0.18
    match profile_id:
        "guard":
            frequency = 150.0
            amplitude = 0.12
            duration = 0.028
        "medium":
            frequency = 92.0
            amplitude = 0.22
            duration = 0.045
        "heavy":
            frequency = 72.0
            amplitude = 0.30
            duration = 0.060
        "counter":
            frequency = 128.0
            amplitude = 0.32
            duration = 0.055
        "knockdown":
            frequency = 58.0
            amplitude = 0.38
            duration = 0.080
        "miss":
            frequency = 210.0
            amplitude = 0.07
            duration = 0.020
        _:
            pass
    var frame_count: int = min(playback.get_frames_available(), int(generator.mix_rate * duration))
    if frame_count <= 0:
        return
    for i in range(frame_count):
        var t: float = float(i) / generator.mix_rate
        var envelope: float = max(0.0, 1.0 - t / duration)
        var fundamental: float = sin(TAU * frequency * t)
        var grit: float = sin(TAU * frequency * 2.7 * t) * 0.22
        var sample: float = clamp((fundamental + grit) * amplitude * envelope, -1.0, 1.0)
        playback.push_frame(Vector2(sample, sample))

static func profile(exchange: Dictionary) -> String:
    if exchange.is_empty():
        return "idle"
    var player_event: Dictionary = exchange.get("player_event", {})
    var opponent_event: Dictionary = exchange.get("opponent_event", {})
    if bool(player_event.get("knockout", false)) or bool(opponent_event.get("knockout", false)):
        return "knockdown"
    if bool(exchange.get("counter_success", false)):
        return "counter"
    var strongest_damage: float = max(float(player_event.get("damage", 0.0)), float(opponent_event.get("damage", 0.0)))
    if strongest_damage >= 14.0:
        return "heavy"
    if bool(player_event.get("hit", false)) or bool(opponent_event.get("hit", false)):
        return "medium"
    if bool(player_event.get("guard", false)) or bool(opponent_event.get("guard", false)):
        return "guard"
    if bool(player_event.get("miss", false)) or bool(opponent_event.get("miss", false)):
        return "miss"
    return "light"

static func haptic_duration_ms(profile_id: String) -> int:
    match profile_id:
        "guard": return 18
        "medium": return 28
        "heavy": return 42
        "counter": return 48
        "knockdown": return 70
        _: return 0

static func sfx_cue(profile_id: String) -> String:
    match profile_id:
        "guard": return "glove_block"
        "medium": return "glove_hit"
        "heavy": return "heavy_hit"
        "counter": return "counter_crack"
        "knockdown": return "knockdown_thud"
        "miss": return "air_swing"
        _: return ""
