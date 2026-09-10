class_name FightStage
extends Control

const BG := Color(0.045, 0.050, 0.065, 1.0)
const RING_FLOOR := Color(0.12, 0.13, 0.16, 1.0)
const ROPE := Color(0.66, 0.19, 0.18, 1.0)
const PLAYER := Color(0.34, 0.66, 0.95, 1.0)
const OPPONENT := Color(0.92, 0.37, 0.31, 1.0)
const SKIN := Color(0.82, 0.70, 0.58, 1.0)
const GLOVE := Color(0.94, 0.94, 0.96, 1.0)
const READ := Color(0.93, 0.71, 0.32, 1.0)
const IMPACT := Color(1.0, 0.88, 0.54, 1.0)
const COUNTER := Color(0.52, 0.88, 0.96, 1.0)

const COMMERCIAL_PLAYER_X := 0.31
const COMMERCIAL_OPPONENT_X := 0.69
const COMMERCIAL_STAND_HEIGHT := 242.0
const COMMERCIAL_COMPACT_HEIGHT := 226.0
const COMMERCIAL_DOWN_HEIGHT := 148.0

var snapshot: Dictionary = {}
var telegraph: Dictionary = {}
var last_exchange: Dictionary = {}
var player_name: String = "PLAYER"
var opponent_name: String = "OPPONENT"
var opponent_style: String = "swarmer"
var title_fight: bool = false

var player_pose: String = "guard"
var opponent_pose: String = "guard"
var last_animation_profile: String = "idle"
var telegraph_action: String = ""
var animation_progress: float = 0.0
var impact_flash: float = 0.0
var presentation_event_id: int = 0
var commercial_assets_active: bool = false
var asset_used_rect_cache: Dictionary = {}

func _ready() -> void:
    name = "FightStage"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(0, 320)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    queue_redraw()

func configure(player_label: String, opponent_label: String, combat_snapshot: Dictionary, opponent_read: Dictionary) -> void:
    player_name = player_label
    opponent_name = opponent_label
    opponent_style = VisualAssetCatalog.opponent_style_for_name(opponent_label)
    title_fight = VisualAssetCatalog.is_title_opponent(opponent_label)
    commercial_assets_active = VisualAssetCatalog.asset_pack_available()
    snapshot = combat_snapshot.duplicate(true)
    telegraph = opponent_read.duplicate(true)
    telegraph_action = str(telegraph.get("action_id", ""))
    if last_exchange.is_empty():
        player_pose = "guard"
        opponent_pose = _telegraph_pose(telegraph_action)
    queue_redraw()

func play_exchange(exchange: Dictionary) -> void:
    if exchange.is_empty():
        return
    last_exchange = exchange.duplicate(true)
    presentation_event_id += 1
    last_animation_profile = ImpactFeedback.profile(exchange)
    player_pose = _pose_for_action(str(exchange.get("player_action", "guard")))
    opponent_pose = _pose_for_action(str(exchange.get("opponent_action", "guard")))
    var player_event: Dictionary = exchange.get("player_event", {})
    var opponent_event: Dictionary = exchange.get("opponent_event", {})
    if bool(player_event.get("knockout", false)):
        opponent_pose = "down"
    elif bool(opponent_event.get("knockout", false)):
        player_pose = "down"
    else:
        if bool(player_event.get("hit", false)): opponent_pose = "hurt"
        if bool(opponent_event.get("hit", false)): player_pose = "hurt"
    impact_flash = 1.0 if last_animation_profile in ["heavy", "counter", "knockdown"] else 0.55
    animation_progress = 0.0
    queue_redraw()
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_method(Callable(self, "_set_animation_progress"), 0.0, 1.0, 0.10)
    tween.tween_method(Callable(self, "_set_animation_progress"), 1.0, 0.0, 0.18)
    tween.parallel().tween_method(Callable(self, "_set_impact_flash"), impact_flash, 0.0, 0.24)

func _set_animation_progress(value: float) -> void:
    animation_progress = value
    queue_redraw()
