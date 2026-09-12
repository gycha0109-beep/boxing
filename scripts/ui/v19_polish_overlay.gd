extends Node

# v19.1 layout polish only. This node does not introduce or generate image assets;
# it tightens the existing v19 tactical hierarchy and gives live combat more ring area.
var _main: Node

func _ready() -> void:
    _main = get_parent()
    _sanitize_diego_identity_guides()
    process_priority = 100
    set_process(true)
    call_deferred("_apply_polish")

func _process(_delta: float) -> void:
    _apply_polish()

func _sanitize_diego_identity_guides() -> void:
    # Diego's authored WebP contains two narrow red/green construction guides
    # beside the shorts. Keep the original packaged asset untouched and remove
    # only those guide-colour pixels in memory so portrait/live/knockdown share
    # one cleaned runtime identity source.
    # Keep this classifier in sync with roster_identity_coverage_smoke.gd; QA requires exact removed-pixel equality.
    const OPPONENT_NAME := "디에고 레예스"
    var path := VisualAssetCatalog.opponent_identity_path_for_name(OPPONENT_NAME)
    if path.is_empty() or not ResourceLoader.exists(path):
        return
    var source := load(path) as Texture2D
    if source == null:
        return
    var image := source.get_image()
    if image == null:
        return
    var width := image.get_width()
    var height := image.get_height()
    var left_limit := int(round(width * 0.235))
    var right_start := int(round(width * 0.725))
    var y_start := int(round(height * 0.44))
    var y_end := int(round(height * 0.74))
    var changed := false
    for y in range(y_start, y_end):
        for x in range(width):
            if x >= left_limit and x <= right_start:
                continue
            var pixel := image.get_pixel(x, y)
            if pixel.a <= 0.5:
                continue
            var red_guide := pixel.r > 0.32 and pixel.r > pixel.g * 2.2 and pixel.r > pixel.b * 2.0
            var green_guide := pixel.g > 0.25 and pixel.g > pixel.r * 2.2 and pixel.g > pixel.b * 1.45
            if red_guide or green_guide:
                image.set_pixel(x, y, Color(0, 0, 0, 0))
                changed = true
    if not changed:
        return
    var cleaned := ImageTexture.create_from_image(image)
    VisualAssetCatalog._texture_cache[path] = cleaned
    VisualAssetCatalog._identity_cache["named_fighter_" + OPPONENT_NAME] = cleaned
    VisualAssetCatalog._identity_cache.erase("named_portrait_" + OPPONENT_NAME)

func _apply_polish() -> void:
    if not is_instance_valid(_main):
        return
    _polish_tactical_preparation()
    _polish_fight_surface()

func _content_width() -> float:
    if _main is Control:
        return maxf(0.0, (_main as Control).size.x - 24.0)
    return 0.0

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
        var insert_index := (tactic_nodes[0] as Node).get_index()
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
                        if labels.size() > 0:
                            (labels[0] as Label).add_theme_font_size_override("font_size", 14)
                        if labels.size() > 1:
                            (labels[1] as Label).add_theme_font_size_override("font_size", 10)
                        if labels.size() > 2:
                            (labels[2] as Label).add_theme_font_size_override("font_size", 9)
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
