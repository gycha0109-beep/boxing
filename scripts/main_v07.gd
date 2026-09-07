extends "res://scripts/main_v06.gd"

const V07_MUTED := Color(0.68, 0.70, 0.75, 1.0)
const V07_ACCENT := Color(0.92, 0.70, 0.34, 1.0)

func _ready() -> void:
    _apply_v07_system_font()
    super._ready()
    _disable_horizontal_scroll()

func _apply_v07_system_font() -> void:
    var system_font := SystemFont.new()
    system_font.font_names = PackedStringArray([
        "Apple SD Gothic Neo",
        "Malgun Gothic",
        "Noto Sans CJK KR",
        "Noto Sans KR",
        "sans-serif",
    ])
    system_font.allow_system_fallback = true
    var ui_theme := Theme.new()
    ui_theme.default_font = system_font
    theme = ui_theme

func _disable_horizontal_scroll() -> void:
    for node in find_children("*", "ScrollContainer", true, false):
        var scroll := node as ScrollContainer
        if scroll != null:
            scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _render_camp() -> void:
    _render_player_visual_card()
    var injury_note: String = ""
    if not GameState.state.boxer.injury.is_empty():
        injury_note = "\n현재 부상: %s. 재활을 고르면 기간을 줄일 수 있습니다." % GameState.state.boxer.injury.name
    _section("이번 캠프", "한 번의 선택만 할 수 있습니다. 성장, 회복, 체중 중 무엇을 포기할지 결정합니다.%s" % injury_note)

    for action in camp_actions:
        var details: Array[String] = []
        for key in action.effects.keys():
            details.append("%s %s" % [str(key), _signed_value(action.effects[key])])
        var affordable: bool = int(GameState.state.career.money) >= int(action.cost)
        var card := _card_box(str(action.name))
        _add_wrapped_label(card, "비용 %d원 · 부상 위험 %.1f%%" % [int(action.cost), float(action.risk) * 100.0], true)
        _add_wrapped_label(card, ", ".join(details), false)
        if not affordable:
            _add_wrapped_label(card, "자금 부족", true)
        var choose := Button.new()
        choose.text = "캠프 선택" if affordable else "선택 불가"
        choose.custom_minimum_size = Vector2(0, 58)
        choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choose.disabled = not affordable
        choose.pressed.connect(Callable(self, "_choose_camp_action").bind(action))
        card.add_child(choose)

func _render_offers() -> void:
    var offers: Array = GameState.get_fight_offers(opponents)
    _section("경기 계약", "상대를 고른 뒤 스카우팅 리포트와 게임플랜을 확인합니다. 초상화는 상대 스타일을 빠르게 읽기 위한 시각적 앵커입니다.")
    for opponent in offers:
        _render_offer_card(opponent)

func _render_game_plan() -> void:
    if current_opponent.is_empty():
        current_opponent = _find_opponent(str(GameState.state.selected_opponent))
    if current_opponent.is_empty():
        GameState.state.phase = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return

    _render_opponent_visual_card(current_opponent, "OPPONENT FILE")

    var scouting: Dictionary = current_opponent.get("scouting", {})
    var tendencies: Dictionary = current_opponent.get("tendencies", {})
    _section("상대 스카우팅 · %s" % current_opponent.name,
        "스타일: %s · 랭킹 #%d\n강점: %s\n약점: %s\n텔: %s\n\n행동 경향: %s" % [
            str(current_opponent.style), int(current_opponent.rank),
            str(scouting.get("strength", "정보 부족")),
            str(scouting.get("weakness", "정보 부족")),
            str(scouting.get("tell", "정보 부족")),
            _tendency_text(tendencies)
        ])

    var identity_note := Label.new()
    identity_note.text = "내 복서: %s — %s" % [str(GameState.state.boxer.get("identity_name", "균형형")), GameState.identity_description()]
    identity_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    identity_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    identity_note.custom_minimum_size = Vector2.ZERO
    body.add_child(identity_note)

    _section("게임 플랜", "이번 경기에서만 적용됩니다. ★는 스카우팅 추천이지만 정답은 아닙니다. 상대의 습관과 내 복서의 정체성을 함께 보고 선택합니다.")
    var suggested: Array = scouting.get("suggested_plans", [])
    for plan in GameState.game_plans:
        var recommended: bool = str(plan.id) in suggested
        var mark: String = "★ 추천 · " if recommended else ""
        var card := _card_box("%s%s" % [mark, str(plan.name)])
        _add_wrapped_label(card, "리스크 · %s" % str(plan.get("risk", "중간")), true)
        _add_wrapped_label(card, str(plan.description), false)
        _add_wrapped_label(card, _plan_effect_text(plan), true)
        var choose := Button.new()
        choose.text = "이 플랜 선택"
        choose.custom_minimum_size = Vector2(0, 58)
        choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choose.pressed.connect(Callable(self, "_choose_game_plan").bind(str(plan.id)))
        card.add_child(choose)

