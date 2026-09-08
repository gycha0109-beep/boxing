extends "res://scripts/main_v08.gd"

const RELEASE_FONT_PATH := "res://assets/fonts/NotoSansKR-VF.ttf"
const RELEASE_FONT_LICENSE_PATH := "res://assets/fonts/OFL-NotoSansKR.txt"
const MOBILE_SCROLL_DEADZONE := 7
const PROFILE_ACCENT := Color(0.92, 0.70, 0.34, 1.0)
const PROFILE_MUTED := Color(0.68, 0.70, 0.75, 1.0)
const PROFILE_BAR_BG := Color(0.16, 0.17, 0.20, 1.0)

var fighter_profile_root: Control

func _ready() -> void:
    super._ready()
    _configure_mobile_scroll()

func _render_phase() -> void:
    fighter_profile_root = null
    super._render_phase()

    if _should_insert_persistent_fighter_profile():
        _render_player_visual_card()
        if is_instance_valid(fighter_profile_root) and fighter_profile_root.get_parent() == body:
            body.move_child(fighter_profile_root, 0)

    _configure_mobile_scroll()

func _render_fight(animated_exchange: Dictionary = {}) -> void:
    fighter_profile_root = null
    super._render_fight(animated_exchange)
    _configure_mobile_scroll()

func _render_game_plan() -> void:
    if not str(GameState.state.get("selected_opponent", "")).is_empty():
        var back := Button.new()
        back.text = "← 상대 다시 선택"
        back.custom_minimum_size = Vector2(0, 58)
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back.mouse_filter = Control.MOUSE_FILTER_PASS
        back.pressed.connect(Callable(self, "_return_to_fight_offers"))
        body.add_child(back)
    super._render_game_plan()
    _configure_mobile_scroll()

func _return_to_fight_offers() -> void:
    if str(GameState.state.get("phase", "")) != "game_plan":
        return
    GameState.state["selected_opponent"] = ""
    GameState.state["selected_game_plan"] = ""
    GameState.state["last_weigh_in"] = {}
    GameState.state["fight_seed"] = 0
    GameState.state["active_fight"] = {}
    GameState.state["phase"] = "fight_offer"
    current_opponent = {}
    SaveService.save_game(GameState.state)
    _render_phase()

func _should_insert_persistent_fighter_profile() -> bool:
    if launch_gate_active or not is_instance_valid(body) or GameState.state.is_empty():
        return false
    var phase := str(GameState.state.get("phase", ""))
    return phase in ["fight_offer", "game_plan", "result", "event"]

