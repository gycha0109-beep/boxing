class_name FightFxDirector
extends Node

var last_profile: String = "idle"
var last_hit_stop_seconds: float = 0.0
var last_shake_strength: float = 0.0
var last_shake_duration: float = 0.0
var presentation_event_id: int = 0
var shake_tween: Tween

func trigger(stage: FightStage, exchange: Dictionary) -> void:
    last_profile = ImpactFeedback.profile(exchange)
    last_hit_stop_seconds = ImpactFeedback.hit_stop_seconds(last_profile)
    last_shake_strength = ImpactFeedback.shake_strength(last_profile)
    last_shake_duration = shake_duration_seconds(last_profile)
    presentation_event_id += 1
    if not is_instance_valid(stage):
        return
    if last_hit_stop_seconds > 0.0:
        _apply_hit_stop(stage, presentation_event_id)
    if last_shake_strength > 0.0:
        _apply_screen_shake(stage, last_shake_strength, last_shake_duration)

func _apply_hit_stop(stage: FightStage, event_id: int) -> void:
    var previous_mode: int = stage.process_mode
    stage.process_mode = Node.PROCESS_MODE_DISABLED
    var timer := get_tree().create_timer(last_hit_stop_seconds, true, false, true)
    var stage_ref: WeakRef = weakref(stage)
    timer.timeout.connect(func() -> void:
        var live_stage: FightStage = stage_ref.get_ref()
        if event_id == presentation_event_id and is_instance_valid(live_stage):
            live_stage.process_mode = previous_mode
    )

func _apply_screen_shake(stage: FightStage, strength: float, duration: float) -> void:
    if is_instance_valid(shake_tween):
        shake_tween.kill()
    var base_position: Vector2 = stage.position
    shake_tween = stage.create_tween()
    var stage_ref: WeakRef = weakref(stage)
    shake_tween.set_trans(Tween.TRANS_SINE)
    shake_tween.set_ease(Tween.EASE_OUT)
    shake_tween.tween_method(func(progress: float) -> void:
        var live_stage: FightStage = stage_ref.get_ref()
        if not is_instance_valid(live_stage):
            return
        var decay: float = 1.0 - progress
        var phase: float = progress * TAU * 4.0
        live_stage.position = base_position + Vector2(sin(phase), cos(phase * 1.37)) * strength * decay
    , 0.0, 1.0, duration)
    shake_tween.tween_callback(func() -> void:
        var live_stage: FightStage = stage_ref.get_ref()
        if is_instance_valid(live_stage):
            live_stage.position = base_position
    )

static func shake_duration_seconds(profile_id: String) -> float:
    match profile_id:
        "medium": return 0.10
        "heavy": return 0.14
        "counter": return 0.16
        "knockdown": return 0.22
        _: return 0.0

static func interaction_lock_seconds(exchange: Dictionary) -> float:
    var profile_id: String = ImpactFeedback.profile(exchange)
    return 0.28 + ImpactFeedback.hit_stop_seconds(profile_id) + shake_duration_seconds(profile_id) * 0.25
