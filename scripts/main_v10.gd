extends "res://scripts/main_v08.gd"

const RELEASE_FONT_PATH := "res://assets/fonts/NotoSansKR-VF.ttf"
const RELEASE_FONT_LICENSE_PATH := "res://assets/fonts/OFL-NotoSansKR.txt"
const MOBILE_SCROLL_DEADZONE := 7
const PROFILE_ACCENT := Color(0.92, 0.70, 0.34, 1.0)
const PROFILE_MUTED := Color(0.68, 0.70, 0.75, 1.0)
const PROFILE_BAR_BG := Color(0.16, 0.17, 0.20, 1.0)
const FIGHT_PANEL_BG := Color(0.055, 0.060, 0.075, 0.98)
const FIGHT_PANEL_BORDER := Color(0.31, 0.25, 0.16, 1.0)
const FIGHT_HP := Color(0.82, 0.24, 0.24, 1.0)
const FIGHT_STA := Color(0.25, 0.58, 0.84, 1.0)
const FIGHT_STAGE_HEIGHT := 320.0

var fighter_profile_root: Control

func _ready() -> void:
    super._ready()
    _configure_mobile_scroll()

func _render_phase() -> void:
    fighter_profile_root = null
    if is_instance_valid(body):
        body.add_theme_constant_override("separation", 12)
    super._render_phase()

    if _should_insert_persistent_fighter_profile():
        _render_player_visual_card()
        if is_instance_valid(fighter_profile_root) and fighter_profile_root.get_parent() == body:
            body.move_child(fighter_profile_root, 0)

    _configure_mobile_scroll()

func _render_fight(animated_exchange: Dictionary = {}) -> void:
    fighter_profile_root = null
    _clear_body()
    body.add_theme_constant_override("separation", 8)

    var had_pending_action: bool = not combat.pending_opponent_action.is_empty()
    var telegraph: Dictionary = combat.prepare_exchange()
    if not had_pending_action and not telegraph.is_empty():
        GameState.save_active_fight(combat.export_state())

    var snap: Dictionary = combat.snapshot()
    var selected_plan: Dictionary = GameState.get_selected_game_plan()
    var exchange_in_round: int = (int(snap.exchange) % int(combat.balance.fight.exchanges_per_round)) + 1

    header.text = "TWELVE COUNT"
    status.text = "ROUND %d · EXCHANGE %d/%d   ·   %s" % [
        int(snap.round), exchange_in_round, int(combat.balance.fight.exchanges_per_round),
        str(selected_plan.get("name", "균형 운영"))
    ]
    status.add_theme_font_size_override("font_size", 16)
    status.add_theme_color_override("font_color", PROFILE_ACCENT)

    var ring_label := Label.new()
    ring_label.text = "RING"
    ring_label.add_theme_font_size_override("font_size", 13)
    ring_label.add_theme_color_override("font_color", PROFILE_MUTED)
    body.add_child(ring_label)

    var stage := FightStage.new()
    stage.configure(str(GameState.state.boxer.name), str(current_opponent.name), snap, telegraph)
    body.add_child(stage)
    stage.custom_minimum_size = Vector2(0, FIGHT_STAGE_HEIGHT)
    stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    if not animated_exchange.is_empty():
        stage.play_exchange(animated_exchange)

    var hud_box := _fight_panel()
    var hud_row := HBoxContainer.new()
    hud_row.add_theme_constant_override("separation", 10)
    hud_box.add_child(hud_row)

    var player_hud := VBoxContainer.new()
    player_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hud_row.add_child(player_hud)
    var player_name := Label.new()
    player_name.text = str(GameState.state.boxer.name)
    player_name.add_theme_font_size_override("font_size", 15)
    player_hud.add_child(player_name)
    _fight_meter_line(player_hud, "HP", float(snap.player_hp), FIGHT_HP)
    _fight_meter_line(player_hud, "STA", float(snap.player_stamina), FIGHT_STA)

    var versus := Label.new()
    versus.text = "VS"
    versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    versus.add_theme_font_size_override("font_size", 18)
    versus.add_theme_color_override("font_color", PROFILE_ACCENT)
    versus.custom_minimum_size = Vector2(34, 0)
    hud_row.add_child(versus)

    var opponent_hud := VBoxContainer.new()
    opponent_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hud_row.add_child(opponent_hud)
    var opponent_name := Label.new()
    opponent_name.text = str(current_opponent.name)
    opponent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    opponent_name.add_theme_font_size_override("font_size", 15)
    opponent_hud.add_child(opponent_name)
    _fight_meter_line(opponent_hud, "HP", float(snap.opponent_hp), FIGHT_HP)
    _fight_meter_line(opponent_hud, "STA", float(snap.opponent_stamina), FIGHT_STA)

    var last_exchange: Dictionary = snap.get("last_exchange", {})
    if bool(snap.finished):
        GameState.apply_fight_result(str(snap.result), current_opponent, snap)
        var finish_line := Label.new()
        finish_line.text = CombatPresentation.exchange_headline(last_exchange) if not last_exchange.is_empty() else "경기 종료"
        finish_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        finish_line.add_theme_font_size_override("font_size", 18)
        finish_line.add_theme_color_override("font_color", PROFILE_ACCENT)
        body.add_child(finish_line)
        _button("경기 정산", func(): _render_phase())
        _configure_mobile_scroll()
        return

    var read_box := _fight_panel()
    var read_line := Label.new()
    var confidence := int(telegraph.get("confidence", 0))
    var read_title := CombatPresentation.telegraph_title(telegraph)
    var read_hint := _compact_read_hint(str(telegraph.get("action_id", "")))
    read_line.text = "OPPONENT READ · %d%%   |   %s · %s" % [confidence, read_title, read_hint]
    read_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    read_line.add_theme_font_size_override("font_size", 14)
    read_line.add_theme_color_override("font_color", PROFILE_ACCENT)
    read_box.add_child(read_line)

    if not last_exchange.is_empty():
        var previous := Label.new()
        previous.text = "직전 교환 · %s" % CombatPresentation.exchange_headline(last_exchange)
        previous.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        previous.add_theme_font_size_override("font_size", 11)
        previous.add_theme_color_override("font_color", PROFILE_MUTED)
        read_box.add_child(previous)

    var action_title := Label.new()
    action_title.text = "다음 행동"
    action_title.add_theme_font_size_override("font_size", 15)
    action_title.add_theme_color_override("font_color", PROFILE_MUTED)
    body.add_child(action_title)

    var first_row := HBoxContainer.new()
    first_row.add_theme_constant_override("separation", 8)
    body.add_child(first_row)
    _fight_action_button(first_row, "jab", selected_plan)
    _fight_action_button(first_row, "power", selected_plan)

    var second_row := HBoxContainer.new()
    second_row.add_theme_constant_override("separation", 8)
    body.add_child(second_row)
    _fight_action_button(second_row, "body", selected_plan)
    _fight_action_button(second_row, "guard", selected_plan)
    _fight_action_button(second_row, "counter", selected_plan)

    _configure_mobile_scroll()

