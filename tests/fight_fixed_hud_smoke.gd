extends SceneTree

const Save = preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    _cleanup_save_files()
    await process_frame

    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState unavailable")
    if not is_instance_valid(game_state):
        _finish()
        return

    var opponents: Array = _load_array("res://data/opponents.json")
    _check(not opponents.is_empty(), "fight HUD fixture has no opponents")
    if opponents.is_empty():
        _finish()
        return

    game_state.rng.seed = 237
    game_state.new_career("HUD Boxer", "technician")
    game_state.state.boxer.weight_kg = 61.0
    game_state.state["first_launch_acknowledged"] = true
    game_state.state["weigh_in_acknowledged"] = true
    game_state.state.phase = "fight_offer"
    var opponent: Dictionary = opponents[0]
    game_state.select_opponent(opponent)
    var selected: Dictionary = game_state.select_game_plan("outside_boxing")
    _check(bool(selected.get("ok", false)), "fight HUD fixture could not select plan")

    game_state.state["fight_seed"] = 237
    var packed: PackedScene = load("res://scenes/Main.tscn")
    _check(is_instance_valid(packed), "Main scene could not load")
    if not is_instance_valid(packed):
        _finish()
        return

    main_view = packed.instantiate()
    main_view.set("current_opponent", opponent)
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    _check(str(main_view.get_script().resource_path) == "res://scripts/main_v18_release.gd", "fight HUD is not using the active release shell")

    var scroll := _find_scroll(main_view)
    _check(is_instance_valid(scroll), "fight HUD has no ScrollContainer")
    if is_instance_valid(scroll):
        _check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "fight screen still allows vertical scrolling")
        _check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "fight screen allows horizontal scrolling")
        _check(scroll.scroll_vertical == 0, "fight HUD did not reset to the top")

    var stage := _find_stage(main_view)
    _check(is_instance_valid(stage), "fight HUD has no visible FightStage")
    if is_instance_valid(stage):
        _check(stage.custom_minimum_size.y >= 340.0, "fight stage is too short to remain the visual focus")

    var text := "\n".join(_collect_text(main_view))
    _check(text.contains("ROUND 1"), "fight HUD has no round header")
    _check(text.contains("상대 읽기"), "fight HUD has no Korean tactical read strip")
    _check(text.contains("FIGHT NIGHT"), "fight HUD shows the fight title")
    _check(not text.contains("OPPONENT READ"), "legacy English opponent-read card remains on fight screen")
    _check(not text.contains("★ PLAN"), "legacy PLAN copy remains inside action buttons")
    _check(not text.contains("상대 몸통 상태:"), "legacy long tactical copy still occupies the fight screen")

    var bottom_nav := main_view.find_child("V19BottomNav", true, false) as Control
    _check(is_instance_valid(bottom_nav), "redesigned shell has no named bottom navigation")
    if is_instance_valid(bottom_nav):
        _check(not bottom_nav.visible, "app bottom navigation remains visible during live combat")

    for chrome_name in ["V19MenuButton", "V19MoneyBox", "V19SettingsButton"]:
        var chrome := main_view.find_child(chrome_name, true, false) as Control
        _check(is_instance_valid(chrome), "missing phase-aware chrome node: " + chrome_name)
        if is_instance_valid(chrome):
            _check(chrome.visible == (chrome_name == "V19SettingsButton" and main_view._dev_reset_enabled()), "non-combat app chrome remains visible during fight: " + chrome_name)

    var actions := main_view.find_child("V19FightActions", true, false) as HBoxContainer
    _check(is_instance_valid(actions), "fight HUD has a single action row")
    _check(_direct_button_count(actions) == 5, "all actions share one row")

    var ids := ["jab", "power", "body", "guard", "counter"]
    var labels := ["잽", "강타", "바디", "가드", "카운터"]
    for index in range(ids.size()):
        var button := main_view.find_child("FightAction_" + ids[index], true, false) as Button
        _check(button != null and button.text.begins_with(labels[index]) and button.icon != null, "live action card: " + ids[index])
        if button != null and scroll != null:
            _check(scroll.get_global_rect().encloses(button.get_global_rect()), "the action is fully inside the fixed HUD")
    _check_hud_values()
    await _play_bout()
    _finish()

