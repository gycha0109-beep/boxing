extends VBoxContainer

const UI := preload("res://scripts/ui/reference_ui.gd")
const Art := preload("res://scripts/ui/reference_result_art.gd")
const RING := preload("res://assets/visual/reference_v1/title_ring.webp")
const TROPHY := preload("res://assets/visual/reference_v1/legacy_trophy.webp")
const FEATHER := preload("res://scripts/ui/reference_result_portrait.gdshader")
const TITLES := {
    "district": "구·시",
    "regional": "지역",
    "national": "대한민국",
    "continental": "아시아",
    "world_eliminator": "세계 도전자",
    "world": "세계 타이틀",
}
const INK := Color("#0a131d")
const PANEL := Color("#15202b")
const PAPER := Color("#f8f3e8")
const MUTED := Color("#c3cbd3")
const GREEN := Color("#a6dca4")
const RED := Color("#f5a094")

var boxer: Dictionary
var career: Dictionary
var career_state: Dictionary
var recent: Dictionary
var recent_result: String
var generation: int
var legacy_count: int
var legacy_capacity: int
var lineage: Array[Dictionary]
var active_legacies: Array[String]
var titles: Array
var stage_label: String
var next_stage: Dictionary
var title_ready := false
var required_points := 0
var heading_font: Font
var bold_font: Font
var money_text: Callable

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 7)
    _hero()
    _record()
    _title_progress()
    _latest_bout()
    _lineage()

func _hero() -> void:
    var frame := _panel(self, 3, UI.GOLD)
    var layer := Control.new()
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.clip_contents = true
    frame.add_child(layer)
    var arena := AtlasTexture.new()
    arena.atlas = RING
    arena.region = Rect2(0, 0, 941, 423)
    arena.filter_clip = true
    var scene := _picture(layer, arena, 0.0, 1.0)
    scene.modulate = Color("#75808d")
    var trophy := _picture(layer, TROPHY, 0.58, 1.0)
    var material := ShaderMaterial.new()
    material.shader = FEATHER
    material.set_shader_parameter("mirror_fade", true)
    material.set_shader_parameter("spotlight", 0.84)
    trophy.material = material
    trophy.resized.connect(func(): material.set_shader_parameter("portrait_size", trophy.size))
    Art.glow(layer, Vector2(0.5, 0.32), Vector2(450, 165), Color(0.025, 0.035, 0.05, 0.87))
    Art.glow(layer, Vector2(0.5, 0.92), Vector2(355, 65), Color(0.02, 0.04, 0.06, 0.90))
    var stack := _column(frame, 1)
    var heading := _row(stack, 5)
    heading.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(heading, 33, UI.GOLD, false)
    _outlined(_label(heading, "CAREER RECORD", 36, PAPER, UI.DISPLAY_FONT))
    Art.laurel(heading, 33, UI.GOLD, true)
    var spacer := Control.new()
    spacer.custom_minimum_size.y = 57
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(spacer)
    var name_label := _label(stack, str(boxer.get("name", "무명 복서")), 28, PAPER, heading_font, true)
    name_label.name = "CareerRecordFighter"
    _center(name_label)
    _outlined(name_label)
    var badge := PanelContainer.new()
    badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    badge.add_theme_stylebox_override("panel", Art.gold_plate(162, 25, Color("#c58c41"), 2))
    stack.add_child(badge)
    var label := _label(badge, "%d세대  ·  %s" % [generation, stage_label], 12, INK, bold_font)
    label.custom_minimum_size = Vector2(158, 20)
    _center(label)

func _record() -> void:
    var row := _row(self, 6)
    var record := _metric(row, "통산 전적", "%d승 %d패 %d무" % [
        int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)),
    ], "%d전" % int(career.get("fights", 0)))
    record.size_flags_stretch_ratio = 1.27
    _metric(row, "현재 랭킹", "#%d" % int(career.get("rank", 50)), _best("career_high_rank", "최고 #%d"))
    _metric(row, "커리어 포인트", "%d pt" % int(career.get("career_points", 0)), _best("career_high_points", "최고 %d pt"))

