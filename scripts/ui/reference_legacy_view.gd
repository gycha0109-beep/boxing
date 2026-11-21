extends VBoxContainer

signal legacy_chosen(definition_id: String)
signal slot_replaced(slot_index: int)
signal legacy_abandoned()
signal next_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const Art := preload("res://scripts/ui/reference_result_art.gd")
const FEATHER := preload("res://scripts/ui/reference_result_portrait.gdshader")
const ARENA := preload("res://assets/visual/v0.7/arena/arena_title_night.png")
const BOXER_ART := preload("res://assets/visual/reference_v1/profile_boxer.png")
const TROPHY := preload("res://assets/visual/reference_v1/legacy_trophy.webp")
const MENTOR := preload("res://assets/visual/reference_v1/legacy_mentor.webp")
const TRAINING := preload("res://assets/visual/reference_v1/legacy_training.webp")
const RECOVERY := preload("res://assets/visual/reference_v1/legacy_recovery.webp")
const JAB := preload("res://assets/visual/reference_v1/legacy_jab.webp")
const INK := Color("#0b1118")
const METAL := Color("#151b20")
const PAPER := Color("#f6f1e5")
const MUTED := Color("#ccd0cf")
const GOLD_EDGE := Color("#c19a5c")
const TRAINING_EFFECTS := {
    "early_camp_growth_percent": "훈련 성장 +%d%%",
    "cycle_recovery_bonus": "피로 회복 +%d",
    "early_fatigue_reduction": "경기 피로 −%d",
    "training_power_percent": "파워 성장 +%d%%",
    "training_conditioning_percent": "체력 성장 +%d%%",
    "training_technique_bonus": "기술 훈련 +%d",
    "jab_training_bonus": "미트 훈련 +%d",
}

var boxer: Dictionary
var career: Dictionary
var profile: Dictionary
var meta: Dictionary
var pending: Dictionary
var selected: Dictionary
var candidates: Array
var definition_for: Callable
var ending: String
var notice: String
var milestone: Dictionary
var heading_font: Font
var bold_font: Font

var _submitted := false

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 7)
    _hero()
    _career_report()
    if not notice.is_empty():
        _copy(_card(self), notice, 12, Color("#ff9b87"))
    if not selected.is_empty():
        _confirmed()
    elif not pending.is_empty():
        _slot_decision()
    else:
        _choices()
    _successor()

func _hero() -> void:
    var panel := _card(self, 2, GOLD_EDGE)
    var art := Control.new()
    art.clip_contents = true
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var frame := panel.get_parent() as PanelContainer
    frame.add_child(art)
    frame.move_child(art, 0)
    var arena := AtlasTexture.new()
    arena.atlas = ARENA
    arena.region = Rect2(0, 139, 1080, 905)
    arena.filter_clip = true
    _art_layer(art, arena, 0.0, 1.0, 0.0, false).modulate = Color("#8c99a9")
    var boxer_crop := AtlasTexture.new()
    boxer_crop.atlas = BOXER_ART
    boxer_crop.region = Rect2(0, 0, 361, 453)
    boxer_crop.filter_clip = true
    _art_layer(art, boxer_crop, -0.03, 0.46, 56.0, true)
    _art_layer(art, TROPHY, 0.60, 1.015, 84.0, true, true)
    Art.glow(art, Vector2(0.5, 0.69), Vector2(218, 115), Color(0.03, 0.03, 0.04, 0.84))
    Art.glow(art, Vector2(0.5, 0.94), Vector2(281, 15), Color(1.0, 0.70, 0.33, 0.56))

    var content := panel
    content.add_theme_constant_override("separation", 3)
    var masthead := _row(content, 4)
    masthead.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(masthead, 28, UI.GOLD, false)
    _title(masthead, "LEGACY SELECTION", 36, PAPER, true).add_theme_font_override("font", UI.DISPLAY_FONT)
    Art.laurel(masthead, 28, UI.GOLD, true)
    var plaque := PanelContainer.new()
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    plaque.add_theme_stylebox_override("panel", Art.gold_plate(184, 23, Color("#b97731"), 2))
    content.add_child(plaque)
    var ribbon := _title(plaque, "NEXT GENERATION", 17, INK)
    ribbon.add_theme_font_override("font", UI.DISPLAY_FONT)
    ribbon.custom_minimum_size.x = 180
    var generation := int(meta.get("generation", 1))
    _copy(content, "%d세대  →  %d세대" % [generation, generation + 1], 12, UI.GOLD_BRIGHT, true)
    var space := Control.new()
    space.custom_minimum_size.y = 57
    space.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(space)
    _title(content, "체육관 유산", 32, UI.GOLD_BRIGHT, true)
    var tail := Control.new()
    tail.custom_minimum_size.y = 9
    tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(tail)

