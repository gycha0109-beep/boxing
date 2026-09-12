extends Node

# v19.1 layout polish plus v1.3 persistent-world/career-risk surfaces.
# This node does not introduce or generate image assets.
var _main: Node
var _world_signature: String = ""

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
    _sync_world_opponents()
    _sync_current_world_opponent()
    _polish_tactical_preparation()
    _polish_fight_surface()
    _polish_world_career()
    _polish_world_matchup_read()

func _content_width() -> float:
    if _main is Control:
        return maxf(0.0, (_main as Control).size.x - 24.0)
    return 0.0

func _sync_world_opponents() -> void:
    if not GameState.has_method("world_summary") or not GameState.has_method("world_opponent_definition"):
        return
    var summary: Dictionary = GameState.world_summary()
    var signature: String = "%d:%d:%s" % [int(summary.get("year", 0)), int(summary.get("month", 0)), str(summary.get("champion_boxer_id", ""))]
    if signature == _world_signature:
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    if typeof(parsed) != TYPE_ARRAY:
        return
    var decorated: Array = []
    for value in parsed:
        var opponent: Dictionary = value
        decorated.append(GameState.world_opponent_definition(opponent))
    _main.set("opponents", decorated)
    _world_signature = signature

func _sync_current_world_opponent() -> void:
    var current_value: Variant = _main.get("current_opponent")
    if typeof(current_value) != TYPE_DICTIONARY:
        return
    var current: Dictionary = current_value
    var opponent_id: String = str(current.get("id", ""))
    if opponent_id.is_empty():
        return
    var values: Variant = _main.get("opponents")
    if typeof(values) != TYPE_ARRAY:
        return
    for value in values:
        var opponent: Dictionary = value
        if str(opponent.get("id", "")) == opponent_id:
            _main.set("current_opponent", opponent.duplicate(true))
            return

func _polish_world_career() -> void:
    if not GameState.has_method("world_summary") or str(_main.get("v17_overlay")) != "career":
        return
    var body := _main.get("body") as Container
    if not is_instance_valid(body) or is_instance_valid(_main.find_child("V13WorldPersistencePanel", true, false)):
        return
    var summary: Dictionary = GameState.world_summary()
    var world_panel := _main.call("_v17_panel", body, false) as VBoxContainer
    if not is_instance_valid(world_panel):
        return
    world_panel.name = "V13WorldPersistencePanel"
    _main.call("_v17_eyebrow", world_panel, "PERSISTENT WORLD")
    _main.call("_v17_title", world_panel, "복싱 세계 · %04d.%02d" % [int(summary.get("year", 2030)), int(summary.get("month", 1))], 20)
    _main.call("_v17_copy", world_panel, "WORLD CHAMPION · %s" % str(summary.get("champion_name", "타이틀 공석")), false)
    var record: Dictionary = summary.get("champion_record", {})
    if int(summary.get("champion_age", 0)) > 0:
        _main.call("_v17_copy", world_panel, "%d세 · %d-%d-%d · %d차 방어" % [int(summary.get("champion_age", 0)), int(record.get("wins", 0)), int(record.get("losses", 0)), int(record.get("draws", 0)), int(summary.get("title_defenses", 0))], true)
    var gym_id: String = str(summary.get("gym_id", ""))
    if not gym_id.is_empty():
        _main.call("_v17_copy", world_panel, "GYM · %s" % gym_id.to_upper().replace("_", " "), true)
    var damage: int = int(GameState.career_damage_value())
    var risk_panel := _main.call("_v17_panel", body, damage >= 50) as VBoxContainer
    if not is_instance_valid(risk_panel):
        return
    risk_panel.name = "V13CareerDamagePanel"
    _main.call("_v17_eyebrow", risk_panel, "CAREER RISK")
    _main.call("_v17_title", risk_panel, "커리어 데미지 · %d / 100" % damage, 20)
    _main.call("_v17_copy", risk_panel, "건강 상한 %d%% · 회복 페널티 %d" % [int(GameState.career_health_ceiling()), int(GameState.career_recovery_penalty())], damage >= 50)
    var injuries: Array = GameState.chronic_injuries()
    if injuries.is_empty():
        _main.call("_v17_copy", risk_panel, "만성 부상 · 없음", true)
    else:
        var names: Array[String] = []
        for value in injuries:
            var injury: Dictionary = value
            names.append(str(injury.get("name", "만성 손상")))
        _main.call("_v17_copy", risk_panel, "만성 부상 · %s" % " · ".join(names), true)

