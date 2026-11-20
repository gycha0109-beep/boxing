extends VBoxContainer

# Profile screen derived from the user's 941x1672 reference. Data and navigation remain live.
const GOLD := Color("#eac078")
const GOLD_DARK := Color("#9c7136")
const WHITE := Color("#f8f3e9")
const MUTED := Color("#afbac7")
const RED := Color("#e84d4c")
const BLUE := Color("#5ba8f7")
const PANEL := Color("#0a1724")
const PANEL_ALT := Color("#111f2d")
const HERO_ASSET := preload("res://assets/visual/reference_v1/profile_boxer.png")
const Art := preload("res://scripts/ui/reference_result_art.gd")

var heading_font: Font
var bold_font: Font

func _ready() -> void:
    name = "ReferenceProfile"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 9)
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    _header()
    _hero(boxer, career)
    _condition(boxer)
    _stats(boxer)
    _goal(career)
    _legacy()

func _style(bg: Color = PANEL, edge: Color = GOLD_DARK, pad: int = 8) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = edge
    s.border_width_top = 2
    s.border_width_bottom = 2
    s.border_width_left = 1
    s.border_width_right = 1
    s.corner_radius_top_left = 6
    s.corner_radius_top_right = 6
    s.corner_radius_bottom_left = 6
    s.corner_radius_bottom_right = 6
    s.content_margin_left = pad
    s.content_margin_right = pad
    s.content_margin_top = pad
    s.content_margin_bottom = pad
    s.shadow_size = 3
    s.shadow_color = Color(0, 0, 0, 0.42)
    return s

func _panel(parent: Container, bg: Color = PANEL, edge: Color = GOLD_DARK, pad: int = 8) -> VBoxContainer:
    var outer := PanelContainer.new()
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.add_theme_stylebox_override("panel", _style(bg, edge, pad))
    parent.add_child(outer)
    var inside := VBoxContainer.new()
    inside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inside.add_theme_constant_override("separation", 4)
    outer.add_child(inside)
    return inside

func _label(parent: Container, content: String, points: int = 14, tint: Color = WHITE, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = false) -> Label:
    var l := Label.new()
    l.text = content
    l.horizontal_alignment = alignment
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_color_override("font_color", tint)
    l.add_theme_font_size_override("font_size", points)
    if bold:
        l.add_theme_font_override("font", bold_font)
        l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
        l.add_theme_constant_override("shadow_offset_x", 1)
        l.add_theme_constant_override("shadow_offset_y", 2)
    parent.add_child(l)
    return l