func _career_report() -> void:
    var report := _card(self, 7, GOLD_EDGE)
    var columns := _row(report, 4)
    var fighter := _summary_cell(columns, "은퇴한 선수")
    _title(fighter, str(boxer.get("name", "무명 복서")), 16, PAPER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _copy(fighter, str(profile.get("role", "코치")), 10, MUTED, true)
    _rule(columns, true)
    var record := _summary_cell(columns, "최종 전적")
    _title(record, "%d승 %d패 %d무" % [int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0))], 16, PAPER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _copy(record, "%d전" % int(career.get("fights", 0)), 10, MUTED, true)
    _rule(columns, true)
    var rankings := _summary_cell(columns, "최고 랭킹")
    _title(rankings, "#%d" % int(profile.get("career_high_rank", 50)), 19, UI.GOLD_BRIGHT)
    _copy(rankings, "최종 #%d · 최고 %dpt" % [int(career.get("rank", 50)), int(profile.get("career_high_points", 0))], 10, MUTED, true)
    _rule(report)
    _copy(report, ending, 11, PAPER, true)
    if not milestone.is_empty():
        var milestone_card := _card(self, 7, GOLD_EDGE)
        milestone_card.name = "LegacyMilestone"
        _title(milestone_card, "12전 커리어 평가", 15, UI.GOLD_BRIGHT)
        _copy(milestone_card, "%d전 %d승 %d패 %d무 · 랭킹 #%d (%+d계단)" % [
            int(milestone.get("fights", 0)), int(milestone.get("wins", 0)), int(milestone.get("losses", 0)),
            int(milestone.get("draws", 0)), int(milestone.get("rank", 50)), int(milestone.get("rank_gain", 0)),
        ], 11, PAPER, true)
        _copy(milestone_card, "인기 %+d · 평균 능력치 성장 %+.1f · 건강 %d · %s" % [
            int(milestone.get("fan_gain", 0)), float(milestone.get("skill_gain", 0.0)),
            int(milestone.get("health", 0)), str(milestone.get("injury", "부상 없음")),
        ], 11, MUTED, true)
        _copy(milestone_card, "세계 타이틀 도전 가능" if bool(milestone.get("title_ready", false)) else "세계 타이틀 도전 준비 중", 10, UI.GOLD_BRIGHT, true)

func _choices() -> void:
    _title(self, "다음 세대에게 전할 유산을 선택하세요", 17, UI.GOLD_BRIGHT)
    if candidates.is_empty():
        _copy(_card(self), "이 은퇴 기록에서 선택할 수 있는 유산이 없습니다.", 12, MUTED, true)
    else:
        var row := _row(self, 5)
        for definition: Dictionary in candidates:
            var card := _card(row, 4, GOLD_EDGE)
            _picture(card, _card_art(str(definition.get("category", ""))), 66)
            var name_label := _title(card, str(definition.get("name", "유산")), 14, UI.GOLD_BRIGHT)
            name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            name_label.custom_minimum_size.y = 33
            name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            var description := _copy(card, str(definition.get("description", "")), 10, PAPER, true)
            description.size_flags_vertical = Control.SIZE_EXPAND_FILL
            var effects := _card(card, 3, UI.GOLD_DARK)
            effects.custom_minimum_size.y = 39
            effects.alignment = BoxContainer.ALIGNMENT_CENTER
            _effect(effects, definition)
            var button := _action(card, "선택", func(): legacy_chosen.emit(str(definition.get("id", ""))), true)
            button.name = "LegacyChoose_" + str(definition.get("id", ""))
            button.tooltip_text = str(definition.get("name", ""))
    _slot_banner("선택한 유산 1개가 다음 제자에게 이어집니다.")

