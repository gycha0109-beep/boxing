extends Node

# Compact the existing fight controls so the ring remains visible.
var _main: Node

func _ready() -> void:
    _main = get_parent()
    process_priority = 100
    set_process(true)
    call_deferred("_apply_polish")

func _process(_delta: float) -> void:
    _apply_polish()

func _apply_polish() -> void:
    if not is_instance_valid(_main):
        return
    _polish_fight_surface()

func _polish_fight_surface() -> void:
    var stage := _main.find_child("FightStage", true, false) as Control
    if is_instance_valid(stage) and not stage.has_meta("v19_1_stage"):
        stage.custom_minimum_size.y = 360
        stage.set_meta("v19_1_stage", true)

    var read_panel := _main.find_child("V19TacticalRead", true, false) as PanelContainer
    if is_instance_valid(read_panel) and not read_panel.has_meta("v19_1_compact"):
        var read_style := _main.call("_v17_box_style", Color("06101a"), Color("27384a"), 5, 5) as StyleBoxFlat
        if is_instance_valid(read_style):
            read_style.border_width_left = 3
            read_style.border_color = Color("b78a43")
            read_panel.add_theme_stylebox_override("panel", read_style)
        read_panel.set_meta("v19_1_compact", true)

    var action_wrap := _main.find_child("V19FightActions", true, false) as VBoxContainer
    if is_instance_valid(action_wrap) and not action_wrap.has_meta("v19_1_compact"):
        action_wrap.add_theme_constant_override("separation", 5)
        action_wrap.set_meta("v19_1_compact", true)