func _set_impact_flash(value: float) -> void:
    impact_flash = value
    queue_redraw()

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    if w < 80.0: return
    var arena_texture := VisualAssetCatalog.arena_texture(title_fight)
    if arena_texture != null:
        var source_size := arena_texture.get_size()
        var scale_factor := maxf(w / source_size.x, h / source_size.y)
        var crop_size := Vector2(w, h) / scale_factor
        # Exclude the title arena's foreground apron: boots belong on the canvas.
        var bottom_inset := 180.0 if title_fight else 60.0
        var crop_origin := Vector2((source_size.x - crop_size.x) * 0.5, maxf(0, source_size.y - crop_size.y - bottom_inset))
        draw_texture_rect_region(arena_texture, Rect2(0, 0, w, h), Rect2(crop_origin, crop_size), Color(0.65, 0.67, 0.72, 1.0))
    else: _draw_procedural_arena(w, h)
    var player_x: float = COMMERCIAL_PLAYER_X if commercial_assets_active else 0.32
    var opponent_x: float = COMMERCIAL_OPPONENT_X if commercial_assets_active else 0.68
    var player_center := Vector2(w * player_x, h - 18.0) + _fighter_motion(true)
    var opponent_center := Vector2(w * opponent_x, h - 18.0) + _fighter_motion(false)
    _draw_fighter_asset_or_fallback(player_center, 1.0, true, "", PLAYER, player_pose)
    _draw_fighter_asset_or_fallback(opponent_center, -1.0, false, opponent_style, OPPONENT, opponent_pose)
    if not telegraph_action.is_empty():
        var read_offset := _identity_height(false, opponent_style) + 12.0
        var read_center := opponent_center + Vector2(0.0, -read_offset)
        var pulse: float = 1.0 + 0.12 * sin(Time.get_ticks_msec() / 140.0)
        draw_arc(read_center, 14.0 * pulse, 0.0, TAU, 28, READ, 2.0)
        draw_circle(read_center, 4.0, READ)
    if not last_exchange.is_empty() and impact_flash > 0.01:
        var impact_center := (player_center + opponent_center) * 0.5
        if bool(last_exchange.get("player_event", {}).get("hit", false)):
            impact_center = _commercial_impact_center(opponent_center, opponent_pose, str(last_exchange.get("player_action", "")), -1.0) if commercial_assets_active else opponent_center + Vector2(-22.0, -62.0)
        elif bool(last_exchange.get("opponent_event", {}).get("hit", false)):
            impact_center = _commercial_impact_center(player_center, player_pose, str(last_exchange.get("opponent_action", "")), 1.0) if commercial_assets_active else player_center + Vector2(22.0, -62.0)
        var fx_texture := VisualAssetCatalog.fx_texture(last_exchange)
        if fx_texture != null:
            var fx_size := 92.0 + 52.0 * impact_flash
            var fx_rect := Rect2(impact_center - Vector2(fx_size, fx_size) * 0.5, Vector2(fx_size, fx_size))
            draw_texture_rect(fx_texture, fx_rect, false, Color(1.0, 1.0, 1.0, clamp(impact_flash, 0.0, 1.0)))
        else: _draw_procedural_impact(impact_center)

func _draw_procedural_arena(w: float, h: float) -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), BG, true)
    var floor_rect := Rect2(Vector2(12.0, h * 0.48), Vector2(w - 24.0, h * 0.40))
    draw_rect(floor_rect, RING_FLOOR, true)
    for y in [h * 0.28, h * 0.39, h * 0.50]: draw_line(Vector2(10.0, y), Vector2(w - 10.0, y), ROPE, 2.0)
    draw_line(Vector2(14.0, h * 0.22), Vector2(14.0, h * 0.88), Color(0.75, 0.76, 0.80), 4.0)
    draw_line(Vector2(w - 14.0, h * 0.22), Vector2(w - 14.0, h * 0.88), Color(0.75, 0.76, 0.80), 4.0)

