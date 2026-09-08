class_name VisualAssetCatalog
extends RefCounted

const ROOT := "res://assets/visual/v0.7"
const POSES := ["idle", "jab", "power", "body", "guard", "counter", "hurt", "knockdown"]
const STYLES := ["swarmer", "outboxer", "slugger", "counter"]

# Combat style remains gameplay data in data/opponents.json. Visual profile is
# intentionally separate so a Korean boxer cannot turn into a different person
# just because two opponents share the same tactical style.
const VISUAL_PROFILE_BY_NAME := {
    "한도윤": "korean", "서민재": "korean", "장우진": "korean", "박태호": "korean",
    "이준석": "korean", "배성호": "korean", "김성민": "korean", "최현우": "korean",
    "임태건": "korean", "강무진": "korean", "윤재혁": "korean", "나카무라 렌": "korean",
    "미겔 산토스": "latino", "에번 브룩스": "black", "마테오 실바": "latino",
    "빅토르 코즐로프": "european",
}
const COUNTRY_BY_NAME := {
    "한도윤": "KR", "서민재": "KR", "장우진": "KR", "박태호": "KR",
    "이준석": "KR", "배성호": "KR", "김성민": "KR", "최현우": "KR",
    "임태건": "KR", "강무진": "KR", "윤재혁": "KR", "나카무라 렌": "JP",
    "미겔 산토스": "MX", "에번 브룩스": "US", "마테오 실바": "BR",
    "빅토르 코즐로프": "RU",
}
const VISUAL_STYLE_BY_PROFILE := {
    # The legacy slugger pose set is player-derived and is the stable East-Asian set.
    "korean": "slugger",
    # These three retain the distinct authored v0.7 silhouettes.
    "black": "swarmer",
    "latino": "outboxer",
    "european": "counter",
}
const PORTRAIT_STYLE_BY_PROFILE := {
    "black": "swarmer",
    "latino": "outboxer",
    "european": "counter",
}

static var _texture_cache: Dictionary = {}
static var _opponent_cache: Dictionary = {}
static var _opponents_loaded: bool = false

static func normalize_style(style_id: String) -> String:
    match style_id.strip_edges().to_lower():
        "out_boxer", "out-boxer", "outboxer": return "outboxer"
        "counter_puncher", "counter-puncher", "counter": return "counter"
        "swarmer": return "swarmer"
        "slugger": return "slugger"
        _: return "swarmer"

static func fighter_path(is_player: bool, style_id: String, pose: String) -> String:
    var normalized_pose := _normalize_pose(pose)
    if is_player:
        return "%s/fighters/player/player_base_%s.png" % [ROOT, normalized_pose]
    var style := normalize_style(style_id)
    return "%s/fighters/opponents/%s/op_%s_a_%s.png" % [ROOT, style, style, normalized_pose]

static func portrait_path(is_player: bool, style_id: String = "") -> String:
    if is_player:
        return "%s/portraits/portrait_player_a.png" % ROOT
    return "%s/portraits/portrait_%s_a.png" % [ROOT, normalize_style(style_id)]

static func opponent_visual_profile_for_name(opponent_name: String) -> String:
    return str(VISUAL_PROFILE_BY_NAME.get(opponent_name, "korean"))

static func opponent_visual_style_for_name(opponent_name: String) -> String:
    var profile: String = opponent_visual_profile_for_name(opponent_name)
    return normalize_style(str(VISUAL_STYLE_BY_PROFILE.get(profile, "slugger")))

static func opponent_country_badge(opponent_name: String) -> String:
    return str(COUNTRY_BY_NAME.get(opponent_name, "INT"))

static func opponent_portrait_path_for_name(opponent_name: String) -> String:
    var profile: String = opponent_visual_profile_for_name(opponent_name)
    if profile == "korean":
        # Use the exact visual family that FightStage will render. This keeps the
        # contract-board portrait distinct from the player and prevents the
        # portrait/fight person swap that existed in the prototype pipeline.
        return fighter_path(false, opponent_visual_style_for_name(opponent_name), "idle")
    var portrait_style: String = str(PORTRAIT_STYLE_BY_PROFILE.get(profile, "swarmer"))
    return portrait_path(false, portrait_style)

static func opponent_portrait_texture_for_name(opponent_name: String) -> Texture2D:
    return texture(opponent_portrait_path_for_name(opponent_name))

static func arena_path(title_fight: bool) -> String:
    return "%s/arena/%s" % [ROOT, "arena_title_night.png" if title_fight else "arena_gym_basic.png"]

