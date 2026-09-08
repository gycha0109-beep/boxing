extends "res://scripts/main_v05.gd"

const MIN_TOUCH_TARGET := 56.0

var arena_audio: ArenaAudio
var fight_fx: FightFxDirector
var safe_insets: Dictionary = SafeAreaLayout.zero_insets()
var lifecycle_pause_saves: int = 0
var lifecycle_resumes: int = 0
var fight_input_locked: bool = false

func _ready() -> void:
    super._ready()
    _apply_safe_area()
    var resize_callback := Callable(self, "_apply_safe_area")
    if not get_viewport().size_changed.is_connected(resize_callback):
        get_viewport().size_changed.connect(resize_callback)
    _post_layout_polish()

func _render_phase() -> void:
    super._render_phase()
    call_deferred("_post_layout_polish")

func _start_fight() -> void:
    _arena().start_fight()
    super._start_fight()
    call_deferred("_post_layout_polish")

func _choose_fight_action(action: String) -> void:
    if fight_input_locked:
        return
    var before_round: int = int(combat.snapshot().round)
    var resolved: Dictionary = combat.resolve_exchange(action)
    var exchange: Dictionary = resolved.get("exchange_result", {})
    GameState.save_active_fight(combat.export_state())
    _impact().trigger(exchange)
    _arena().react(exchange)
    var after: Dictionary = combat.snapshot()
    var after_round: int = int(after.round)
    if bool(after.finished):
        _arena().finish_fight()
    elif after_round != before_round:
        _arena().round_break(after_round)
    _render_fight(exchange)
    var stage: FightStage = _find_fight_stage(body)
    if stage != null:
        _fx().trigger(stage, exchange)
    if not bool(after.finished):
        _lock_fight_input(exchange)
    call_deferred("_post_layout_polish")

func _lock_fight_input(exchange: Dictionary) -> void:
    fight_input_locked = true
    for button in _buttons_under(body):
        button.disabled = true
    var duration: float = FightFxDirector.interaction_lock_seconds(exchange)
    get_tree().create_timer(duration).timeout.connect(Callable(self, "_unlock_fight_input"))

func _unlock_fight_input() -> void:
    fight_input_locked = false
    if not is_instance_valid(body):
        return
    for button in _buttons_under(body):
        button.disabled = false

func _post_layout_polish() -> void:
    _apply_safe_area()
    _enforce_touch_targets()

func _apply_safe_area() -> void:
    if not is_inside_tree():
        return
    safe_insets = SafeAreaLayout.current_insets(get_viewport_rect().size)
    var margin := _shell_margin()
    if margin == null:
        return
    margin.add_theme_constant_override("margin_left", int(ceil(18.0 + float(safe_insets.left))))
    margin.add_theme_constant_override("margin_right", int(ceil(18.0 + float(safe_insets.right))))
    margin.add_theme_constant_override("margin_top", int(ceil(22.0 + float(safe_insets.top))))
    margin.add_theme_constant_override("margin_bottom", int(ceil(20.0 + float(safe_insets.bottom))))

func _shell_margin() -> MarginContainer:
    for child in get_children():
        if child is MarginContainer:
            return child as MarginContainer
    return null

func _enforce_touch_targets() -> void:
    if not is_instance_valid(body):
        return
    for button in _buttons_under(body):
        button.custom_minimum_size.y = max(button.custom_minimum_size.y, MIN_TOUCH_TARGET)

func _buttons_under(node: Node) -> Array[Button]:
    var result: Array[Button] = []
    if node == null:
        return result
    for child in node.get_children():
        if child is Button:
            result.append(child as Button)
        result.append_array(_buttons_under(child))
    return result

func _find_fight_stage(node: Node) -> FightStage:
    if node == null:
        return null
    for child in node.get_children():
        if child is FightStage:
            return child as FightStage
        var nested: FightStage = _find_fight_stage(child)
        if nested != null:
            return nested
    return null

func _notification(what: int) -> void:
    if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
        lifecycle_pause_saves += 1
        _persist_for_suspend()
        if is_instance_valid(arena_audio):
            arena_audio.set_suspended(true)
    elif what == MainLoop.NOTIFICATION_APPLICATION_RESUMED:
        lifecycle_resumes += 1
        if is_instance_valid(arena_audio):
            arena_audio.set_suspended(false)
        call_deferred("_post_layout_polish")

func _persist_for_suspend() -> void:
    if combat != null and str(GameState.state.phase) == "fight":
        GameState.save_active_fight(combat.export_state())
    else:
        SaveService.save_game(GameState.state)

func _arena() -> ArenaAudio:
    if is_instance_valid(arena_audio):
        return arena_audio
    arena_audio = ArenaAudio.new()
    arena_audio.name = "ArenaAudio"
    add_child(arena_audio)
    return arena_audio

func _fx() -> FightFxDirector:
    if is_instance_valid(fight_fx):
        return fight_fx
    fight_fx = FightFxDirector.new()
    fight_fx.name = "FightFxDirector"
    add_child(fight_fx)
    return fight_fx
