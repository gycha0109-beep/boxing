extends Node

# v19.1 layout polish only. This node does not introduce or generate image assets;
# it tightens the existing v19 tactical hierarchy and gives live combat more ring area.
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
    _polish_tactical_preparation()
    _polish_fight_surface()

func _polish_tactical_preparation() -> void:
    var matchup := _main.find_child("V19TacticalMatchup", true, false) as PanelContainer
    if is_instance_valid(matchup) and not matchup.has_meta("v19_1_compact"):
        var matchup_style := _main.call("_v17_box_style", Color("071019"), Color("253242"), 7, 7) as StyleBoxFlat
        if is_instance_valid(matchup_style):
            matchup.add_theme_stylebox_override("panel", matchup_style)
        var portraits := matchup.find_children("*", "TextureRect", true, false)
        if not portraits.is_empty():
            var portrait := portraits[0] as TextureRect
            if is_instance_valid(portrait):
                portrait.custom_minimum_size = Vector2(82, 104)
        var matchup_rows := matchup.find_children("*", "HBoxContainer", true, false)
        if not matchup_rows.is_empty():
            var matchup_row := matchup_rows[0] as HBoxContainer
            if is_instance_valid(matchup_row):
                matchup_row.add_theme_constant_override("separation", 10)
        matchup.set_meta("v19_1_compact", true)

    var tactic_nodes := _main.find_children("V19Tactic_*", "PanelContainer", true, false)
    if tactic_nodes.is_empty():
        return

    var list := _main.find_child("V19TacticalList", true, false) as GridContainer
    if not is_instance_valid(list):
        var body := _main.get("body") as Container
        if not is_instance_valid(body):
            return
        list = GridContainer.new()
        list.name = "V19TacticalList"
        list.columns = 1
        list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        list.add_theme_constant_override("v_separation", 5)
        var insert_index := (tactic_nodes[0] as Node).get_index()
        body.add_child(list)
        body.move_child(list, insert_index)
        for tactic_node in tactic_nodes:
            (tactic_node as Node).reparent(list)

    for panel_node in list.get_children():
        var panel := panel_node as PanelContainer
        if not is_instance_valid(panel) or panel.has_meta("v19_1_compact"):
            continue
        var panel_style := _main.call("_v17_box_style", Color("071019"), Color("1d2b3a"), 6, 5) as StyleBoxFlat
        if is_instance_valid(panel_style):
            panel.add_theme_stylebox_override("panel", panel_style)
        if panel.get_child_count() > 0:
            var row := panel.get_child(0) as HBoxContainer
            if is_instance_valid(row):
                row.add_theme_constant_override("separation", 7)
                for child in row.get_children():
                    if child is Label:
                        var number := child as Label
                        number.custom_minimum_size.x = 22
                        number.add_theme_font_size_override("font_size", 11)
                    elif child is VBoxContainer:
                        var labels := child.find_children("*", "Label", true, false)
                        if labels.size() > 0:
                            (labels[0] as Label).add_theme_font_size_override("font_size", 14)
                        if labels.size() > 1:
                            (labels[1] as Label).add_theme_font_size_override("font_size", 10)
                        if labels.size() > 2:
                            (labels[2] as Label).add_theme_font_size_override("font_size", 9)
                    elif child is Button:
                        var choose := child as Button
                        choose.custom_minimum_size = Vector2(58, 56)
                        choose.add_theme_font_size_override("font_size", 11)
        panel.set_meta("v19_1_compact", true)

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
