class_name ArenaAudio
extends Node

const CROWD_VOLUME_DB: float = -18.0
const CUE_VOLUME_DB: float = -9.0
const REACTION_VOLUME_DB: float = -13.0
const CUE_PLAYER_COUNT: int = 4
const CROWD_AMBIENCE_PATH := "res://assets/audio/sfx/crowd/crowd_ambience.ogg"
const ROUND_BELL_PATH := "res://assets/audio/sfx/bells/round_bell.wav"
const FINAL_BELL_PATH := "res://assets/audio/sfx/bells/final_bell.wav"
const SMALL_REACTIONS: Array[String] = [
    "res://assets/audio/sfx/crowd/reaction_small_01.ogg",
    "res://assets/audio/sfx/crowd/reaction_small_02.ogg",
]
const BIG_HIT_REACTIONS: Array[String] = [
    "res://assets/audio/sfx/crowd/reaction_big_hit_01.ogg",
    "res://assets/audio/sfx/crowd/reaction_big_hit_02.ogg",
]
const KNOCKDOWN_REACTIONS: Array[String] = [
    "res://assets/audio/sfx/crowd/reaction_knockdown_01.ogg",
    "res://assets/audio/sfx/crowd/reaction_knockdown_02.ogg",
]
const WIN_REACTIONS: Array[String] = [
    "res://assets/audio/sfx/crowd/reaction_win_01.ogg",
    "res://assets/audio/sfx/crowd/reaction_win_02.ogg",
]

var crowd_active: bool = false
var suspended: bool = false
var last_cue: String = ""
var cue_count: int = 0
var last_cue_asset_path: String = ""
var last_reaction: String = ""
var last_reaction_asset_path: String = ""

var crowd_player: AudioStreamPlayer
var cue_players: Array[AudioStreamPlayer] = []
var cue_cursor: int = 0
var reaction_player: AudioStreamPlayer
var crowd_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    crowd_rng.seed = 12062026
    _ensure_cue_audio()

func start_fight() -> void:
    crowd_active = true
    _ensure_crowd_audio()
    if not crowd_player.playing:
        crowd_player.play()
    _play_cue("round_bell")

func round_break(next_round: int) -> void:
    _play_cue("round_bell")
    if next_round > 1:
        _play_cue("corner_call")

func finish_fight() -> void:
    _play_cue("final_bell")
    _play_reaction("win")
    crowd_active = false
    if is_instance_valid(crowd_player):
        crowd_player.stop()

func react(exchange: Dictionary) -> void:
    if exchange.is_empty() or suspended:
        return
    var profile_id := ImpactFeedback.profile(exchange)
    match profile_id:
        "knockdown":
            _play_reaction("knockdown")
        "heavy", "counter":
            _play_reaction("big_hit")
        "medium":
            # Keep the bed alive without making every jab sound like a title KO.
            if crowd_rng.randf() <= 0.42:
                _play_reaction("small")
        _:
            pass

func set_suspended(value: bool) -> void:
    suspended = value
    if is_instance_valid(crowd_player):
        crowd_player.stream_paused = value
    if is_instance_valid(reaction_player):
        reaction_player.stream_paused = value
    for player in cue_players:
        if is_instance_valid(player):
            player.stream_paused = value

func _ensure_crowd_audio() -> void:
    if is_instance_valid(crowd_player):
        return
    crowd_player = AudioStreamPlayer.new()
    crowd_player.name = "CrowdAmbience"
    crowd_player.volume_db = CROWD_VOLUME_DB
    add_child(crowd_player)
    if not ResourceLoader.exists(CROWD_AMBIENCE_PATH):
        push_warning("Missing commercial crowd ambience: %s" % CROWD_AMBIENCE_PATH)
        return
    var stream := ResourceLoader.load(CROWD_AMBIENCE_PATH) as AudioStream
    if stream == null:
        push_warning("Failed to load commercial crowd ambience: %s" % CROWD_AMBIENCE_PATH)
        return
    stream = stream.duplicate() as AudioStream
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = true
    crowd_player.stream = stream

func _ensure_cue_audio() -> void:
    if cue_players.is_empty():
        for index in range(CUE_PLAYER_COUNT):
            var player := AudioStreamPlayer.new()
            player.name = "ArenaCueAudio%02d" % (index + 1)
            player.volume_db = CUE_VOLUME_DB
            add_child(player)
            cue_players.append(player)
    if not is_instance_valid(reaction_player):
        reaction_player = AudioStreamPlayer.new()
        reaction_player.name = "CrowdReaction"
        reaction_player.volume_db = REACTION_VOLUME_DB
        add_child(reaction_player)

func _play_cue(cue_id: String) -> void:
    last_cue = cue_id
    cue_count += 1
    _ensure_cue_audio()
    var path := cue_asset_path(cue_id)
    last_cue_asset_path = path
    if path.is_empty() or not ResourceLoader.exists(path):
        if not path.is_empty():
            push_warning("Missing commercial arena cue: %s" % path)
        return
    var stream := ResourceLoader.load(path) as AudioStream
    if stream == null:
        push_warning("Failed to load commercial arena cue: %s" % path)
        return
    var player := cue_players[cue_cursor % cue_players.size()]
    cue_cursor = (cue_cursor + 1) % cue_players.size()
    player.stop()
    player.stream = stream
    player.volume_db = CUE_VOLUME_DB + (-4.0 if cue_id == "corner_call" else 0.0)
    player.pitch_scale = 0.96 if cue_id == "corner_call" else 1.0
    player.play()

func _play_reaction(reaction_id: String) -> void:
    _ensure_cue_audio()
    var pool := reaction_assets(reaction_id)
    if pool.is_empty():
        return
    var path := pool[crowd_rng.randi_range(0, pool.size() - 1)]
    last_reaction = reaction_id
    last_reaction_asset_path = path
    if not ResourceLoader.exists(path):
        push_warning("Missing commercial crowd reaction: %s" % path)
        return
    var stream := ResourceLoader.load(path) as AudioStream
    if stream == null:
        push_warning("Failed to load commercial crowd reaction: %s" % path)
        return
    reaction_player.stop()
    reaction_player.stream = stream
    reaction_player.pitch_scale = crowd_rng.randf_range(0.98, 1.02)
    reaction_player.volume_db = REACTION_VOLUME_DB + (1.5 if reaction_id in ["knockdown", "win"] else 0.0)
    reaction_player.play()

static func cue_asset_path(cue_id: String) -> String:
    match cue_id:
        "round_bell": return ROUND_BELL_PATH
        "final_bell": return FINAL_BELL_PATH
        # A subdued real crowd accent replaces the old synthetic 520 Hz tone.
        "corner_call": return SMALL_REACTIONS[0]
        _: return ""

static func reaction_assets(reaction_id: String) -> Array[String]:
    match reaction_id:
        "small": return SMALL_REACTIONS
        "big_hit": return BIG_HIT_REACTIONS
        "knockdown": return KNOCKDOWN_REACTIONS
        "win": return WIN_REACTIONS
        _: return [] as Array[String]

static func cue_profile(cue_id: String) -> Dictionary:
    # Kept as a QA/mix contract. Runtime playback now uses recorded CC0 files.
    match cue_id:
        "round_bell": return {"frequency": 1180.0, "amplitude": 0.20, "duration": 0.16}
        "final_bell": return {"frequency": 930.0, "amplitude": 0.24, "duration": 0.20}
        "corner_call": return {"frequency": 520.0, "amplitude": 0.08, "duration": 0.08}
        _: return {"frequency": 440.0, "amplitude": 0.05, "duration": 0.05}
