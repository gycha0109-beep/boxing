extends SceneTree

var failures: Array[String] = []
var state: Node
var ui: Control
var opponent: Dictionary

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: use an isolated user-data directory")
        quit(2)
        return
    state = root.get_node("GameState")
    var opponents: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    opponent = opponents[0]
    await _verify_result("WIN_DEC", "판정승", [[10, 9], [9, 10], [10, 9]], 3, false)
    await _verify_result("LOSS_KO", "KO패", [[9, 10]], 2, true)
    await _verify_legacy_draw()
    await create_timer(0.30).timeout
    if failures.is_empty():
        print("PASS: report values and old saves, result reload, one settlement, event and next camp")
        quit(0)
    else:
        printerr("FAIL: ", failures)
        quit(1)

func _start_fixture() -> void:
    state.new_career("경기 결과 QA", "technician")
    state.state["first_launch_acknowledged"] = true
    state.state["boxer"]["weight_kg"] = 60.9
    state.state["boxer"]["health"] = 84
    state.state["boxer"]["fatigue"] = 18
    state.state.phase = "fight_offer"
    state.select_opponent(opponent)
    state.select_game_plan("outside_boxing")

func _verify_result(id: String, verdict: String, cards: Array, round_number: int, expect_event: bool) -> void:
    _start_fixture()
    var initial_career: Dictionary = state.state["career"].duplicate(true)
    var initial_boxer: Dictionary = state.state["boxer"].duplicate(true)
    state.apply_fight_result(id, opponent, {"cards": cards, "round": round_number, "player_hp": 71.0, "opponent_hp": 63.0})
    var settled := SaveService.load_game()
    var report: Dictionary = settled.get("last_fight_summary", {})
    var before: Dictionary = report.get("previous", {})
    var saved_cards: Array = report.get("round_cards", [])
    _require(saved_cards.size() == cards.size(), "actual round cards are stored")
    for index in range(mini(saved_cards.size(), cards.size())):
        _require(int(saved_cards[index][0]) == int(cards[index][0]) and int(saved_cards[index][1]) == int(cards[index][1]), "round score is unchanged by save")
    _require(int(report.get("ending_round", 0)) == round_number, "actual ending round is stored")
    _require(int(before.get("rank", -1)) == int(initial_career["rank"]), "rank before settlement is stored")
    _require(int(before.get("career_points", -1)) == int(initial_career["career_points"]), "points before settlement are stored")
    _require(int(before.get("health", -1)) == int(initial_boxer["health"]), "health baseline is stored")
    _require(int(before.get("fatigue", -1)) == int(initial_boxer["fatigue"]), "fatigue baseline is stored")
    var original_money := int(initial_career["money"])
    var delta := int(report.get("purse", 0)) - int(report.get("cycle_cost", 0))
    _require(int(settled["career"]["money"]) == original_money + delta, "purse minus fees reaches the real wallet")

    state.state = settled
    await _open_game()
    var view := ui.find_child("ReferenceFightResult", true, false)
    _require(view != null, "result renders after reopening")
    if view != null:
        var labels := _texts(view)
        _require(verdict in labels, "result uses the actual verdict")
        _require(("ROUND %d 종료" % round_number) in labels, "correct ending round")
        _require("라운드 점수" in labels and _has_text(labels, "R1 %d:%d" % [int(cards[0][0]), int(cards[0][1])]), "recorded round scores are visible")
        _require("거리전" in labels, "the confirmed game plan is visible")
        _require(_has_text(labels, "#%d  →  #%d" % [int(initial_career["rank"]), int(settled["career"]["rank"])]), "actual rank movement is visible")
        var display_delta: String = ("+" if delta > 0 else "") + ui._v17_money(delta)
        _require(_has_text(labels, "잔액 변동 %s원" % display_delta), "actual money change is visible")
        var health := int(settled["boxer"]["health"])
        _require(("%d%% → %d%% (%+d)" % [int(initial_boxer["health"]), health, health - int(initial_boxer["health"])]) in labels, "condition reflects the actual change")
    _require(int(state.state["career"]["fights"]) == 1, "rendering the saved result does not settle again")

    state.career_balance.events.post_fight_chance = 1.0 if expect_event else 0.0
    var next := ui.find_child("FightResultContinue", true, false) as Button
    _require(next != null, "result can continue")
    if next != null:
        next.pressed.emit()
        next.pressed.emit()
        await _settle()
        _require(str(state.state["phase"]) == ("event" if expect_event else "camp"), "result continues to the correct phase")
        if expect_event and state.state["phase"] == "event":
            for action in ui.find_children("*", "Button", true, false):
                if action.text == "계속":
                    action.pressed.emit()
                    break
            await _settle()
        _require(state.state["phase"] == "camp" and ui.find_child("ReferenceTraining", true, false) != null, "next camp loads")
        var saved := SaveService.load_game()
        _require(int(saved["career"]["fights"]) == 1 and str(saved["last_result"]) == id, "next camp keeps the result")
        if not expect_event:
            _require(int(saved["career"]["money"]) == original_money + delta, "no second charge or payout")
    await _close_game()

func _verify_legacy_draw() -> void:
    _start_fixture()
    state.apply_fight_result("DRAW", opponent)
    for key in ["previous", "round_cards", "ending_round"]:
        state.state["last_fight_summary"].erase(key)
    SaveService.save_game(state.state)
    state.state = SaveService.load_game()
    await _open_game()
    var labels := _texts(ui)
    _require("무승부" in labels, "old result save still renders")
    _require("라운드 점수" not in labels and not _has_text(labels, "ROUND 0"), "legacy data does not fabricate a round score")
    await _close_game()

func _open_game() -> void:
    var scene := load("res://scenes/Main.tscn") as PackedScene
    ui = scene.instantiate()
    root.add_child(ui)
    await _settle()

func _close_game() -> void:
    ui.queue_free()
    await process_frame

func _settle() -> void:
    await process_frame
    await process_frame

func _texts(node: Node) -> Array[String]:
    var labels: Array[String] = []
    for label in node.find_children("*", "Label", true, false):
        labels.append(label.text)
    return labels

func _has_text(labels: Array[String], value: String) -> bool:
    for label in labels:
        if label.contains(value):
            return true
    return false

func _require(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
        push_error(reason)
