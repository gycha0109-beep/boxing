extends VBoxContainer

signal purchase_requested(section: String, item_id: String)
signal section_requested(section: String)
signal back_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const Art := preload("res://scripts/ui/reference_result_art.gd")
const GYM := preload("res://assets/visual/v0.7/arena/arena_gym_basic.png")
const TACTICS := preload("res://assets/visual/reference_v1/tactical_art.png")
const ACTIONS := preload("res://assets/visual/reference_v1/battle_actions.png")
const BAG := preload("res://assets/visual/reference_v1/training_bag.png")
const ROADWORK := preload("res://assets/visual/reference_v1/training_running.png")
const GLOVES := preload("res://assets/visual/reference_v1/legacy_jab.webp")
const STATS := {"power": "파워", "speed": "스피드", "technique": "테크닉", "defense": "수비", "conditioning": "체력"}
const INK := Color("#09131e")
const PANEL := Color("#141e29")
const PAPER := Color("#f7f3e8")
const MUTED := Color("#c4ccd3")
const GREEN := Color("#a3dfaa")
const RED := Color("#f0a08f")

var section := "personal"
var slots: Array[Dictionary]
var receipt: Dictionary
var money: int
var spent: int
var unavailable := false
var purchase_complete := false
var money_text: Callable
var heading_font: Font
var bold_font: Font

var _submitted := false

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 7)
    _hero()
    if unavailable:
        var info := _column(_panel(self), 4)
        _label(info, "장비 구매는 다음 캠프에서 가능합니다.", 17, UI.GOLD_BRIGHT, heading_font, true)
        _label(info, "개인 장비는 능력치를 높이고, 체육관 장비는 해당 훈련의 성장 효율을 높입니다.", 13, MUTED, null, true)
    else:
        _wallet()
        if purchase_complete:
            var notice := _column(_panel(self, 6, UI.GOLD), 2)
            _label(notice, "이번 캠프의 장비 구매를 완료했습니다.", 14, UI.GOLD_BRIGHT, heading_font, true)
            _label(notice, "구매 결과를 확인한 뒤 경기 제안으로 이동할 수 있습니다.", 12, MUTED, bold_font, true)
        _tabs()
        for item in slots:
            _item(item)
    var back_label := "현재 단계로 돌아가기" if unavailable else ("경기 제안으로 이동" if purchase_complete else "캠프로 돌아가기")
    var back := UI.action_button(back_label, bold_font)
    back.name = "EquipmentShopBack"
    back.pressed.connect(func(): back_requested.emit())
    add_child(back)

func _hero() -> void:
    var frame := _panel(self, 3)
    var layer := Control.new()
    layer.clip_contents = true
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(layer)
    var art := _picture(layer, GYM)
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    art.modulate = Color("#8e98a5")
    Art.glow(layer, Vector2(0.5, 0.42), Vector2(330, 131), Color(0.02, 0.04, 0.07, 0.87))
    var stack := _column(frame, 2)
    stack.custom_minimum_size.y = 102
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    var line := _row(stack, 6)
    line.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(line, 31, UI.GOLD, false)
    var title := _label(line, "EQUIPMENT SHOP", 35, PAPER, UI.DISPLAY_FONT)
    title.add_theme_color_override("font_outline_color", INK)
    title.add_theme_constant_override("outline_size", 6)
    Art.laurel(line, 31, UI.GOLD, true)
    var tag := _label(stack, "장비 · 체육관 투자", 14, UI.GOLD_BRIGHT, heading_font)
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tag.add_theme_color_override("font_outline_color", INK)
    tag.add_theme_constant_override("outline_size", 5)

func _wallet() -> void:
    var row := _row(_panel(self), 12)
    var wallet := _column(row, 0)
    wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(wallet, "보유금", 11, UI.GOLD_BRIGHT, bold_font)
    var balance := _label(wallet, _money(money), 22, PAPER, heading_font)
    balance.name = "EquipmentWallet"
    var total := _column(row, 0)
    var caption := _label(total, "이번 커리어 장비 투자", 11, MUTED, bold_font)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    var outlay := _label(total, _money(spent), 15, UI.GOLD_BRIGHT, bold_font)
    outlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _tabs() -> void:
    var row := _row(self, 6)
    for id in ["personal", "gym"]:
        var selected: bool = id == section
        var tab := UI.action_button("개인 장비" if id == "personal" else "체육관 장비", bold_font)
        tab.name = "EquipmentTab_" + id
        tab.custom_minimum_size.y = 45
        var edge := UI.GOLD_BRIGHT if selected else UI.GOLD_DARK
        tab.add_theme_color_override("font_color", UI.GOLD_BRIGHT if selected else PAPER)
        tab.add_theme_stylebox_override("normal", UI.beveled_panel_style(Color("#332518") if selected else INK, edge, 4))
        tab.add_theme_stylebox_override("hover", UI.beveled_panel_style(Color("#293340"), edge, 4))
        tab.pressed.connect(func():
            if id != section and not _submitted:
                _submitted = true
                section_requested.emit(id)
        )
        row.add_child(tab)