func _polish_world_matchup_read() -> void:
    var matchup := _main.find_child("V19TacticalMatchup", true, false) as PanelContainer
    if not is_instance_valid(matchup) or matchup.has_meta("v13_world_read"):
        return
    var opponent_value: Variant = _main.get("current_opponent")
    if typeof(opponent_value) != TYPE_DICTIONARY:
        return
    var opponent: Dictionary = opponent_value
    if opponent.is_empty() or not opponent.has("age"):
        return
    var record: Dictionary = opponent.get("record", {})
    var world_line: String = "WORLD · %d세 · %d-%d-%d" % [int(opponent.get("age", 0)), int(record.get("wins", 0)), int(record.get("losses", 0)), int(record.get("draws", 0))]
    if bool(opponent.get("champion", false)):
        world_line += " · %d차 방어" % int(opponent.get("title_defenses", 0))
    var info_nodes := matchup.find_children("*", "VBoxContainer", true, false)
    if not info_nodes.is_empty():
        var info := info_nodes[0] as VBoxContainer
        var label := Label.new()
        label.text = world_line
        label.add_theme_font_size_override("font_size", 10)
        label.add_theme_color_override("font_color", Color("d4a24d") if bool(opponent.get("champion", false)) else Color("9eaab8"))
        info.add_child(label)
    matchup.set_meta("v13_world_read", true)

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
    var body := _main.get("body") as Container
    if not is_instance_valid(body):
        return
    var list := _main.find_child("V19TacticalList", true, false) as GridContainer
    if not is_instance_valid(list):
        list = GridContainer.new()
        list.name = "V19TacticalList"
        list.columns = 1
        list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        list.add_theme_constant_override("v_separation", 5)
        var insert_index: int = (tactic_nodes[0] as Node).get_index()
        body.add_child(list)
        body.move_child(list, insert_index)
        for tactic_node in tactic_nodes:
            (tactic_node as Node).reparent(list)
    var target_width := _content_width()
    if target_width > 0.0:
        list.custom_minimum_size.x = target_width
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for panel_node in list.get_children():
        var panel := panel_node as PanelContainer
        if not is_instance_valid(panel):
            continue
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if target_width > 0.0:
            panel.custom_minimum_size.x = target_width
        if panel.has_meta("v19_1_compact"):
            continue
        var panel_style := _main.call("_v17_box_style", Color("071019"), Color("1d2b3a"), 6, 5) as StyleBoxFlat
        if is_instance_valid(panel_style):
            panel.add_theme_stylebox_override("panel", panel_style)
        if panel.get_child_count() > 0:
            var row := panel.get_child(0) as HBoxContainer
            if is_instance_valid(row):
                row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                row.add_theme_constant_override("separation", 7)
                for child in row.get_children():
                    if child is Label:
                        var number := child as Label
                        number.custom_minimum_size.x = 22
                        number.add_theme_font_size_override("font_size", 11)
                    elif child is VBoxContainer:
                        var copy := child as VBoxContainer
                        copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                        var labels := copy.find_children("*", "Label", true, false)
                        if labels.size() > 0: (labels[0] as Label).add_theme_font_size_override("font_size", 14)
                        if labels.size() > 1: (labels[1] as Label).add_theme_font_size_override("font_size", 10)
                        if labels.size() > 2: (labels[2] as Label).add_theme_font_size_override("font_size", 9)
                    elif child is Button:
                        var choose := child as Button
                        choose.custom_minimum_size = Vector2(58, 56)
                        choose.size_flags_horizontal = Control.SIZE_SHRINK_END
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