func _play_bout() -> void:
    var sequence := ["guard", "jab", "counter", "body", "power", "jab", "guard", "counter", "power"]
    var used: Array[String] = []
    var ring_top := (main_view.find_child("FightRingFrame", true, false) as Control).get_global_rect().position.y
    for id in sequence:
        var button := main_view.find_child("FightAction_" + id, true, false) as Button
        _check(button != null and not button.disabled, id + " is available on the live screen")
        if button == null:
            break
        var previous := int(main_view.combat.snapshot()["exchange"])
        button.pressed.emit()
        button.pressed.emit()
        var next: Dictionary = main_view.combat.snapshot()
        _check(int(next["exchange"]) == previous + 1, id + " is consumed exactly once")
        _check(str(next["last_exchange"]["player_action"]) == id, "the selected action reaches the combat engine")
        used.append(id)
        await create_timer(0.40).timeout
        _check_hud_values()
        var stage := _find_stage(main_view)
        var ring := main_view.find_child("FightRingFrame", true, false) as Control
        _check(stage != null and ring != null and is_equal_approx(stage.position.y, 0.0), "impact shake restores the visual surface")
        _check(ring != null and is_equal_approx(ring.get_global_rect().position.y, ring_top), "animation keeps the fixed layout")
        if bool(next["finished"]):
            break
        var saved := Save.load_game()
        _check(int(saved["active_fight"]["exchange_no"]) == int(next["exchange"]), "the exchange is saved")
    for id in ["jab", "power", "body", "guard", "counter"]:
        _check(id in used, id + " participated in the bout")
    _check(bool(main_view.combat.snapshot()["finished"]), "bout reached a result")
    _check(int(game_state.state["career"]["fights"]) == 1, "the first bout is settled once")
    var settle := main_view.find_child("FightSettlement", true, false) as Button
    _check(settle != null and game_state.state["phase"] == "result", "the result can be opened")
    if settle != null:
        settle.pressed.emit()
        await process_frame
        await process_frame
        _check(main_view.find_child("ReferenceBattle", true, false) == null, "the settlement opens the result screen")
        _check(int(Save.load_game()["career"]["fights"]) == 1, "the result remains saved")

func _check_hud_values() -> void:
    var snapshot: Dictionary = main_view.combat.snapshot()
    var meters := {
        "FightPlayerHealth": "player_hp", "FightPlayerStamina": "player_stamina",
        "FightOpponentHealth": "opponent_hp", "FightOpponentStamina": "opponent_stamina",
    }
    for meter_name in meters:
        var meter := main_view.find_child(meter_name, true, false) as ProgressBar
        var value := float(snapshot[meters[meter_name]])
        _check(meter != null and is_equal_approx(meter.value, value), meter_name + " matches live state")
    var round_label := main_view.find_child("FightRoundLabel", true, false) as Label
    _check(round_label != null and round_label.text == "ROUND %d / %d" % [
        int(snapshot["round"]), int(main_view.combat.balance.fight.rounds),
    ], "the arena label tracks the live round")
    var finished := bool(snapshot["finished"])
    var limit := int(main_view.combat.balance.fight.exchanges_per_round)
    var active_step := maxi(0, int(snapshot["exchange"]) - (1 if finished else 0)) % limit + 1
    for index in range(1, limit + 1):
        var marker := main_view.find_child("FightExchangeStep%d" % index, true, false) as ColorRect
        _check(marker != null, "exchange track contains step %d" % index)
        if marker != null:
            _check((marker.color == Color("#ffe2a0")) == (index == active_step), "exchange track highlights the current step")
    var forecast := main_view.find_child("FightPrediction", true, false) as Label
    if finished:
        _check(forecast == null, "the final exchange shows the result only")
        return
    var trust := main_view.find_child("FightReadConfidence", true, false) as Label
    _check(trust != null and trust.text == "%d%%" % int(snapshot["pending_telegraph"].get("confidence", 0)), "read confidence matches the engine")
    _check(forecast != null and forecast.text.contains("가능성"), "the next opponent action is shown as a prediction")
    if int(snapshot["exchange"]) > 0:
        var feedback := main_view.find_child("FightEventLabel", true, false) as Label
        _check(feedback != null and not feedback.text.is_empty(), "the last exchange and next prediction coexist")
    var scroll := _find_scroll(main_view)
    if scroll != null:
        for button in main_view.find_children("FightAction_*", "Button", true, false):
            _check(scroll.get_global_rect().encloses(button.get_global_rect()), "action stays reachable after the exchange")

func _find_scroll(root: Node) -> ScrollContainer:
    for node in root.find_children("*", "ScrollContainer", true, false):
        if node is ScrollContainer:
            return node as ScrollContainer
    return null

func _find_stage(root: Node) -> FightStage:
    if root is FightStage:
        return root as FightStage
    for child in root.get_children():
        var found := _find_stage(child)
        if is_instance_valid(found):
            return found
    return null

func _direct_button_count(root: Node) -> int:
    var count := 0
    if not is_instance_valid(root):
        return count
    for child in root.get_children():
        if child is Button:
            count += 1
    return count

func _collect_text(root: Node) -> Array[String]:
    var out: Array[String] = []
    if root is Label:
        out.append((root as Label).text)
    elif root is Button:
        out.append((root as Button).text)
    for child in root.get_children():
        out.append_array(_collect_text(child))
    return out

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Array else []

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
        await process_frame
        main_view = null
    await create_timer(0.15).timeout
    _cleanup_save_files()
    if failures.is_empty():
        print("fight-fixed-hud-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
