class_name ImpactFeedback
extends Node

var last_profile: String = "idle"
var last_sfx_cue: String = ""
var last_target_sfx_cue: String = ""
var last_haptic_ms: int = 0
var last_haptic_amplitude: float = 0.0
var audio_player: AudioStreamPlayer
var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var impact_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    impact_rng.seed = 12062026

func trigger(exchange: Dictionary) -> String:
    last_profile = profile(exchange)
    last_sfx_cue = sfx_cue(last_profile)
    last_target_sfx_cue = sfx_cue_for_exchange(exchange, last_profile)
    last_haptic_ms = haptic_duration_ms(last_profile)
    last_haptic_amplitude = haptic_amplitude(last_profile)
    _ensure_audio()
    _play_procedural_impact(last_profile, last_target_sfx_cue)
    if OS.has_feature("mobile") and last_haptic_ms > 0:
        Input.vibrate_handheld(last_haptic_ms, last_haptic_amplitude)
    return last_profile

func _ensure_audio() -> void:
    if is_instance_valid(audio_player):
        return
    audio_player = AudioStreamPlayer.new()
    audio_player.name = "ImpactAudio"
    generator = AudioStreamGenerator.new()
    generator.mix_rate = 22050.0
    generator.buffer_length = 0.20
    audio_player.stream = generator
    audio_player.volume_db = 0.0
    add_child(audio_player)
    audio_player.play()
    playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _play_procedural_impact(profile_id: String, cue_id: String) -> void:
    if playback == null or generator == null:
        return
    var spec: Dictionary = impact_profile(profile_id, cue_id)
    var duration: float = float(spec.get("duration", 0.055))
    var body_frequency: float = float(spec.get("body_frequency", 175.0))
    var crack_frequency: float = float(spec.get("crack_frequency", 560.0))
    var amplitude: float = float(spec.get("amplitude", 0.55))
    var noise_mix: float = float(spec.get("noise_mix", 0.28))

    # A fresh impact must win the mix immediately. Low-only tones were almost
    # inaudible on phone speakers; clearing queued samples also prevents a hit
    # from arriving late behind a previous transient.
    playback.clear_buffer()
    var frame_count: int = int(min(playback.get_frames_available(), int(generator.mix_rate * duration)))
    if frame_count <= 0:
        return

    for i in range(frame_count):
        var t: float = float(i) / generator.mix_rate
        var progress: float = t / duration
        var body_envelope: float = pow(max(0.0, 1.0 - progress), 2.2)
        var crack_envelope: float = exp(-progress * 9.5)
        var body: float = sin(TAU * body_frequency * t) * 0.72
        var slap: float = sin(TAU * crack_frequency * t) * 0.38 * crack_envelope
        var grit: float = impact_rng.randf_range(-1.0, 1.0) * noise_mix * crack_envelope
        var sample: float = float(clamp((body + slap + grit) * amplitude * body_envelope, -0.95, 0.95))
        playback.push_frame(Vector2(sample, sample))

static func impact_profile(profile_id: String, cue_id: String = "") -> Dictionary:
    var spec: Dictionary
    match profile_id:
        "guard":
            spec = {"duration": 0.050, "body_frequency": 215.0, "crack_frequency": 390.0, "amplitude": 0.44, "noise_mix": 0.22}
        "medium":
            spec = {"duration": 0.064, "body_frequency": 178.0, "crack_frequency": 610.0, "amplitude": 0.60, "noise_mix": 0.30}
        "heavy":
            spec = {"duration": 0.088, "body_frequency": 158.0, "crack_frequency": 760.0, "amplitude": 0.74, "noise_mix": 0.34}
        "counter":
            spec = {"duration": 0.078, "body_frequency": 184.0, "crack_frequency": 860.0, "amplitude": 0.78, "noise_mix": 0.38}
        "knockdown":
            spec = {"duration": 0.115, "body_frequency": 138.0, "crack_frequency": 430.0, "amplitude": 0.84, "noise_mix": 0.32}
        "miss":
            spec = {"duration": 0.034, "body_frequency": 320.0, "crack_frequency": 920.0, "amplitude": 0.20, "noise_mix": 0.42}
        _:
            spec = {"duration": 0.050, "body_frequency": 190.0, "crack_frequency": 520.0, "amplitude": 0.50, "noise_mix": 0.26}

    if cue_id == "body_hit":
        spec["body_frequency"] = 148.0
        spec["crack_frequency"] = 360.0
        spec["duration"] = float(spec.get("duration", 0.055)) * 1.16
        spec["noise_mix"] = float(spec.get("noise_mix", 0.28)) * 0.72
    elif cue_id == "head_crack":
        spec["body_frequency"] = max(172.0, float(spec.get("body_frequency", 175.0)))
        spec["crack_frequency"] = max(820.0, float(spec.get("crack_frequency", 560.0)))
        spec["amplitude"] = min(0.88, float(spec.get("amplitude", 0.55)) * 1.08)
        spec["noise_mix"] = min(0.44, float(spec.get("noise_mix", 0.28)) * 1.12)
    elif cue_id == "glove_block":
        spec["body_frequency"] = 230.0
        spec["crack_frequency"] = 410.0
        spec["amplitude"] = float(spec.get("amplitude", 0.55)) * 0.84
    return spec

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

static func landed_action(exchange: Dictionary) -> String:
    var player_event: Dictionary = exchange.get("player_event", {})
    if bool(player_event.get("hit", false)):
        return str(exchange.get("player_action", ""))
    var opponent_event: Dictionary = exchange.get("opponent_event", {})
    if bool(opponent_event.get("hit", false)):
        return str(exchange.get("opponent_action", ""))
    return ""

static func sfx_cue_for_exchange(exchange: Dictionary, profile_id: String = "") -> String:
    var resolved_profile: String = profile_id if not profile_id.is_empty() else profile(exchange)
    if resolved_profile == "knockdown":
        return "knockdown_thud"
    if resolved_profile == "guard":
        return "glove_block"
    if resolved_profile == "miss":
        return "air_swing"
    var action_id: String = landed_action(exchange)
    if action_id == "body":
        return "body_hit"
    if resolved_profile in ["heavy", "counter"]:
        return "head_crack"
    if resolved_profile in ["medium", "light"]:
        return "glove_head_hit"
    return ""

static func haptic_duration_ms(profile_id: String) -> int:
    match profile_id:
        "guard": return 18
        "medium": return 28
        "heavy": return 42
        "counter": return 48
        "knockdown": return 70
        _: return 0

static func haptic_amplitude(profile_id: String) -> float:
    match profile_id:
        "guard": return 0.28
        "medium": return 0.46
        "heavy": return 0.68
        "counter": return 0.78
        "knockdown": return 0.92
        _: return 0.0

static func hit_stop_seconds(profile_id: String) -> float:
    match profile_id:
        "medium": return 0.018
        "heavy": return 0.030
        "counter": return 0.038
        "knockdown": return 0.052
        _: return 0.0

static func shake_strength(profile_id: String) -> float:
    match profile_id:
        "medium": return 1.5
        "heavy": return 3.0
        "counter": return 3.6
        "knockdown": return 5.0
        _: return 0.0

static func sfx_cue(profile_id: String) -> String:
    match profile_id:
        "guard": return "glove_block"
        "medium": return "glove_hit"
        "heavy": return "heavy_hit"
        "counter": return "counter_crack"
        "knockdown": return "knockdown_thud"
        "miss": return "air_swing"
        _: return ""
