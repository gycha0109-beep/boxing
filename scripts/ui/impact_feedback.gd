class_name ImpactFeedback
extends Node

const IMPACT_VOLUME_DB: float = -1.0
const VOICE_VOLUME_DB: float = -7.0
const IMPACT_PLAYER_COUNT: int = 5
const VOICE_PLAYER_COUNT: int = 2

const JAB_ASSETS: Array[String] = [
    "res://assets/audio/sfx/punches/jab_01.wav",
    "res://assets/audio/sfx/punches/jab_02.wav",
    "res://assets/audio/sfx/punches/jab_03.wav",
]
const HEAD_ASSETS: Array[String] = [
    "res://assets/audio/sfx/punches/head_01.wav",
    "res://assets/audio/sfx/punches/head_02.wav",
    "res://assets/audio/sfx/punches/head_03.wav",
    "res://assets/audio/sfx/punches/head_04.wav",
]
const HEAVY_ASSETS: Array[String] = [
    "res://assets/audio/sfx/punches/heavy_01.wav",
    "res://assets/audio/sfx/punches/heavy_02.wav",
    "res://assets/audio/sfx/punches/heavy_03.wav",
]
const COUNTER_ASSETS: Array[String] = [
    "res://assets/audio/sfx/punches/counter_01.wav",
    "res://assets/audio/sfx/punches/counter_02.wav",
    "res://assets/audio/sfx/punches/counter_03.wav",
]
const BODY_ASSETS: Array[String] = [
    "res://assets/audio/sfx/punches/body_01.wav",
    "res://assets/audio/sfx/punches/body_02.wav",
    "res://assets/audio/sfx/punches/body_03.wav",
]
const BLOCK_ASSETS: Array[String] = [
    "res://assets/audio/sfx/blocks/block_01.wav",
    "res://assets/audio/sfx/blocks/block_02.wav",
    "res://assets/audio/sfx/blocks/block_03.wav",
    "res://assets/audio/sfx/blocks/block_04.wav",
    "res://assets/audio/sfx/blocks/block_05.wav",
]
const SWING_ASSETS: Array[String] = [
    "res://assets/audio/sfx/swings/swing_01.wav",
    "res://assets/audio/sfx/swings/swing_02.wav",
    "res://assets/audio/sfx/swings/swing_03.wav",
]
const LIGHT_VOICE_ASSETS: Array[String] = [
    "res://assets/audio/sfx/voice/light_01.ogg",
    "res://assets/audio/sfx/voice/light_02.ogg",
    "res://assets/audio/sfx/voice/light_03.ogg",
    "res://assets/audio/sfx/voice/light_04.ogg",
]
const HEAVY_VOICE_ASSETS: Array[String] = [
    "res://assets/audio/sfx/voice/heavy_01.ogg",
    "res://assets/audio/sfx/voice/heavy_02.ogg",
    "res://assets/audio/sfx/voice/heavy_03.ogg",
]
const BODY_VOICE_ASSETS: Array[String] = [
    "res://assets/audio/sfx/voice/body_01.ogg",
    "res://assets/audio/sfx/voice/body_02.ogg",
]
const KNOCKDOWN_VOICE_ASSETS: Array[String] = [
    "res://assets/audio/sfx/voice/knockdown_01.ogg",
    "res://assets/audio/sfx/voice/knockdown_02.ogg",
]

var last_profile: String = "idle"
var last_sfx_cue: String = ""
var last_target_sfx_cue: String = ""
var last_haptic_ms: int = 0
var last_haptic_amplitude: float = 0.0
var last_asset_path: String = ""
var last_voice_asset_path: String = ""
var impact_players: Array[AudioStreamPlayer] = []
var voice_players: Array[AudioStreamPlayer] = []
var impact_cursor: int = 0
var voice_cursor: int = 0
var impact_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    impact_rng.seed = 12062026
    _ensure_audio_players()

func trigger(exchange: Dictionary) -> String:
    last_profile = profile(exchange)
    last_sfx_cue = sfx_cue(last_profile)
    last_target_sfx_cue = sfx_cue_for_exchange(exchange, last_profile)
    last_haptic_ms = haptic_duration_ms(last_profile)
    last_haptic_amplitude = haptic_amplitude(last_profile)
    _ensure_audio_players()
    _play_recorded_impact(exchange, last_profile, last_target_sfx_cue)
    _play_recorded_voice(exchange, last_profile, last_target_sfx_cue)
    if OS.has_feature("mobile") and last_haptic_ms > 0:
        Input.vibrate_handheld(last_haptic_ms, last_haptic_amplitude)
    return last_profile

