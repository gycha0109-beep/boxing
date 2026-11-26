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
var actions_seen: Array = []
var font: Font


func _ready() -> void:
    name = "FirstCycleStory"
    add_theme_constant_override("separation", 10)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if mode == "welcome":
        size_flags_vertical = Control.SIZE_EXPAND_FILL
        alignment = BoxContainer.ALIGNMENT_CENTER
    match mode:
        "welcome":
            _welcome_prompt()
        "overview":
            _heading("복서의 첫 번째 도전", "한 경기를 준비하는 과정")
            var cards := [
                ["01  훈련", "선수의 능력치와 컨디션을 관리합니다."],
                ["02  경기 계약", "상대를 살펴보고 싸울 경기를 정합니다."],
                ["03  경기 준비", "상대를 분석하고 맞춤 게임플랜을 고릅니다."],
                ["04  링 위의 선택", "상대 행동을 읽고 다섯 가지 기술로 승부합니다."],
                ["05  경기 정산", "승패와 보상을 확인하고 다음 도전을 시작합니다."],
            ]
            for card in cards:
                _info(str(card[0]), str(card[1]))
            _coach("하나씩 직접 해보자.\n먼저 네 복싱 스타일을 정해.")
            _button("내 복서 만들기", func(): next_requested.emit())
            _skip_button()
        "training_result":
            _label(self, "4/10 · 첫 훈련 결과", 16, GOLD)
            _hero(TRAINING, "훈련 완료", "네 능력치가 실제로 변했어.", 180)
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
            _coach("좋아. 방금 훈련한 결과는 네 능력치에 반영됐어.\n이제 첫 상대를 직접 골라보자.")
            _button("경기 제안 확인", func(): next_requested.emit())
            _skip_button()
        "finished":
            _label(self, "10/10 · 첫 경기 완료", 16, GOLD)
            _hero(BOXER, "FIRST BOUT COMPLETE", "네 첫 프로 경기가 끝났어.", 185)
            _info("✓ 훈련", "훈련으로 네 능력치를 키우고 피로를 관리할 수 있어.")
            _info("✓ 경기 준비", "상대의 약점에 맞춰 네 게임플랜을 고를 수 있어.")
            var controls := [
                ["jab", "잽으로 거리 조절하기", "잽은 안전하게 공격을 시작하는 기본 기술입니다."],
                ["guard", "가드로 방어하기", "가드는 상대 공격을 막고 피해를 줄입니다."],
                ["counter", "상대의 빈틈에 카운터하기", "상대 공격 직후 반격하면 유리합니다."],
            ]
            var all_controls_seen := true
            for control in controls:
                var completed := str(control[0]) in actions_seen
                all_controls_seen = all_controls_seen and completed
                _info(("✓ " if completed else "○ ") + str(control[1]), str(control[2]))
            _coach("좋아. 잽·가드·카운터를 익혔어.\n이제부터 네 커리어는 네가 직접 이끌어." if all_controls_seen else "첫 경기를 마쳤어.\n아직 익히지 못한 기술은 다음 경기에서 직접 써보자.")
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


func _welcome_prompt() -> void:
    var shell := PanelContainer.new()
    shell.name = "TutorialConsentDialog"
    shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    shell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#0b1420")
    style.border_color = Color("#a77b3c")
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
    style.shadow_size = 16
    style.content_margin_left = 20
    style.content_margin_right = 20
    style.content_margin_top = 22
    style.content_margin_bottom = 20
    shell.add_theme_stylebox_override("panel", style)
    add_child(shell)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 14)
    shell.add_child(content)

    var eyebrow := _label(content, "TWELVE COUNT  /  FIRST CAREER", 10, GOLD)
    eyebrow.add_theme_font_override("font", UI.DISPLAY_FONT)
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var rule := ColorRect.new()
    rule.custom_minimum_size = Vector2(0, 1)
    rule.color = Color("#6f542f")
    content.add_child(rule)

    var title := _label(content, "첫 커리어를 시작합니다", 23, WHITE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_override("font", UI.DISPLAY_FONT)

    var question := _label(content, "기본 조작과 첫 경기를 관장에게 안내받으시겠습니까?", 14, MUTED)
    question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var actions := VBoxContainer.new()
    actions.add_theme_constant_override("separation", 8)
    content.add_child(actions)

    var yes := UI.action_button("예, 안내받겠습니다", font, true)
    yes.name = "TutorialAccept"
    yes.custom_minimum_size.y = 54
    yes.pressed.connect(func(): next_requested.emit())
    actions.add_child(yes)

    var no := Button.new()
    no.name = "TutorialDecline"
    no.text = "아니요, 바로 시작하겠습니다"
    no.custom_minimum_size.y = 44
    no.flat = true
    no.add_theme_font_size_override("font_size", 13)
    no.add_theme_color_override("font_color", MUTED)
    no.pressed.connect(func(): skip_requested.emit())
    actions.add_child(no)


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