func _fight_panel() -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style := StyleBoxFlat.new()
    style.bg_color = FIGHT_PANEL_BG
    style.border_color = FIGHT_PANEL_BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.content_margin_left = 10.0
    style.content_margin_right = 10.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    panel.add_theme_stylebox_override("panel", style)
    body.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    panel.add_child(box)
    return box

func _fight_meter_line(parent: VBoxContainer, label_text: String, value: float, fill_color: Color) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)

    var label := Label.new()
    label.text = "%s %d" % [label_text, int(round(value))]
    label.custom_minimum_size = Vector2(48, 0)
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", PROFILE_MUTED)
    row.add_child(label)

    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = clamp(value, 0.0, 100.0)
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 9)
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background := StyleBoxFlat.new()
    background.bg_color = PROFILE_BAR_BG
    background.set_corner_radius_all(5)
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.set_corner_radius_all(5)
    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", fill)
    row.add_child(bar)

func _fight_action_button(parent: HBoxContainer, action_id: String, selected_plan: Dictionary) -> void:
    var action: Dictionary = combat.balance.actions[action_id]
    var button := Button.new()
    var stamina := int(action.get("stamina", 0))
    var stamina_text := "STA +%d" % abs(stamina) if stamina < 0 else "STA %d" % stamina
    var plan_bonus: bool = bool(selected_plan.get("action_modifiers", {}).has(action_id))
    var plan_text := "\n★ PLAN" if plan_bonus else ""
    button.text = "%s%s\n%s" % [str(action.get("label", action_id)), plan_text, stamina_text]
    button.custom_minimum_size = Vector2(0, 68)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 14)
    button.mouse_filter = Control.MOUSE_FILTER_PASS
    if plan_bonus:
        button.add_theme_color_override("font_color", PROFILE_ACCENT)
    button.pressed.connect(Callable(self, "_choose_fight_action").bind(action_id))
    parent.add_child(button)

func _compact_read_hint(action_id: String) -> String:
    match action_id:
        "jab": return "잽 경계"
        "power": return "강타 주의"
        "body": return "바디 주의"
        "guard": return "가드 중 · 압박 기회"
        "counter": return "카운터 주의"
        _: return "움직임 관찰"

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
    identity_label.text = "%s · 특성 [%s]" % [str(boxer.get("identity_name", "균형형")), str(boxer.get("trait_name", "무특성"))]
    identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    identity_label.add_theme_color_override("font_color", PROFILE_ACCENT)
    identity_info.add_child(identity_label)

    var record_label := Label.new()
    record_label.text = "%d-%d-%d · 랭킹 #%d · %s · %s" % [int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)), int(career.get("rank", 0)), GameState.tier_label(), GameState.age_text()]
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
    condition.text = "현재 상태 · 체중 %.2f / %.1fkg · 피로 %d%% · 건강 %d%%\n부상 %s · 커리어 %dpt · 보유금 %d원" % [float(boxer.get("weight_kg", 0.0)), float(GameState.career_balance.weight_class.limit_kg), int(boxer.get("fatigue", 0)), int(boxer.get("health", 0)), injury_text, int(career.get("career_points", 0)), int(career.get("money", 0))]
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
    if str(GameState.state.get("phase", "")) == "fight":
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.scroll_vertical = 0
    else:
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
    bundled_font.allow_system_fallback = false
    var ui_theme := Theme.new()
    ui_theme.default_font = bundled_font
    theme = ui_theme
