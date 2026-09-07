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

var snapshot: Dictionary = {}
var telegraph: Dictionary = {}
var last_exchange: Dictionary = {}
var player_name: String = "PLAYER"
var opponent_name: String = "OPPONENT"

var player_pose: String = "guard"
var opponent_pose: String = "guard"
var last_animation_profile: String = "idle"
var telegraph_action: String = ""
var animation_progress: float = 0.0
var impact_flash: float = 0.0
var presentation_event_id: int = 0

func _ready() -> void:
    name = "FightStage"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(0, 250)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    queue_redraw()

func configure(player_label: String, opponent_label: String, combat_snapshot: Dictionary, opponent_read: Dictionary) -> void:
    player_name = player_label
    opponent_name = opponent_label
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
        if bool(player_event.get("hit", false)):
            opponent_pose = "hurt"
        if bool(opponent_event.get("hit", false)):
            player_pose = "hurt"

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
    var h: float = max(size.y, 250.0)
    if w < 80.0:
        return

    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), BG, true)
    var floor_rect := Rect2(Vector2(12.0, h * 0.48), Vector2(w - 24.0, h * 0.40))
    draw_rect(floor_rect, RING_FLOOR, true)

    var rope_y := [h * 0.28, h * 0.39, h * 0.50]
    for y in rope_y:
        draw_line(Vector2(10.0, y), Vector2(w - 10.0, y), ROPE, 2.0)
    draw_line(Vector2(14.0, h * 0.22), Vector2(14.0, h * 0.88), Color(0.75, 0.76, 0.80), 4.0)
    draw_line(Vector2(w - 14.0, h * 0.22), Vector2(w - 14.0, h * 0.88), Color(0.75, 0.76, 0.80), 4.0)

    var player_center := Vector2(w * 0.32, h * 0.78) + _fighter_motion(true)
    var opponent_center := Vector2(w * 0.68, h * 0.78) + _fighter_motion(false)
    _draw_fighter(player_center, 1.0, PLAYER, player_pose)
    _draw_fighter(opponent_center, -1.0, OPPONENT, opponent_pose)

    if not telegraph_action.is_empty():
        var read_center := opponent_center + Vector2(0.0, -116.0)
        var pulse: float = 1.0 + 0.12 * sin(Time.get_ticks_msec() / 140.0)
        draw_arc(read_center, 14.0 * pulse, 0.0, TAU, 28, READ, 2.0)
        draw_circle(read_center, 4.0, READ)

    if not last_exchange.is_empty() and impact_flash > 0.01:
        var impact_center := (player_center + opponent_center) * 0.5
        if bool(last_exchange.get("player_event", {}).get("hit", false)):
            impact_center = opponent_center + Vector2(-22.0, -58.0)
        elif bool(last_exchange.get("opponent_event", {}).get("hit", false)):
            impact_center = player_center + Vector2(22.0, -58.0)
        var flash_color := COUNTER if last_animation_profile == "counter" else IMPACT
        flash_color.a = clamp(impact_flash, 0.0, 1.0)
        draw_circle(impact_center, 16.0 + 18.0 * impact_flash, flash_color)
        draw_line(impact_center + Vector2(-28, 0), impact_center + Vector2(28, 0), flash_color, 3.0)
        draw_line(impact_center + Vector2(0, -28), impact_center + Vector2(0, 28), flash_color, 3.0)
        if last_animation_profile in ["counter", "knockdown"]:
            draw_line(impact_center + Vector2(-20, -20), impact_center + Vector2(20, 20), flash_color, 3.0)
            draw_line(impact_center + Vector2(-20, 20), impact_center + Vector2(20, -20), flash_color, 3.0)

func _fighter_motion(is_player: bool) -> Vector2:
    if last_exchange.is_empty() or animation_progress <= 0.0:
        return Vector2.ZERO
    var direction: float = 1.0 if is_player else -1.0
    var action_id: String = str(last_exchange.get("player_action" if is_player else "opponent_action", ""))
    var event: Dictionary = last_exchange.get("player_event" if is_player else "opponent_event", {})
    var target_event: Dictionary = last_exchange.get("opponent_event" if is_player else "player_event", {})
    var offset := Vector2.ZERO
    if action_id in ["jab", "power", "body", "counter"]:
        var lunge: float = 8.0
        if action_id == "power":
            lunge = 15.0
        elif action_id == "counter":
            lunge = 12.0
        offset.x += direction * lunge * animation_progress
    if bool(target_event.get("hit", false)):
        offset.x -= direction * 10.0 * animation_progress
        offset.y += 3.0 * animation_progress
    if bool(event.get("knockout", false)):
        offset.x += direction * 5.0 * animation_progress
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
        "jab":
            lead_glove = shoulder + Vector2(43.0 * facing, -4.0)
            rear_glove = head + Vector2(-7.0 * facing, 7.0)
        "power":
            lead_glove = head + Vector2(7.0 * facing, 8.0)
            rear_glove = rear_shoulder + Vector2(50.0 * facing, 4.0)
        "body":
            lead_glove = shoulder + Vector2(29.0 * facing, 20.0)
            rear_glove = head + Vector2(-5.0 * facing, 8.0)
        "counter":
            lead_glove = head + Vector2(7.0 * facing, 4.0)
            rear_glove = rear_shoulder + Vector2(38.0 * facing, -8.0)
        "hurt":
            lead_glove = head + Vector2(9.0 * facing, 12.0)
            rear_glove = head + Vector2(-8.0 * facing, 12.0)
        _:
            lead_glove = head + Vector2(10.0 * facing, 11.0)
            rear_glove = head + Vector2(-8.0 * facing, 12.0)

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
