extends "res://scripts/main_v14.gd"

var music_director: MusicDirector

func _ready() -> void:
    super._ready()
    _sync_music_for_phase()
    call_deferred("_wire_ui_sounds")

func _render_phase() -> void:
    super._render_phase()
    _sync_music_for_phase()
    call_deferred("_wire_ui_sounds")

func _render_fight(animated_exchange: Dictionary = {}) -> void:
    super._render_fight(animated_exchange)
    _sync_music_for_phase()
    call_deferred("_wire_ui_sounds")

func _choose_fight_action(action: String) -> void:
    if fight_input_locked:
        return
    super._choose_fight_action(action)
    _music().duck(0.52)
    _sync_music_for_phase()

func _notification(what: int) -> void:
    super._notification(what)
    if not is_instance_valid(music_director):
        return
    if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
        music_director.set_suspended(true)
    elif what == MainLoop.NOTIFICATION_APPLICATION_RESUMED:
        music_director.set_suspended(false)

func _sync_music_for_phase() -> void:
    if GameState == null:
        return
    var phase := str(GameState.state.get("phase", "")) if not GameState.state.is_empty() else ""
    _music().set_mode(MusicDirector.mode_for_phase(phase, launch_gate_active))

func _music() -> MusicDirector:
    if is_instance_valid(music_director):
        return music_director
    music_director = MusicDirector.new()
    music_director.name = "MusicDirector"
    add_child(music_director)
    return music_director

func _wire_ui_sounds() -> void:
    if not is_instance_valid(body):
        return
    _wire_ui_sounds_under(body)

func _wire_ui_sounds_under(node: Node) -> void:
    if node == null:
        return
    for child in node.get_children():
        if child is Button:
            var button := child as Button
            if not button.has_meta("ui_sound_bound"):
                button.set_meta("ui_sound_bound", true)
                button.pressed.connect(Callable(self, "_play_button_sound").bind(button))
        _wire_ui_sounds_under(child)

func _play_button_sound(button: Button) -> void:
    if button == null or button.disabled:
        return
    var text := button.text
    var cue := "click"
    if str(GameState.state.get("phase", "")) == "fight":
        cue = "fight_select"
    elif "구매" in text:
        cue = "purchase"
    elif "돌아" in text or "다시" in text or "←" in text:
        cue = "back"
    elif "시작" in text or "확정" in text or "계체" in text or "다음 제자" in text:
        cue = "confirm"
    _music().play_ui(cue)
