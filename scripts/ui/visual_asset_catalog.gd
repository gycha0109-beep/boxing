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
    "빅토르 코즐로프": "european", "디에고 레예스": "latino",
}
const COUNTRY_BY_NAME := {
    "한도윤": "KR", "서민재": "KR", "장우진": "KR", "박태호": "KR",
    "이준석": "KR", "배성호": "KR", "김성민": "KR", "최현우": "KR",
    "임태건": "KR", "강무진": "KR", "윤재혁": "KR", "나카무라 렌": "JP",
    "미겔 산토스": "MX", "에번 브룩스": "US", "마테오 실바": "BR",
    "빅토르 코즐로프": "RU", "디에고 레예스": "MX",
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
const IDENTITY_ATLAS := "res://assets/visual/v18/fighters/identity_atlas.png"
const UNIQUE_IDENTITY_ROOT := "res://assets/visual/v18/fighters/opponents"
static var _identity_cache: Dictionary = {}

# One source per visual family, shared by portrait, weigh-in and live ring.
# Crop alpha bounds inside the authored cells; never scale the axes separately.
static func identity_fighter_texture(is_player: bool, style_id: String = "") -> Texture2D:
    var column: int = 0 if is_player else {"slugger": 1, "swarmer": 2, "outboxer": 3, "counter": 4}.get(normalize_style(style_id), 1)
    var key := "fighter_%d" % column
    if _identity_cache.has(key): return _identity_cache[key]
    var source := texture(IDENTITY_ATLAS)
    if source == null: return fighter_texture(is_player, style_id, "idle")
    var cell_width := source.get_width() / 5.0
    var cell := Rect2i(int(column * cell_width), 0, int(cell_width), source.get_height())
    # Disregard near-transparent generator dust when choosing framing bounds.
    var cell_image := source.get_image().get_region(cell)
    var first := Vector2i(cell.size.x, cell.size.y)
    var last := Vector2i.ZERO
    for y in range(cell.size.y):
        for x in range(cell.size.x):
            if cell_image.get_pixel(x, y).a > 0.125:
                first = first.min(Vector2i(x, y))
                last = last.max(Vector2i(x, y))
    var used := Rect2i(first, last - first + Vector2i.ONE)
    var atlas := AtlasTexture.new()
    atlas.atlas = source
    atlas.region = Rect2(Vector2(cell.position + used.position), Vector2(used.size))
    _identity_cache[key] = atlas
    return atlas

static func identity_portrait_texture(is_player: bool, style_id: String = "") -> Texture2D:
    var key := "portrait_%s_%s" % [str(is_player), style_id]
    if _identity_cache.has(key): return _identity_cache[key]
    var fighter := identity_fighter_texture(is_player, style_id)
    var portrait := _identity_portrait_from_texture(fighter)
    if portrait == null: return portrait_texture(is_player, style_id)
    _identity_cache[key] = portrait
    return portrait

# Drop a bespoke transparent full-body opponent image at
# assets/visual/v18/fighters/opponents/<opponent-id>.webp. Portrait, weigh-in,
# HUD and live ring then resolve the exact same source by opponent name.
static func opponent_identity_path_for_name(opponent_name: String) -> String:
    _load_opponents()
    var meta: Dictionary = _opponent_cache.get(opponent_name, {})
    var opponent_id := str(meta.get("id", "")).strip_edges()
    if opponent_id.is_empty(): return ""
    return "%s/%s.webp" % [UNIQUE_IDENTITY_ROOT, opponent_id]

static func has_unique_identity_for_name(opponent_name: String) -> bool:
    var path := opponent_identity_path_for_name(opponent_name)
    return not path.is_empty() and ResourceLoader.exists(path)

static func identity_fighter_texture_for_name(opponent_name: String) -> Texture2D:
    var key := "named_fighter_" + opponent_name
    if _identity_cache.has(key): return _identity_cache[key]
    var unique_path := opponent_identity_path_for_name(opponent_name)
    var fighter: Texture2D = null
    if not unique_path.is_empty() and ResourceLoader.exists(unique_path):
        fighter = texture(unique_path)
    if fighter == null:
        fighter = identity_fighter_texture(false, opponent_visual_style_for_name(opponent_name))
    _identity_cache[key] = fighter
    return fighter

static func identity_portrait_texture_for_name(opponent_name: String) -> Texture2D:
    var key := "named_portrait_" + opponent_name
    if _identity_cache.has(key): return _identity_cache[key]
    var fighter := identity_fighter_texture_for_name(opponent_name)
    var portrait := _identity_portrait_from_texture(fighter)
    if portrait == null:
        portrait = identity_portrait_texture(false, opponent_visual_style_for_name(opponent_name))
    _identity_cache[key] = portrait
    return portrait

static func _identity_portrait_from_texture(fighter: Texture2D) -> Texture2D:
    if fighter == null: return null
    var portrait := AtlasTexture.new()
    var region := Rect2()
    if fighter is AtlasTexture:
        var fighter_atlas := fighter as AtlasTexture
        portrait.atlas = fighter_atlas.atlas
        region = fighter_atlas.region
    else:
        portrait.atlas = fighter
        var image := fighter.get_image()
        var used := Rect2i(0, 0, fighter.get_width(), fighter.get_height())
        if image != null:
            var detected := image.get_used_rect()
            if detected.size.x > 0 and detected.size.y > 0: used = detected
        region = Rect2(Vector2(used.position), Vector2(used.size))
    # Tighter head-and-shoulders crop makes the same card footprint read like a portrait.
    region.position.x += region.size.x * 0.10
    region.size.x *= 0.80
    region.size.y *= 0.38
    portrait.region = region
    return portrait

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
    var unique_path := opponent_identity_path_for_name(opponent_name)
    if not unique_path.is_empty() and ResourceLoader.exists(unique_path):
        return unique_path
    var profile: String = opponent_visual_profile_for_name(opponent_name)
    if profile == "korean":
        # Use the exact visual family that FightStage will render. This keeps the
        # contract-board portrait distinct from the player and prevents the
        # portrait/fight person swap that existed in the prototype pipeline.
        return fighter_path(false, opponent_visual_style_for_name(opponent_name), "idle")
    var portrait_style: String = str(PORTRAIT_STYLE_BY_PROFILE.get(profile, "swarmer"))
    return portrait_path(false, portrait_style)

static func opponent_portrait_texture_for_name(opponent_name: String) -> Texture2D:
    if has_unique_identity_for_name(opponent_name):
        return identity_portrait_texture_for_name(opponent_name)
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