func _slot_decision() -> void:
    _title(self, "유산 슬롯이 가득 찼습니다", 18, UI.GOLD_BRIGHT)
    var incoming: Dictionary = definition_for.call(str(pending.get("definition_id", "")))
    var panel := _card(self, 7, GOLD_EDGE)
    _title(panel, "새 유산 · " + str(incoming.get("name", pending.get("definition_id", ""))), 15, UI.GOLD_BRIGHT)
    _effect(panel, incoming)
    _copy(panel, "기존 슬롯 하나를 교체하거나 새 유산을 포기하세요.", 12, PAPER, true)
    var slots: Array = meta.get("legacy_slots", [])
    for index in range(slots.size()):
        var slot: Dictionary = slots[index]
        var row := _row(_card(self), 7)
        var details := VBoxContainer.new()
        details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(details)
        var old: Dictionary = definition_for.call(str(slot.get("definition_id", "")))
        _copy(details, "%d.  %s" % [index + 1, str(old.get("name", slot.get("definition_id", "")))], 13, UI.GOLD_BRIGHT)
        _copy(details, "%d세대 · %s" % [int(slot.get("source_generation", 0)), str(slot.get("source_boxer_name", ""))], 11, MUTED)
        var replace := _action(row, "교체", func(): slot_replaced.emit(index), false)
        replace.name = "LegacyReplace_%d" % index
        replace.custom_minimum_size.x = 94
        replace.size_flags_horizontal = Control.SIZE_SHRINK_END
    var abandon := _action(self, "새 유산 포기 · 기존 슬롯 유지", func(): legacy_abandoned.emit(), false)
    abandon.name = "LegacyAbandon"
    _slot_banner("교체하거나 포기하면 다음 제자를 시작할 수 있습니다.")

func _confirmed() -> void:
    var abandoned := str(selected.get("legacy_status", "")) == "abandoned"
    _title(self, "유산 기록 완료" if abandoned else "유산 확정", 20, UI.GOLD_BRIGHT)
    var definition: Dictionary = definition_for.call(str(selected.get("definition_id", "")))
    var panel := _card(self, 8, GOLD_EDGE)
    _title(panel, str(definition.get("name", selected.get("definition_id", ""))), 18, PAPER)
    if abandoned:
        _copy(panel, "계보에 기록했습니다. 기존 슬롯의 유산이 다음 제자에게 이어집니다.", 12, MUTED, true)
    else:
        _copy(panel, str(definition.get("description", "")), 12, PAPER, true)
        _effect(panel, definition)
    var slots: Array = meta.get("legacy_slots", [])
    if not slots.is_empty():
        var list := _card(self)
        for index in range(slots.size()):
            var slot: Dictionary = slots[index]
            var entry: Dictionary = definition_for.call(str(slot.get("definition_id", "")))
            _copy(list, "%d. %s  ·  %s" % [
                index + 1, str(entry.get("name", slot.get("definition_id", ""))), str(slot.get("source_boxer_name", "")),
            ], 12, MUTED)
    _slot_banner("체육관에 보관된 유산은 다음 세대로 이어집니다.")

func _slot_banner(detail: String) -> void:
    var row := _row(_card(self, 7, GOLD_EDGE), 7)
    var slots: Array = meta.get("legacy_slots", [])
    var count := _title(row, "유산 슬롯 %d / %d" % [slots.size(), int(meta.get("legacy_capacity", 3))], 14, UI.GOLD_BRIGHT)
    count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _rule(row, true)
    _copy(row, detail, 11, PAPER).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _successor() -> void:
    var panel := _card(self, 2, GOLD_EDGE if not selected.is_empty() else UI.GOLD_DARK)
    var art := Control.new()
    art.clip_contents = true
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var frame := panel.get_parent() as PanelContainer
    frame.add_child(art)
    frame.move_child(art, 0)
    var mentor_crop := AtlasTexture.new()
    mentor_crop.atlas = MENTOR
    mentor_crop.region = Rect2(22, 0, 328, 137)
    mentor_crop.filter_clip = true
    _art_layer(art, mentor_crop, 0.0, 0.54, 0.0, false).modulate.a = 0.85
    Art.glow(art, Vector2(0.53, 0.06), Vector2(288, 20), Color(1.0, 0.72, 0.33, 0.68))
    var row := _row(panel, 4)
    var space := Control.new()
    space.mouse_filter = Control.MOUSE_FILTER_IGNORE
    space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(space)
    var next := _action(row, "다음 제자 시작  »", func(): next_requested.emit(), true)
    next.name = "LegacyStartSuccessor"
    next.disabled = selected.is_empty()
    next.custom_minimum_size = Vector2(238, 61)
    next.add_theme_font_size_override("font_size", 19)