func _draw_fighter_asset_or_fallback(center: Vector2, facing: float, is_player: bool, style_id: String, tint: Color, pose: String) -> void:
    var texture := VisualAssetCatalog.identity_fighter_texture(true, style_id) if is_player else VisualAssetCatalog.identity_fighter_texture_for_name(opponent_name)
    if texture == null: _draw_fighter(center, facing, tint, pose); return
    var source_rect := _texture_used_rect(texture)
    if source_rect.size.x <= 0 or source_rect.size.y <= 0: _draw_fighter(center, facing, tint, pose); return
    var target_height := _identity_height(is_player, style_id)
    if pose == "down":
        _draw_articulated_knockdown(texture, source_rect, center, facing, target_height)
        return
    var target_width := target_height * float(source_rect.size.x) / float(source_rect.size.y)
    var destination_rect := Rect2(-target_width * 0.5, -target_height, target_width, target_height)
    var angle := -facing * 0.06 * animation_progress if pose == "hurt" else 0.0
    var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
    for point in [destination_rect.position, Vector2(destination_rect.end.x, destination_rect.position.y), destination_rect.end, Vector2(destination_rect.position.x, destination_rect.end.y)]:
        bounds = bounds.expand((point * Vector2(facing, 1.0)).rotated(angle))
    var origin := Vector2(clampf(center.x, 8.0 - bounds.position.x, size.x - 8.0 - bounds.end.x), size.y - 18.0 - bounds.end.y)
    # Sole positions in the shared atlas; the forward boot sits slightly higher.
    for sole in [Vector2(-0.40, -0.005), Vector2(0.36, -0.025)]:
        var contact := origin + (Vector2(sole.x * target_width * facing, sole.y * target_height)).rotated(angle)
        draw_set_transform(contact, 0, Vector2(1, 0.20))
        draw_circle(Vector2.ZERO, target_width * 0.105, Color(0, 0, 0, 0.42))
    draw_set_transform(origin, angle, Vector2(facing, 1.0))
    draw_texture_rect_region(texture, destination_rect, Rect2(Vector2(source_rect.position), Vector2(source_rect.size)), Color.WHITE, false, true)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_articulated_knockdown(texture: Texture2D, source_rect: Rect2i, center: Vector2, facing: float, standing_height: float) -> void:
    # Keep the exact fighter identity, but bend the body at the hips instead of
    # rotating the entire standing sprite like a cardboard cut-out.
    var split_y := clampi(int(round(source_rect.size.y * 0.58)), 1, source_rect.size.y - 1)
    var overlap_px := mini(4, split_y - 1)
    var upper_source := Rect2(
        Vector2(source_rect.position),
        Vector2(source_rect.size.x, split_y + overlap_px)
    )
    var lower_source := Rect2(
        Vector2(source_rect.position.x, source_rect.position.y + split_y - overlap_px),
        Vector2(source_rect.size.x, source_rect.size.y - split_y + overlap_px)
    )
    var down_length := minf(size.x * 0.43, standing_height * 0.76)
    var upper_length := down_length * 0.62
    var lower_length := down_length * 0.48
    var upper_width := upper_length * upper_source.size.x / maxf(1.0, upper_source.size.y)
    var lower_width := lower_length * lower_source.size.x / maxf(1.0, lower_source.size.y)
    var upper_rect := Rect2(-upper_width * 0.50, -upper_length + 3.0, upper_width, upper_length)
    var lower_rect := Rect2(-lower_width * 0.48, -2.0, lower_width, lower_length)
    var upper_angle := -facing * PI * 0.38
    var lower_angle := -facing * PI * 0.17

    var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
    for point in [upper_rect.position, Vector2(upper_rect.end.x, upper_rect.position.y), upper_rect.end, Vector2(upper_rect.position.x, upper_rect.end.y)]:
        bounds = bounds.expand((point * Vector2(facing, 1.0)).rotated(upper_angle))
    for point in [lower_rect.position, Vector2(lower_rect.end.x, lower_rect.position.y), lower_rect.end, Vector2(lower_rect.position.x, lower_rect.end.y)]:
        bounds = bounds.expand((point * Vector2(facing, 1.0)).rotated(lower_angle))

    var hip := Vector2(
        clampf(center.x, 10.0 - bounds.position.x, size.x - 10.0 - bounds.end.x),
        size.y - 18.0 - bounds.end.y
    )
    draw_set_transform(Vector2(hip.x + bounds.get_center().x, size.y - 18.5), 0.0, Vector2(1.0, 0.12))
    draw_circle(Vector2.ZERO, maxf(34.0, bounds.size.x * 0.46), Color(0, 0, 0, 0.30))

    # Legs first, torso second: the small overlap hides the hip seam and leaves
    # the head/gloves readable above the canvas instead of clipping into it.
    draw_set_transform(hip, lower_angle, Vector2(facing, 1.0))
    draw_texture_rect_region(texture, lower_rect, lower_source, Color.WHITE, false, true)
    draw_set_transform(hip, upper_angle, Vector2(facing, 1.0))
    draw_texture_rect_region(texture, upper_rect, upper_source, Color.WHITE, false, true)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _identity_height(is_player: bool, style_id: String) -> float:
    var texture := VisualAssetCatalog.identity_fighter_texture(true, style_id) if is_player else VisualAssetCatalog.identity_fighter_texture_for_name(opponent_name)
    if texture == null: return COMMERCIAL_STAND_HEIGHT
    var source := _texture_used_rect(texture)
    return minf(size.y - 42.0, (size.x * 0.42 - 24.0) * float(source.size.y) / maxf(1.0, float(source.size.x)))