func _ensure_audio_players() -> void:
    if impact_players.is_empty():
        for index in range(IMPACT_PLAYER_COUNT):
            var player := AudioStreamPlayer.new()
            player.name = "ImpactAudio%02d" % (index + 1)
            player.volume_db = IMPACT_VOLUME_DB
            add_child(player)
            impact_players.append(player)
    if voice_players.is_empty():
        for index in range(VOICE_PLAYER_COUNT):
            var player := AudioStreamPlayer.new()
            player.name = "ImpactVoice%02d" % (index + 1)
            player.volume_db = VOICE_VOLUME_DB
            add_child(player)
            voice_players.append(player)

func _play_recorded_impact(exchange: Dictionary, profile_id: String, cue_id: String) -> void:
    var pool := asset_pool_for_exchange(exchange, profile_id, cue_id)
    last_asset_path = _pick_asset(pool)
    if last_asset_path.is_empty():
        return
    var volume_offset := -1.5
    match profile_id:
        "guard": volume_offset = -3.5
        "miss": volume_offset = -7.0
        "heavy": volume_offset = 0.5
        "counter": volume_offset = 1.0
        "knockdown": volume_offset = 1.5
        _:
            pass
    _play_one_shot(impact_players, last_asset_path, volume_offset, true)

func _play_recorded_voice(exchange: Dictionary, profile_id: String, cue_id: String) -> void:
    last_voice_asset_path = ""
    if profile_id in ["idle", "guard", "miss"]:
        return
    # Recorded pain should support the glove transient rather than fire on
    # every light contact. Knockdowns always vocalize; ordinary hits vary.
    var chance := 0.34
    if profile_id in ["heavy", "counter"]:
        chance = 0.62
    elif profile_id == "knockdown":
        chance = 1.0
    elif cue_id == "body_hit":
        chance = 0.72
    if impact_rng.randf() > chance:
        return

    var pool: Array[String] = LIGHT_VOICE_ASSETS
    if profile_id == "knockdown":
        pool = KNOCKDOWN_VOICE_ASSETS
    elif cue_id == "body_hit":
        pool = BODY_VOICE_ASSETS
    elif profile_id in ["heavy", "counter"]:
        pool = HEAVY_VOICE_ASSETS
    last_voice_asset_path = _pick_asset(pool)
    if last_voice_asset_path.is_empty():
        return
    var gain := -1.5 if profile_id == "knockdown" else -3.0
    _play_one_shot(voice_players, last_voice_asset_path, gain, false)

func _play_one_shot(players: Array[AudioStreamPlayer], path: String, gain_db: float, vary_pitch: bool) -> void:
    if players.is_empty() or not ResourceLoader.exists(path):
        if not path.is_empty():
            push_warning("Missing commercial impact asset: %s" % path)
        return
    var stream := ResourceLoader.load(path) as AudioStream
    if stream == null:
        push_warning("Failed to load commercial impact asset: %s" % path)
        return
    var cursor := impact_cursor if players == impact_players else voice_cursor
    var player := players[cursor % players.size()]
    if players == impact_players:
        impact_cursor = (impact_cursor + 1) % players.size()
    else:
        voice_cursor = (voice_cursor + 1) % players.size()
    player.stop()
    player.stream = stream
    player.volume_db = (IMPACT_VOLUME_DB if players == impact_players else VOICE_VOLUME_DB) + gain_db
    player.pitch_scale = impact_rng.randf_range(0.97, 1.03) if vary_pitch else impact_rng.randf_range(0.985, 1.015)
    player.play()

func _pick_asset(pool: Array[String]) -> String:
    if pool.is_empty():
        return ""
    return pool[impact_rng.randi_range(0, pool.size() - 1)]

static func asset_pool_for_exchange(exchange: Dictionary, profile_id: String = "", cue_id: String = "") -> Array[String]:
    var resolved_profile := profile_id if not profile_id.is_empty() else profile(exchange)
    var resolved_cue := cue_id if not cue_id.is_empty() else sfx_cue_for_exchange(exchange, resolved_profile)
    if resolved_cue == "glove_block" or resolved_profile == "guard":
        return BLOCK_ASSETS
    if resolved_cue == "air_swing" or resolved_profile == "miss":
        return SWING_ASSETS
    if resolved_cue == "body_hit":
        return BODY_ASSETS
    if resolved_profile == "counter":
        return COUNTER_ASSETS
    if resolved_profile in ["heavy", "knockdown"]:
        return HEAVY_ASSETS
    if landed_action(exchange) == "jab":
        return JAB_ASSETS
    return HEAD_ASSETS

static func impact_profile(profile_id: String, cue_id: String = "") -> Dictionary:
    # Retained as a phone-mix contract for QA. Playback now comes from recorded
    # files, but these descriptors preserve the intended transient hierarchy.
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
