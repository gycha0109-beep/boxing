extends VBoxContainer

signal next_requested()
signal skip_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const RING := preload("res://assets/visual/reference_v1/title_ring.webp")
const BOXER := preload("res://assets/visual/reference_v1/title_boxer.webp")
const TACTICS := preload("res://assets/visual/reference_v1/title_tactics.webp")
const TRAINING := preload("res://assets/visual/reference_v1/training_bag.png")
const COACH := preload("res://assets/visual/reference_v1/legacy_mentor.webp")
const GOLD := Color("#e9b65a")
const WHITE := Color("#f7f2e8")
const MUTED := Color("#c6ccd4")

var mode := "welcome"
var training_result: Dictionary = {}
var boxer: Dictionary = {}
var font: Font


func _ready() -> void:
    name = "FirstCycleStory"
    add_theme_constant_override("separation", 10)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    match mode:
        "welcome":
            _hero(RING, "TWELVE COUNT", "한 명의 복서를 키워 첫 경기에 도전하세요.", 225)
            _coach("처음부터 함께하지.\n선수를 만들고, 훈련하고, 링 위에서 직접 싸워보자.")
            _button("튜토리얼 시작", func(): next_requested.emit())
            _skip_button()
        "overview":
            _heading("복서의 첫 번째 도전", "한 경기를 준비하는 과정")
            var cards := [
                ["01  훈련", "선수의 능력치와 컨디션을 관리합니다."],
                ["02  경기 계약", "상대를 살펴보고 싸울 경기를 정합니다."],
                ["03  경기 준비", "전술과 몸 상태를 결정하고 상대를 분석합니다."],
                ["04  링 위의 선택", "상대 행동을 읽고 다섯 가지 기술로 승부합니다."],
                ["05  경기 정산", "승패와 보상을 확인하고 다음 도전을 시작합니다."],
            ]
            for card in cards:
                _info(str(card[0]), str(card[1]))
            _coach("하나씩 해보면 어렵지 않아.\n이제 네 선수부터 만들어보자.")
            _button("내 복서 만들기", func(): next_requested.emit())
            _skip_button()
        "training_result":
            _label(self, "4/12 · 첫 훈련 결과", 16, GOLD)
            _hero(TRAINING, "훈련 완료", "선수의 능력치가 실제로 변했습니다.", 180)
            var changes: Dictionary = training_result.get("changes", {})
            var names := {"power":"파워", "speed":"스피드", "technique":"테크닉", "defense":"수비", "conditioning":"지구력", "fatigue":"피로", "health":"건강", "weight":"체중"}
            var any_effect := false
            for key in changes:
                any_effect = true
                var amount := float(changes[key])
                var suffix := "kg" if str(key) == "weight" else ""
                _info(str(names.get(key, key)), "%+.1f%s" % [amount, suffix] if suffix != "" else "%+d" % int(round(amount)))
            if not any_effect:
                _info("훈련 결과", "능력치 변화가 없거나 상한에 도달했습니다.")
            if not str(training_result.get("injury", "")).is_empty():
                _info("부상", str(training_result["injury"]))
            _coach("잘했어. 이 변화는 실제 커리어에 남는다.\n이제 어떤 선수와 싸울지 정해보자.")
            _button("경기 제안 확인", func(): next_requested.emit())
        "finished":
            _hero(BOXER, "FIRST BOUT COMPLETE", "첫 프로 경기를 마쳤습니다.", 185)
            _info("✓ 훈련", "선수를 성장시키고 피로를 관리할 수 있습니다.")
            _info("✓ 경기 준비", "상대를 분석해 전술과 몸 상태를 선택할 수 있습니다.")
            _info("✓ 실제 전투", "상대 움직임을 읽고 직접 행동을 선택할 수 있습니다.")
            _coach("좋아, 기본은 충분하다.\n이제부터는 네가 직접 커리어를 이끌어간다.")
            _button("자유 커리어 시작", func(): next_requested.emit())


func _hero(image: Texture2D, title: String, subtitle: String, height: int) -> void:
    var frame := _frame(self)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 6)
    frame.add_child(content)
    var photo := TextureRect.new()
    photo.texture = image
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    photo.custom_minimum_size.y = height
    content.add_child(photo)
    var heading := _label(content, title, 33, GOLD)
    heading.add_theme_font_override("font", UI.DISPLAY_FONT)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var text := _label(content, subtitle, 14, WHITE)
    text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _heading(title: String, subtitle: String) -> void:
    var panel := _frame(self)
    _label(panel, title, 26, GOLD)
    _label(panel, subtitle, 13, MUTED)


func _coach(message: String) -> void:
    var row := HBoxContainer.new()
    row.name = "TutorialCoachDialogue"
    row.add_theme_constant_override("separation", 8)
    add_child(row)
    var face := TextureRect.new()
    face.texture = COACH
    face.custom_minimum_size = Vector2(78, 92)
    face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    row.add_child(face)
    var balloon := _frame(row)
    balloon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(balloon, "관장", 12, GOLD)
    var text := _label(balloon, message, 13, WHITE)
    text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _info(title: String, description: String) -> void:
    var panel := _frame(self)
    panel.name = "TutorialInfo"
    _label(panel, title, 16, GOLD)
    var detail := _label(panel, description, 13, WHITE)
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _frame(parent: Container) -> VBoxContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", UI.beveled_panel_style(Color("#101c29"), UI.GOLD_DARK, 9))
    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(frame)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    frame.add_child(content)
    return content


func _label(parent: Container, value: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    if font != null:
        label.add_theme_font_override("font", font)
    parent.add_child(label)
    return label


func _button(title: String, callback: Callable) -> void:
    var button := UI.action_button(title, font, true)
    button.name = "TutorialNext"
    button.custom_minimum_size.y = 60
    button.pressed.connect(callback)
    add_child(button)


func _skip_button() -> void:
    var button := Button.new()
    button.name = "TutorialSkip"
    button.text = "튜토리얼 건너뛰기"
    button.flat = true
    button.custom_minimum_size.y = 44
    button.pressed.connect(func(): skip_requested.emit())
    add_child(button)