func _texture_used_rect(texture: Texture2D) -> Rect2i:
    var key := texture.resource_path
    if key.is_empty(): key = str(texture.get_instance_id())
    if asset_used_rect_cache.has(key): return asset_used_rect_cache[key]
    var image := texture.get_image()
    var used := Rect2i(0, 0, texture.get_width(), texture.get_height())
    if image != null:
        var detected := image.get_used_rect()
        if detected.size.x > 0 and detected.size.y > 0: used = detected
    asset_used_rect_cache[key] = used
    return used

func _commercial_pose_height(pose: String) -> float:
    match pose:
        "down": return COMMERCIAL_DOWN_HEIGHT
        "body", "hurt": return COMMERCIAL_COMPACT_HEIGHT
        _: return COMMERCIAL_STAND_HEIGHT
func _commercial_impact_center(center: Vector2, pose: String, action_id: String, horizontal_sign: float) -> Vector2:
    var visual_height := _identity_height(horizontal_sign > 0.0, "" if horizontal_sign > 0.0 else opponent_style)
    if pose == "down": visual_height *= 0.45
    return center + Vector2(14.0 * horizontal_sign, -visual_height * (0.50 if action_id == "body" else 0.72))
func _draw_procedural_impact(impact_center: Vector2) -> void:
    var flash_color := COUNTER if last_animation_profile == "counter" else IMPACT
    flash_color.a = clamp(impact_flash, 0.0, 1.0)
    draw_circle(impact_center, 16.0 + 18.0 * impact_flash, flash_color)
    draw_line(impact_center + Vector2(-28, 0), impact_center + Vector2(28, 0), flash_color, 3.0)
    draw_line(impact_center + Vector2(0, -28), impact_center + Vector2(0, 28), flash_color, 3.0)
    if last_animation_profile in ["counter", "knockdown"]:
        draw_line(impact_center + Vector2(-20, -20), impact_center + Vector2(20, 20), flash_color, 3.0)
        draw_line(impact_center + Vector2(-20, 20), impact_center + Vector2(20, -20), flash_color, 3.0)