static func fx_path(exchange: Dictionary) -> String:
    if exchange.is_empty():
        return ""
    var player_event: Dictionary = exchange.get("player_event", {})
    var opponent_event: Dictionary = exchange.get("opponent_event", {})
    if bool(player_event.get("knockout", false)) or bool(opponent_event.get("knockout", false)):
        return "%s/fx/fx_knockdown_burst_01.png" % ROOT
    if bool(exchange.get("counter_success", false)):
        return "%s/fx/fx_counter_flash_01.png" % ROOT
    var player_hit := bool(player_event.get("hit", false))
    var opponent_hit := bool(opponent_event.get("hit", false))
    if not player_hit and not opponent_hit:
        return "%s/fx/fx_block_01.png" % ROOT
    var action_id := str(exchange.get("player_action" if player_hit else "opponent_action", "jab"))
    match action_id:
        "power": return "%s/fx/fx_hit_power_01.png" % ROOT
        "body": return "%s/fx/fx_hit_body_01.png" % ROOT
        _: return "%s/fx/fx_hit_jab_01.png" % ROOT

static func ui_path(asset_name: String) -> String:
    return "%s/ui/%s.png" % [ROOT, asset_name]

static func icon_path(icon_name: String) -> String:
    return "%s/icons/icon_%s.png" % [ROOT, icon_name]

static func fighter_texture(is_player: bool, style_id: String, pose: String) -> Texture2D:
    return texture(fighter_path(is_player, style_id, pose))

static func portrait_texture(is_player: bool, style_id: String = "") -> Texture2D:
    return texture(portrait_path(is_player, style_id))

static func arena_texture(title_fight: bool) -> Texture2D:
    return texture(arena_path(title_fight))

static func fx_texture(exchange: Dictionary) -> Texture2D:
    var path := fx_path(exchange)
    return texture(path) if not path.is_empty() else null

static func texture(path: String) -> Texture2D:
    if path.is_empty():
        return null
    if _texture_cache.has(path):
        return _texture_cache[path]
    if not ResourceLoader.exists(path):
        _texture_cache[path] = null
        return null
    var loaded := load(path)
    var result: Texture2D = loaded as Texture2D
    _texture_cache[path] = result
    return result

static func asset_pack_available() -> bool:
    return ResourceLoader.exists(fighter_path(true, "", "idle")) and ResourceLoader.exists(arena_path(false))

static func expected_required_paths() -> Array[String]:
    var result: Array[String] = []
    for pose in POSES:
        result.append(fighter_path(true, "", pose))
    for style in STYLES:
        for pose in POSES:
            result.append(fighter_path(false, style, pose))
        result.append(portrait_path(false, style))
    result.append(portrait_path(true))
    result.append(arena_path(false))
    result.append(arena_path(true))
    for fx_name in ["fx_hit_jab_01", "fx_hit_power_01", "fx_hit_body_01", "fx_block_01", "fx_counter_flash_01", "fx_knockdown_burst_01"]:
        result.append("%s/fx/%s.png" % [ROOT, fx_name])
    return result

static func missing_required_paths() -> Array[String]:
    var result: Array[String] = []
    for path in expected_required_paths():
        if not ResourceLoader.exists(path):
            result.append(path)
    return result

# Kept for compatibility with FightStage: this now returns the visual style.
# Combat code reads the opponent dictionary's real style directly and is unchanged.
static func opponent_style_for_name(opponent_name: String) -> String:
    return opponent_visual_style_for_name(opponent_name)

static func opponent_combat_style_for_name(opponent_name: String) -> String:
    _load_opponents()
    var meta: Dictionary = _opponent_cache.get(opponent_name, {})
    return normalize_style(str(meta.get("style", "swarmer")))

static func install_identity_visual_profiles() -> void:
    # Compatibility hook for the v1.1 UI shell. Identity routing is resolved
    # dynamically by the methods above, so no gameplay data is mutated.
    _load_opponents()

static func is_title_opponent(opponent_name: String) -> bool:
    _load_opponents()
    var meta: Dictionary = _opponent_cache.get(opponent_name, {})
    return bool(meta.get("title_fight", false))

static func _normalize_pose(pose: String) -> String:
    var value := pose.strip_edges().to_lower()
    if value == "down":
        return "knockdown"
    return value if value in POSES else "idle"

static func _load_opponents() -> void:
    if _opponents_loaded:
        return
    _opponents_loaded = true
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    if typeof(parsed) != TYPE_ARRAY:
        return
    for item in parsed:
        if typeof(item) == TYPE_DICTIONARY:
            _opponent_cache[str(item.get("name", ""))] = item