func _best(key: String, pattern: String) -> String:
    return pattern % int(career_state[key]) if career_state.has(key) else "최고 기록 없음"

func _metric(row: HBoxContainer, caption: String, value: String, detail: String) -> PanelContainer:
    var panel := _panel(row, 6)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var content := _column(panel, 1)
    _center(_label(content, caption, 11, UI.GOLD_BRIGHT, bold_font, true))
    _center(_label(content, value, 19, PAPER, heading_font, true))
    _center(_label(content, detail, 10, MUTED, bold_font, true))
    return panel

func _title_progress() -> void:
    var box := _column(_panel(self, 8), 5)
    _section(box, &"career", "타이틀 진행")
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    box.add_child(grid)
    var done := bool(career.get("finished", false))
    var champion := bool(career.get("champion", false))
    for key: String in TITLES:
        var earned := key in titles or (key == "world" and champion)
        var next := not done and not earned and key == str(next_stage.get("id", ""))
        var tile := _panel(grid, 4, UI.GOLD if earned or next else Color("#536171"))
        tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var lines := _column(tile, 0)
        _center(_label(lines, TITLES[key], 12, UI.GOLD_BRIGHT if earned or next else MUTED, bold_font, true))
        var status := ("통과" if key == "world_eliminator" else "획득") if earned else ("다음 도전" if next else "미획득")
        _center(_label(lines, status, 10, GREEN if earned else (PAPER if next else MUTED), bold_font))
    if champion:
        _label(box, "세계 타이틀 획득", 13, UI.GOLD_BRIGHT, bold_font)
        return
    if done:
        _label(box, "커리어 종료", 13, MUTED, bold_font)
        return
    if next_stage.is_empty():
        return
    var goal := _row(box, 7)
    var next_name := _label(goal, str(next_stage.get("label", "")), 14, PAPER, heading_font, true)
    next_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var status := _label(goal, "도전 자격 충족" if title_ready else "조건 미충족", 11, GREEN if title_ready else UI.GOLD_BRIGHT, bold_font)
    status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _progress(box, "경기 수", int(career.get("fights", 0)), int(next_stage.get("min_fights", 0)))
    _progress(box, "승리", int(career.get("wins", 0)), int(next_stage.get("min_wins", 0)))
    _progress(box, "커리어 포인트", int(career.get("career_points", 0)), required_points)

func _progress(parent: VBoxContainer, caption: String, current: int, required: int) -> void:
    if required <= 0:
        return
    var row := _row(parent, 6)
    _label(row, caption, 11, MUTED, bold_font).custom_minimum_size.x = 77
    var meter := ProgressBar.new()
    meter.custom_minimum_size.y = 5
    meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    meter.show_percentage = false
    meter.max_value = required
    meter.value = current
    meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    meter.add_theme_stylebox_override("background", UI.panel_style(Color("#233141"), Color("#354353"), 0))
    meter.add_theme_stylebox_override("fill", UI.panel_style(Color("#be8e48"), UI.GOLD, 0))
    row.add_child(meter)
    var value := _label(row, "%d / %d" % [current, required], 11, GREEN if current >= required else PAPER, bold_font)
    value.custom_minimum_size.x = 51
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _latest_bout() -> void:
    var box := _column(_panel(self, 8), 3)
    _section(box, &"scores", "최근 경기")
    if recent.is_empty():
        var copy := "아직 치른 경기가 없습니다." if int(career.get("fights", 0)) == 0 else "저장된 최근 경기 상세가 없습니다."
        _label(box, copy, 12, MUTED, bold_font, true)
        return
    var line := _row(box, 7)
    var opponent := _label(line, str(recent.get("opponent_name", "상대 선수")), 16, PAPER, heading_font, true)
    opponent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if not recent_result.is_empty():
        var result := str(recent.get("result", ""))
        var tint := GREEN if result.begins_with("WIN") else (RED if result.begins_with("LOSS") else UI.GOLD_BRIGHT)
        _label(line, recent_result, 15, tint, heading_font)
    var details: Array[String] = []
    if int(recent.get("ending_round", 0)) > 0:
        details.append("%d라운드 종료" % int(recent["ending_round"]))
    if recent.has("purse"):
        details.append("파이트머니 %s원" % money_text.call(int(recent["purse"])))
    if not details.is_empty():
        _label(box, "  ·  ".join(details), 11, MUTED, bold_font, true)