func _fighter_motion(is_player: bool) -> Vector2:
    if last_exchange.is_empty() or animation_progress <= 0.0: return Vector2.ZERO
    var direction: float = 1.0 if is_player else -1.0
    var action_id: String = str(last_exchange.get("player_action" if is_player else "opponent_action", ""))
    var event: Dictionary = last_exchange.get("player_event" if is_player else "opponent_event", {})
    var target_event: Dictionary = last_exchange.get("opponent_event" if is_player else "player_event", {})
    var offset := Vector2.ZERO
    if action_id in ["jab", "power", "body", "counter"]:
        var lunge: float = 14.0
        if action_id == "power": lunge = 22.0
        elif action_id == "body": lunge = 16.0
        elif action_id == "counter": lunge = 18.0
        offset.x += direction * lunge * animation_progress
    if bool(target_event.get("hit", false)): offset.x -= direction * 7.0 * animation_progress; offset.y += 3.0 * animation_progress
    if bool(event.get("knockout", false)): offset.x += direction * 5.0 * animation_progress
    return offset

func _draw_fighter(center: Vector2, facing: float, tint: Color, pose: String) -> void:
    if pose == "down":
        draw_circle(center + Vector2(-10.0 * facing, -14.0), 12.0, SKIN)
        draw_line(center + Vector2(-2.0 * facing, -12.0), center + Vector2(34.0 * facing, -4.0), tint, 14.0)
        draw_line(center + Vector2(18.0 * facing, -8.0), center + Vector2(42.0 * facing, 10.0), tint, 8.0)
        draw_circle(center + Vector2(42.0 * facing, 10.0), 7.0, GLOVE)
        return
    var hurt_shift := Vector2(-7.0 * facing, 4.0) if pose == "hurt" else Vector2.ZERO
    var hip := center + hurt_shift
    var chest := hip + Vector2(0.0, -54.0)
    var head := chest + Vector2(0.0, -31.0)
    var shoulder := chest + Vector2(5.0 * facing, -2.0)
    var rear_shoulder := chest + Vector2(-5.0 * facing, 2.0)
    draw_line(hip, chest, tint, 18.0)
    draw_circle(head, 13.0, SKIN)
    draw_line(hip, hip + Vector2(-14.0, 38.0), tint, 9.0)
    draw_line(hip, hip + Vector2(15.0, 38.0), tint, 9.0)
    var lead_glove := shoulder + Vector2(15.0 * facing, -4.0)
    var rear_glove := rear_shoulder + Vector2(11.0 * facing, 7.0)
    match pose:
        "jab": lead_glove = shoulder + Vector2(43.0 * facing, -4.0); rear_glove = head + Vector2(-7.0 * facing, 7.0)
        "power": lead_glove = head + Vector2(7.0 * facing, 8.0); rear_glove = rear_shoulder + Vector2(50.0 * facing, 4.0)
        "body": lead_glove = shoulder + Vector2(29.0 * facing, 20.0); rear_glove = head + Vector2(-5.0 * facing, 8.0)
        "counter": lead_glove = head + Vector2(7.0 * facing, 4.0); rear_glove = rear_shoulder + Vector2(38.0 * facing, -8.0)
        "hurt": lead_glove = head + Vector2(9.0 * facing, 12.0); rear_glove = head + Vector2(-8.0 * facing, 12.0)
        _: lead_glove = head + Vector2(10.0 * facing, 11.0); rear_glove = head + Vector2(-8.0 * facing, 12.0)
    draw_line(shoulder, lead_glove, tint, 8.0)
    draw_line(rear_shoulder, rear_glove, tint, 8.0)
    draw_circle(lead_glove, 8.0, GLOVE)
    draw_circle(rear_glove, 8.0, GLOVE)
func _pose_for_action(action_id: String) -> String:
    match action_id:
        "jab": return "jab"
        "power": return "power"
        "body": return "body"
        "counter": return "counter"
        "guard": return "guard"
        _: return "guard"
func _telegraph_pose(action_id: String) -> String:
    match action_id:
        "power": return "power"
        "body": return "body"
        "counter": return "counter"
        _: return "guard"