func _effect(parent: Container, definition: Dictionary) -> void:
    var effect: Dictionary = definition.get("effect", {})
    var formatted: Array[String] = []
    for key: String in TRAINING_EFFECTS:
        if effect.has(key):
            formatted.append(str(TRAINING_EFFECTS[key]) % int(effect[key]))
    if formatted.is_empty():
        _copy(parent, "경기 효과 준비 중", 10, MUTED, true)
        return
    _copy(parent, "\n".join(formatted), 11, UI.GOLD_BRIGHT, true)
    var limits: Array[String] = []
    if effect.has("camp_limit"):
        limits.append("초반 %d캠프" % int(effect["camp_limit"]))
    if effect.has("fight_limit"):
        limits.append("첫 %d경기" % int(effect["fight_limit"]))
    if effect.has("cap"):
        limits.append("중첩 상한 %d" % int(effect["cap"]))
    if not limits.is_empty():
        _copy(parent, " · ".join(limits), 9, MUTED, true)

func _card_art(category: String) -> Texture2D:
    match category:
        "recovery", "fatigue_defense", "training_conditioning":
            return RECOVERY
        "early_growth", "training_power":
            return TRAINING
        _:
            return JAB

func _action(parent: Container, text: String, callback: Callable, primary: bool) -> Button:
    var button := UI.action_button(text, heading_font, primary)
    button.custom_minimum_size.y = 46
    if primary:
        button.add_theme_stylebox_override("normal", Art.gold_plate(148, 46, Color("#b9813a"), 3))
        button.add_theme_stylebox_override("hover", Art.gold_plate(148, 46, Color("#dca650"), 3))
        button.add_theme_stylebox_override("pressed", Art.gold_plate(148, 46, Color("#98602b"), 3))
        button.add_theme_stylebox_override("disabled", UI.beveled_panel_style(Color("#27241d"), UI.GOLD_DARK, 2))
    button.pressed.connect(func():
        if _submitted or button.disabled or is_queued_for_deletion():
            return
        _submitted = true
        callback.call()
    )
    parent.add_child(button)
    return button

func _art_layer(parent: Control, texture: Texture2D, left: float, right: float, top: float, blend: bool, mirror: bool = false) -> TextureRect:
    var art := _picture(parent, texture, 0)
    art.anchor_left = left
    art.anchor_right = right
    art.anchor_bottom = 1.0
    art.offset_top = top
    if blend:
        var material := ShaderMaterial.new()
        material.shader = FEATHER
        material.set_shader_parameter("mirror_fade", mirror)
        material.set_shader_parameter("spotlight", 0.78)
        art.material = material
        art.resized.connect(func(): material.set_shader_parameter("portrait_size", art.size))
    return art

func _picture(parent: Control, texture: Texture2D, height: int) -> TextureRect:
    var picture := TextureRect.new()
    picture.texture = texture
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    picture.custom_minimum_size.y = height
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(picture)
    return picture

func _card(parent: Container, padding: int = 6, edge: Color = UI.GOLD_DARK) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(METAL, edge, padding))
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    parent.add_child(panel)
    panel.add_child(content)
    return content

func _row(parent: Control, gap: int) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", gap)
    parent.add_child(row)
    return row

func _summary_cell(row: HBoxContainer, caption: String) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 1)
    row.add_child(column)
    _copy(column, caption, 11, UI.GOLD_BRIGHT, true)
    return column

func _rule(parent: Container, vertical: bool = false) -> void:
    var rule := ColorRect.new()
    rule.color = Color("#96703f75")
    rule.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(rule)

func _title(parent: Control, text: String, size: int, color: Color, outlined: bool = false) -> Label:
    var label := _copy(parent, text, size, color, true)
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.add_theme_font_override("font", heading_font)
    if outlined:
        label.add_theme_color_override("font_outline_color", INK)
        label.add_theme_constant_override("outline_size", 6)
    return label

func _copy(parent: Control, text: String, size: int, color: Color, centered: bool = false) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_override("font", bold_font)
    label.add_theme_constant_override("line_spacing", 1)
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    if centered:
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label