func _render_player_visual_card() -> void:
    fighter_profile_root = null
    if GameState.state.is_empty():
        return

    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    if boxer.is_empty() or career.is_empty():
        return

    var box := _card_box("내 복서 · YOUR FIGHTER")
    fighter_profile_root = box.get_parent() as Control

    var identity_row := HBoxContainer.new()
    identity_row.add_theme_constant_override("separation", 14)
    box.add_child(identity_row)

    var texture := VisualAssetCatalog.portrait_texture(true)
    if texture != null:
        identity_row.add_child(_portrait_view(texture, 88.0))

    var identity_info := VBoxContainer.new()
    identity_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    identity_info.add_theme_constant_override("separation", 4)
    identity_row.add_child(identity_info)

    var name_label := Label.new()
    name_label.text = str(boxer.get("name", "BOXER"))
    name_label.add_theme_font_size_override("font_size", 22)
    identity_info.add_child(name_label)

    var identity_label := Label.new()
    identity_label.text = "%s · 특성 [%s]" % [
        str(boxer.get("identity_name", "균형형")),
        str(boxer.get("trait_name", "무특성"))
    ]
    identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    identity_label.add_theme_color_override("font_color", PROFILE_ACCENT)
    identity_info.add_child(identity_label)

    var record_label := Label.new()
    record_label.text = "%d-%d-%d · 랭킹 #%d · %s · %s" % [
        int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)),
        int(career.get("rank", 0)), GameState.tier_label(), GameState.age_text()
    ]
    record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    record_label.add_theme_font_size_override("font_size", 13)
    record_label.add_theme_color_override("font_color", PROFILE_MUTED)
    identity_info.add_child(record_label)

    var stats_title := Label.new()
    stats_title.text = "능력치 / 100"
    stats_title.add_theme_font_size_override("font_size", 15)
    stats_title.add_theme_color_override("font_color", PROFILE_MUTED)
    box.add_child(stats_title)

    var stats_grid := GridContainer.new()
    stats_grid.columns = 2
    stats_grid.add_theme_constant_override("h_separation", 12)
    stats_grid.add_theme_constant_override("v_separation", 8)
    box.add_child(stats_grid)
    _profile_stat_cell(stats_grid, "파워", int(boxer.get("power", 0)))
    _profile_stat_cell(stats_grid, "스피드", int(boxer.get("speed", 0)))
    _profile_stat_cell(stats_grid, "테크닉", int(boxer.get("technique", 0)))
    _profile_stat_cell(stats_grid, "수비", int(boxer.get("defense", 0)))
    _profile_stat_cell(stats_grid, "컨디셔닝", int(boxer.get("conditioning", 0)))

    var injury: Dictionary = boxer.get("injury", {})
    var injury_text := "없음"
    if not injury.is_empty():
        injury_text = "%s · %d캠프" % [str(injury.get("name", "부상")), int(injury.get("remaining_camps", 0))]

    var condition := Label.new()
    condition.text = "현재 상태 · 체중 %.2f / %.1fkg · 피로 %d%% · 건강 %d%%\n부상 %s · 커리어 %dpt · 보유금 %d원" % [
        float(boxer.get("weight_kg", 0.0)), float(GameState.career_balance.weight_class.limit_kg),
        int(boxer.get("fatigue", 0)), int(boxer.get("health", 0)), injury_text,
        int(career.get("career_points", 0)), int(career.get("money", 0))
    ]
    condition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    condition.add_theme_font_size_override("font_size", 13)
    condition.add_theme_color_override("font_color", PROFILE_MUTED)
    box.add_child(condition)

    var identity_description := str(boxer.get("identity_description", ""))
    var identity_signature := str(boxer.get("identity_signature", ""))
    if not identity_description.is_empty() or not identity_signature.is_empty():
        var identity_copy := Label.new()
        var signature_prefix := "%s · " % identity_signature if not identity_signature.is_empty() else ""
        identity_copy.text = "복싱 정체성 · %s%s" % [signature_prefix, identity_description]
        identity_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        identity_copy.add_theme_font_size_override("font_size", 12)
        identity_copy.add_theme_color_override("font_color", PROFILE_MUTED)
        box.add_child(identity_copy)

func _profile_stat_cell(parent: GridContainer, label_text: String, value: int) -> void:
    var cell := VBoxContainer.new()
    cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cell.add_theme_constant_override("separation", 3)
    parent.add_child(cell)

    var label := Label.new()
    label.text = "%s  %d" % [label_text, value]
    label.add_theme_font_size_override("font_size", 14)
    cell.add_child(label)

    var progress := ProgressBar.new()
    progress.min_value = 0.0
    progress.max_value = 100.0
    progress.value = clamp(value, 0, 100)
    progress.show_percentage = false
    progress.custom_minimum_size = Vector2(0, 8)
    progress.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var background := StyleBoxFlat.new()
    background.bg_color = PROFILE_BAR_BG
    background.set_corner_radius_all(4)
    progress.add_theme_stylebox_override("background", background)

    var fill := StyleBoxFlat.new()
    fill.bg_color = PROFILE_ACCENT
    fill.set_corner_radius_all(4)
    progress.add_theme_stylebox_override("fill", fill)
    cell.add_child(progress)

func _configure_mobile_scroll() -> void:
    if not is_instance_valid(body):
        return
    var scroll := body.get_parent() as ScrollContainer
    if scroll == null:
        return

    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    _configure_scroll_input_tree(body)

func _configure_scroll_input_tree(node: Node) -> void:
    for child in node.get_children():
        if child is BaseButton:
            (child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
        elif child is Label or child is TextureRect or child is ProgressBar:
            (child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
        elif child is Control:
            (child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
        _configure_scroll_input_tree(child)

func _apply_v07_system_font() -> void:
    var bundled_font := load(RELEASE_FONT_PATH) as FontFile
    if bundled_font == null:
        push_error("Bundled Korean release font failed to load: %s" % RELEASE_FONT_PATH)
        return

    # Release typography must be deterministic across iPhone devices and CI.
    # Noto Sans KR contains the Korean/Latin glyphs used by the product, so do
    # not silently substitute an OS font if a glyph is missing.
    bundled_font.allow_system_fallback = false

    var ui_theme := Theme.new()
    ui_theme.default_font = bundled_font
    theme = ui_theme