func _header() -> void:
    var title := _label(self, "내 선수", 31, WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
    title.add_theme_font_override("font", heading_font)
    title.custom_minimum_size.y = 40
    var eyebrow := _label(self, "━━  B O X E R   P R O F I L E  ━━", 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    eyebrow.custom_minimum_size.y = 22

func _hero(boxer: Dictionary, career: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(row)

    var portrait_panel := PanelContainer.new()
    portrait_panel.custom_minimum_size = Vector2(153, 256)
    portrait_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    portrait_panel.add_theme_stylebox_override("panel", _style(Color("#091420"), GOLD_DARK, 1))
    row.add_child(portrait_panel)
    var portrait := TextureRect.new()
    portrait.name = "ReferenceBoxerPortrait"
    portrait.texture = HERO_ASSET
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.custom_minimum_size = Vector2(148, 250)
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    portrait_panel.add_child(portrait)

    var content := _panel(row, PANEL, GOLD, 7)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(content, "▶  내 선수", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
    _label(content, str(boxer.get("name", "무명 복서")), 22, WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
    _divider(content)
    _pair(content, "스타일", str(boxer.get("identity_name", "미지정")))
    _pair(content, "특성", str(boxer.get("trait_name", "미지정")))
    _divider(content)
    _pair(content, "전적", "%d전 %d승 %d패" % [int(career.get("fights", 0)), int(career.get("wins", 0)), int(career.get("losses", 0))])
    _pair(content, "랭킹", "#%d" % int(career.get("rank", 50)))
    _pair(content, "커리어 점수", "%d CP" % int(career.get("career_points", 0)))
    _divider(content)
    _label(content, "CURRENT TIER", 10, MUTED)
    _label(content, GameState.tier_label(), 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)

func _pair(parent: Container, key: String, val: String) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    parent.add_child(row)
    var k := _label(row, key, 11, MUTED)
    k.custom_minimum_size.x = 61
    var v := _label(row, val, 12, WHITE, HORIZONTAL_ALIGNMENT_RIGHT, true)
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _divider(parent: Container) -> void:
    var sep := HSeparator.new()
    sep.add_theme_color_override("font_color", GOLD_DARK)
    parent.add_child(sep)

func _condition(boxer: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    add_child(row)
    var health := _panel(row, Color("#141c26"), GOLD_DARK, 6)
    _label(health, "♥  건강", 11, MUTED)
    _label(health, "%d / 100" % int(boxer.get("health", 100)), 16, RED, HORIZONTAL_ALIGNMENT_CENTER, true)
    var fatigue := _panel(row, Color("#141c26"), GOLD_DARK, 6)
    var fatigue_label := HBoxContainer.new()
    fatigue_label.add_theme_constant_override("separation", 3)
    fatigue.add_child(fatigue_label)
    Art.result_icon(fatigue_label, &"speed")
    _label(fatigue_label, "피로", 11, MUTED).autowrap_mode = TextServer.AUTOWRAP_OFF
    _label(fatigue, "%d%%" % int(boxer.get("fatigue", 0)), 16, BLUE, HORIZONTAL_ALIGNMENT_CENTER, true)
    var weight := _panel(row, Color("#141c26"), GOLD_DARK, 6)
    _label(weight, "◆  체중", 11, MUTED)
    _label(weight, "%.1f kg" % float(boxer.get("weight_kg", 0.0)), 15, WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)

func _stats(boxer: Dictionary) -> void:
    var main := _panel(self, PANEL_ALT, GOLD, 9)
    for k in [
        ["power", "파워", "◆"],
        ["speed", "스피드", ""],
        ["technique", "테크닉", "◎"],
        ["defense", "수비", "◇"],
        ["conditioning", "체력", "♥"]
    ]:
        var id: String = str(k[0])
        var val: int = clampi(int(boxer.get(id, 0)), 0, 100)
        var line := HBoxContainer.new()
        line.custom_minimum_size.y = 24
        line.add_theme_constant_override("separation", 5)
        main.add_child(line)
        if id == "speed":
            Art.result_icon(line, &"speed")
        else:
            var symbol := _label(line, str(k[2]), 15, GOLD)
            symbol.custom_minimum_size.x = 16
        var key := _label(line, str(k[1]), 14, WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
        key.custom_minimum_size.x = 65
        var meter := ProgressBar.new()
        meter.max_value = 100.0
        meter.value = val
        meter.show_percentage = false
        meter.custom_minimum_size = Vector2(40, 14)
        meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var background := StyleBoxFlat.new()
        background.bg_color = Color("#263343")
        background.set_corner_radius_all(3)
        var fill := StyleBoxFlat.new()
        fill.bg_color = RED
        fill.set_corner_radius_all(3)
        meter.add_theme_stylebox_override("background", background)
        meter.add_theme_stylebox_override("fill", fill)
        line.add_child(meter)
        var number := _label(line, str(val), 15, WHITE, HORIZONTAL_ALIGNMENT_RIGHT, true)
        number.custom_minimum_size.x = 30

func _goal(career: Dictionary) -> void:
    var box := _panel(self, Color("#23151a"), GOLD, 11)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    box.add_child(row)
    Art.result_icon(row, &"goal")
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(col)
    _label(col, "다음 목표", 12, GOLD)
    var stage: Dictionary = GameState.career_ladder_stage()
    _label(col, str(stage.get("label", "다음 타이틀 도전")), 21, WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
    var next_action := _label(box, "승리를 쌓아 랭킹을 올리고 타이틀에 도전하세요.", 11, MUTED)
    next_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _legacy() -> void:
    var box := _panel(self, PANEL, GOLD_DARK, 9)
    var row := HBoxContainer.new()
    box.add_child(row)
    Art.result_icon(row, &"career")
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(col)
    _label(col, "월드 / 레거시", 13, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
    _label(col, "한 선수의 커리어가 다음 제자의 유산이 됩니다.", 11, MUTED)