func _add_wrapped_label(parent: VBoxContainer, text_value: String, muted: bool) -> Label:
    var label := Label.new()
    label.text = text_value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.custom_minimum_size = Vector2.ZERO
    if muted:
        label.add_theme_color_override("font_color", V07_MUTED)
    parent.add_child(label)
    return label

func _render_offer_card(opponent: Dictionary) -> void:
    var box := _card_box("")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    box.add_child(row)

    var portrait := _portrait_view(VisualAssetCatalog.portrait_texture(false, str(opponent.get("style", "swarmer"))), 108.0)
    row.add_child(portrait)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 5)
    row.add_child(info)

    var name_label := Label.new()
    name_label.text = "%s · #%d" % [str(opponent.get("name", "OPPONENT")), int(opponent.get("rank", 0))]
    name_label.add_theme_font_size_override("font_size", 19)
    info.add_child(name_label)

    var style_label := Label.new()
    var title_mark := " · TITLE" if bool(opponent.get("title_fight", false)) else ""
    style_label.text = "%s · %s%s" % [str(opponent.get("tier", "")), str(opponent.get("style", "")), title_mark]
    style_label.add_theme_color_override("font_color", V07_ACCENT)
    info.add_child(style_label)

    var money_label := Label.new()
    money_label.text = "파이트머니 %d원 · 승리 +%dpt · 패배 -%dpt" % [
        int(opponent.get("purse", 0)), int(opponent.get("career_points_win", 0)), int(opponent.get("career_points_loss", 0))
    ]
    money_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    money_label.custom_minimum_size = Vector2.ZERO
    money_label.add_theme_color_override("font_color", V07_MUTED)
    info.add_child(money_label)

    var stats: Dictionary = opponent.get("stats", {})
    var stats_label := Label.new()
    stats_label.text = "P%d  S%d  T%d  D%d  C%d" % [
        int(stats.get("power", 0)), int(stats.get("speed", 0)), int(stats.get("technique", 0)),
        int(stats.get("defense", 0)), int(stats.get("conditioning", 0))
    ]
    stats_label.add_theme_font_size_override("font_size", 12)
    stats_label.add_theme_color_override("font_color", V07_MUTED)
    info.add_child(stats_label)

    var choose := Button.new()
    choose.text = "상대 분석"
    choose.custom_minimum_size = Vector2(0, 58)
    choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choose.pressed.connect(Callable(self, "_choose_opponent").bind(opponent))
    info.add_child(choose)

func _render_player_visual_card() -> void:
    var texture := VisualAssetCatalog.portrait_texture(true)
    if texture == null:
        return
    var box := _card_box("YOUR FIGHTER")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    box.add_child(row)
    row.add_child(_portrait_view(texture, 96.0))

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(info)
    var boxer: Dictionary = GameState.state.boxer
    var career: Dictionary = GameState.state.career
    var name_label := Label.new()
    name_label.text = str(boxer.get("name", "BOXER"))
    name_label.add_theme_font_size_override("font_size", 21)
    info.add_child(name_label)
    var copy := Label.new()
    copy.text = "%s · %s\n%d전 %d승 %d패 · 랭킹 #%d" % [
        str(boxer.get("identity_name", "균형형")), str(boxer.get("trait_name", "")),
        int(career.get("fights", 0)), int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("rank", 0))
    ]
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.custom_minimum_size = Vector2.ZERO
    copy.add_theme_color_override("font_color", V07_MUTED)
    info.add_child(copy)

func _render_opponent_visual_card(opponent: Dictionary, title: String) -> void:
    var texture := VisualAssetCatalog.portrait_texture(false, str(opponent.get("style", "swarmer")))
    if texture == null:
        return
    var box := _card_box(title)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    box.add_child(row)
    row.add_child(_portrait_view(texture, 112.0))

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(info)
    var name_label := Label.new()
    name_label.text = str(opponent.get("name", "OPPONENT"))
    name_label.add_theme_font_size_override("font_size", 21)
    info.add_child(name_label)
    var meta := Label.new()
    meta.text = "%s · #%d" % [str(opponent.get("style", "")), int(opponent.get("rank", 0))]
    meta.add_theme_color_override("font_color", V07_ACCENT)
    info.add_child(meta)
    var scouting: Dictionary = opponent.get("scouting", {})
    var tell := Label.new()
    tell.text = str(scouting.get("tell", ""))
    tell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tell.custom_minimum_size = Vector2.ZERO
    tell.add_theme_color_override("font_color", V07_MUTED)
    info.add_child(tell)

func _portrait_view(texture: Texture2D, extent: float) -> TextureRect:
    var view := TextureRect.new()
    view.texture = texture
    view.custom_minimum_size = Vector2(extent, extent)
    view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return view