func _lineage() -> void:
    var box := _column(_panel(self, 8), 4)
    var heading := _section(box, &"goal", "세대 기록")
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heading.add_child(spacer)
    _label(heading, "보유 유산 %d / %d" % [legacy_count, legacy_capacity], 11, UI.GOLD_BRIGHT, bold_font).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    if not active_legacies.is_empty():
        _label(box, " · ".join(active_legacies), 12, PAPER, bold_font, true)
    if lineage.is_empty():
        _label(box, "다음 제자를 시작하면 이전 선수의 기록이 여기에 남습니다.", 12, MUTED, bold_font, true)
        return
    for entry: Dictionary in lineage:
        var detail := _column(_panel(box, 6), 1)
        var row := _row(detail, 6)
        var name_label := _label(row, "%d세대 · %s" % [int(entry.get("generation", 0)), str(entry.get("boxer_name", ""))], 14, PAPER, heading_font, true)
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if str(entry.get("ending", "")) == "world_champion":
            _label(row, "세계 챔피언", 11, UI.GOLD_BRIGHT, bold_font)
        var record := "%d전 %d승 %d패 %d무" % [
            int(entry.get("fights", 0)), int(entry.get("wins", 0)), int(entry.get("losses", 0)), int(entry.get("draws", 0)),
        ]
        if entry.has("career_high_rank"):
            record += "  ·  최고 #%d" % int(entry["career_high_rank"])
        _label(detail, record, 11, MUTED, bold_font, true)
        var legacy := str(entry.get("legacy_name", ""))
        if not legacy.is_empty():
            var notes: Dictionary = {"active": "계승 중", "replaced": "교체됨", "abandoned": "보관하지 않음"}
            var legacy_status := str(notes.get(str(entry.get("legacy_status", "")), ""))
            _label(detail, legacy if legacy_status.is_empty() else "%s  ·  %s" % [legacy, legacy_status], 11, UI.GOLD_BRIGHT, bold_font, true)

func _section(parent: VBoxContainer, icon: StringName, caption: String) -> HBoxContainer:
    var heading := _row(parent, 5)
    Art.result_icon(heading, icon)
    _label(heading, caption, 16, UI.GOLD_BRIGHT, heading_font)
    return heading

func _picture(parent: Control, texture: Texture2D, left: float, right: float) -> TextureRect:
    var picture := TextureRect.new()
    picture.texture = texture
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(picture)
    picture.anchor_left = left
    picture.anchor_right = right
    picture.anchor_bottom = 1.0
    return picture

func _outlined(label: Label) -> void:
    label.add_theme_color_override("font_outline_color", INK)
    label.add_theme_constant_override("outline_size", 6)

func _center(label: Label) -> void:
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _panel(parent: Container, padding: int, edge: Color = UI.GOLD_DARK) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(PANEL, edge, padding))
    parent.add_child(panel)
    return panel

func _column(parent: Control, gap: int) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", gap)
    parent.add_child(column)
    return column

func _row(parent: Control, gap: int) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", gap)
    parent.add_child(row)
    return row

func _label(parent: Control, text: String, points: int, color: Color, font: Font, wrap: bool = false) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", points)
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_override("font", font)
    if wrap:
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label
