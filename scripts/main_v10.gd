extends "res://scripts/main_v08.gd"

const RELEASE_FONT_PATH := "res://assets/fonts/NotoSansKR-VF.ttf"
const RELEASE_FONT_LICENSE_PATH := "res://assets/fonts/OFL-NotoSansKR.txt"
const MOBILE_SCROLL_DEADZONE := 7

func _ready() -> void:
    super._ready()
    _configure_mobile_scroll()

func _render_phase() -> void:
    super._render_phase()
    _configure_mobile_scroll()

func _render_fight() -> void:
    super._render_fight()
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