func _item(data: Dictionary) -> void:
    var current: Dictionary = data["current"]
    var upgrade: Dictionary = data["upgrade"]
    var slot := str(data["slot"])
    var card := _panel(self, 7, UI.GOLD if receipt.get("slot") == slot else UI.GOLD_DARK)
    card.name = "EquipmentSlot_" + slot
    var body := _column(card, 8)
    var item := upgrade if not upgrade.is_empty() else current
    var top := _row(body, 7)
    var picture := _picture(top, _item_art(slot))
    picture.custom_minimum_size = Vector2(75, 65)
    var names := _column(top, 4)
    names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(names, "%s  ·  보유 %s" % [str(data["label"]), str(current.get("name", "기본 장비"))], 11, MUTED, bold_font, true)
    _label(names, str(item.get("name", "")), 17, PAPER, heading_font, true)
    if not upgrade.is_empty():
        var price := _label(names, "구매가  " + _money(int(upgrade["price"])), 14, UI.GOLD_BRIGHT, bold_font)
        price.name = "EquipmentPrice_" + slot

    if str(receipt.get("slot", "")) == slot:
        _purchase_receipt(body)
    if upgrade.is_empty():
        _label(body, "최대 단계", 12, UI.GOLD_BRIGHT, bold_font)
        return

    var effect := _column(_panel(body, 7), 5)
    if section == "personal":
        _stats(effect, data.get("stat_changes", {}))
    else:
        var from := int(current.get("training_percent", 0))
        var to := int(upgrade.get("training_percent", 0))
        _label(effect, "%s 성장 효율  +%d%%  →  +%d%%" % [str(data.get("training_names", "해당 훈련")), from, to], 12, GREEN, bold_font, true)

    var eligibility: Dictionary = data["eligibility"]
    var actions := _row(body, 10)
    var buy := UI.action_button("구매", heading_font, true)
    buy.disabled = not bool(eligibility.get("ok", false))
    var reason := ""
    match str(eligibility.get("reason", "")):
        "locked":
            reason = str(eligibility.get("unlock", "잠금 해제 조건 미충족"))
            buy.text = "잠김"
        "money":
            reason = "부족한 금액  " + _money(int(upgrade["price"]) - money)
            buy.text = "자금 부족"
        "activity_used":
            reason = "이번 캠프 활동을 이미 사용했습니다."
            buy.text = "활동 완료"
        "":
            reason = "관리 기회 사용 · 구매 후  " + _money(money - int(upgrade["price"]))
        _:
            reason = "구매 조건을 충족하지 못했습니다."
            buy.text = "구매 불가"
    var note := _label(actions, reason, 11, RED if buy.disabled else MUTED, bold_font, true)
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    buy.name = "BuyEquipment_" + str(upgrade["id"])
    buy.custom_minimum_size = Vector2(120, 49)
    buy.size_flags_horizontal = Control.SIZE_SHRINK_END
    buy.pressed.connect(func():
        if not _submitted and not buy.disabled:
            _submitted = true
            purchase_requested.emit(section, str(upgrade["id"]))
    )
    actions.add_child(buy)

func _purchase_receipt(parent: VBoxContainer) -> void:
    var box := _column(_panel(parent, 6, UI.GOLD), 1)
    var paid := _label(box, "구매 완료 · %s" % str(receipt.get("name", "")), 13, UI.GOLD_BRIGHT, heading_font, true)
    paid.name = "EquipmentReceipt"
    _label(box, "보유금  %s  →  %s" % [_money(int(receipt["before_money"])), _money(money)], 12, PAPER, bold_font, true)
    if section == "personal":
        _stats(box, receipt.get("stat_changes", {}))
    else:
        _label(box, "훈련 성장 효율  +%d%%  →  +%d%%" % [int(receipt["old_efficiency"]), int(receipt["new_efficiency"])], 12, GREEN, bold_font)

func _stats(parent: VBoxContainer, stats: Dictionary) -> void:
    if stats.is_empty():
        _label(parent, "능력치 변동 없음", 12, MUTED, bold_font)
        return
    for key in stats:
        var change: Dictionary = stats[key]
        var from := int(change["from"])
        var to := int(change["to"])
        var suffix := "상한 도달" if from == to and to == 100 else ("%+d" % (to - from))
        var tint := GREEN if to > from else (RED if to < from else MUTED)
        _label(parent, "%s  %d  →  %d  (%s)" % [str(STATS.get(key, key)), from, to, suffix], 12, tint, bold_font, true)

func _item_art(slot: String) -> Texture2D:
    match slot:
        "gloves": return GLOVES
        "shoes": return _atlas(TACTICS, Rect2(0, 0, 216, 108))
        "mouthguard", "defense": return _atlas(ACTIONS, Rect2(450, 0, 150, 145))
        "mitts": return _atlas(TACTICS, Rect2(0, 324, 216, 108))
        "heavy_bag": return BAG
        "roadwork": return ROADWORK
        _: return GYM

func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
    var art := AtlasTexture.new()
    art.atlas = texture
    art.region = region
    art.filter_clip = true
    return art

func _money(amount: int) -> String:
    return "%s원" % money_text.call(amount)

func _picture(parent: Control, texture: Texture2D) -> TextureRect:
    var picture := TextureRect.new()
    picture.texture = texture
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(picture)
    return picture

func _panel(parent: Container, padding: int = 8, edge: Color = UI.GOLD_DARK) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(PANEL, edge, padding))
    parent.add_child(panel)
    return panel

func _row(parent: Control, gap: int) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", gap)
    parent.add_child(row)
    return row

func _column(parent: Control, gap: int) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", gap)
    parent.add_child(column)
    return column

func _label(parent: Control, text: String, size: int, color: Color, font: Font = null, wrap: bool = false) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    if font != null:
        label.add_theme_font_override("font", font)
    if wrap:
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label
