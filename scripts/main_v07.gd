extends "res://scripts/main_v06.gd"

const V07_MUTED := Color(0.68, 0.70, 0.75, 1.0)
const V07_ACCENT := Color(0.92, 0.70, 0.34, 1.0)

func _ready() -> void:
    _apply_v07_system_font()
    super._ready()

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

func _render_camp() -> void:
    _render_player_visual_card()
    super._render_camp()

func _render_offers() -> void:
    var offers: Array = GameState.get_fight_offers(opponents)
    _section("경기 계약", "상대를 고른 뒤 스카우팅 리포트와 게임플랜을 확인합니다. 초상화는 상대 스타일을 빠르게 읽기 위한 시각적 앵커입니다.")
    for opponent in offers:
        _render_offer_card(opponent)

func _render_game_plan() -> void:
    if current_opponent.is_empty():
        current_opponent = _find_opponent(str(GameState.state.selected_opponent))
    if not current_opponent.is_empty():
        _render_opponent_visual_card(current_opponent, "OPPONENT FILE")
    super._render_game_plan()

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
