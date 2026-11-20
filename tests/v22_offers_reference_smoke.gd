extends SceneTree

var failures: Array[String] = []
var state_node: Node
var game: Control

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: tests require an isolated user-data directory")
        quit(2)
        return
    state_node = root.get_node("GameState")
    state_node.new_career("경기 제안 QA", "technician")
    state_node.state["first_launch_acknowledged"] = true
    await _enter_game()
    if not _press("TrainingSelect_roadwork"):
        _finish()
        return
    await _settle()
    _require(game.find_child("TrainingResult", true, false) != null, "training result survives offer entry")

    var offers: Array = state_node.get_fight_offers(game.opponents)
    _require(offers.size() == 3, "first camp offers three opponents")
    for opponent: Dictionary in offers:
        await _check_offer(opponent, offers)
    await _check_title_offer()
    game.queue_free()
    await process_frame
    _finish()

func _check_offer(opponent: Dictionary, offers: Array) -> void:
    var id := str(opponent["id"])
    var card := game.find_child("OpponentCard_" + id, true, false)
    _require(card != null, "current opponent is shown: " + id)
    if card == null:
        return

    var rank := card.find_child("FightOfferRank_" + id, true, false) as Label
    _require(rank != null and rank.text == "랭킹 #%d" % int(opponent["rank"]), id + " rank from roster")
    var portrait := card.find_child("FightOfferPortrait_" + id, true, false) as TextureRect
    _require(portrait != null and portrait.texture != null, id + " actual opponent portrait")
    var rewards := card.find_child("FightOfferRewards_" + id, true, false)
    if rewards != null:
        var labels := _labels(rewards)
        _require((game._v17_money(int(opponent["purse"])) + "원") in labels, id + " purse from roster")
        _require(("%+d" % int(opponent["reputation_reward"])) in labels, id + " reputation from roster")
        _require(("%+d / %d" % [int(opponent["career_points_win"]), -absi(int(opponent["career_points_loss"]))]) in labels, id + " career points from roster")
    else:
        _require(false, id + " reward summary")

    var before: Dictionary = state_node.state.duplicate(true)
    var saved_before := SaveService.load_game()
    if not _press("FightOfferAnalyze_" + id):
        return
    await _settle()
    var analysis := card.find_child("FightOfferAnalysis_" + id, true, false) as Control
    _require(analysis != null and analysis.is_visible_in_tree(), id + " analysis opens")
    if analysis != null:
        var labels := _labels(analysis)
        _require(("강점 · " + str(opponent["scouting"]["strength"])) in labels, id + " accurate strengths")
        _require(("약점 · " + str(opponent["scouting"]["weakness"])) in labels, id + " accurate weaknesses")
    _require(state_node.state == before, id + " analysis preserves career")
    _require(SaveService.load_game() == saved_before, id + " analysis does not change save")
    _press("FightOfferAnalyze_" + id)
    _require(analysis == null or not analysis.is_visible_in_tree(), id + " analysis toggles closed")

    var other_id := str(offers[1 if opponent == offers[0] else 0]["id"])
    _press("FightOfferSelect_" + id)
    _press("FightOfferSelect_" + other_id)
    await _settle()
    _require(str(state_node.state["phase"]) == "tactical_prep", id + " advances to tactical prep")
    _require(str(state_node.state["selected_opponent"]) == id, id + " guards duplicate acceptance")
    _require(game.find_child("V19TacticalMatchup", true, false) != null, id + " tactical screen renders")
    var saved := SaveService.load_game()
    _require(str(saved.get("phase", "")) == "tactical_prep", id + " saved phase")
    _require(str(saved.get("selected_opponent", "")) == id, id + " saved opponent")

    if opponent == offers.back():
        game.queue_free()
        await process_frame
        state_node.state = saved
        await _enter_game()
        _require(game.find_child("V19TacticalMatchup", true, false) != null, id + " tactical screen restored from save")
        _require(str(game.current_opponent.get("id", "")) == id, id + " chosen opponent restored")

    var returned := false
    for button in game.find_children("*", "Button", true, false):
        if button.text == "← 상대 다시 선택":
            button.pressed.emit()
            returned = true
            break
    await _settle()
    _require(returned and str(state_node.state["phase"]) == "fight_offer", id + " can return to offers")
    _require(game.find_child("ReferenceFightOffers", true, false) != null, id + " contract board restored")
    _require(game.find_child("TrainingResult", true, false) != null, id + " training result still available")
    _require(int(state_node.state["career"]["money"]) == int(before["career"]["money"]), id + " no second training charge")

func _check_title_offer() -> void:
    state_node.state["career"]["fights"] = 2
    state_node.state["career"]["wins"] = 2
    var options: Array = state_node.get_fight_offers(game.opponents)
    _require(not options.is_empty(), "eligible stage has offers")
    if options.is_empty():
        return
    var first: Dictionary = options.front()
    _require(bool(first.get("title_fight", false)), "fixture qualifies for a title offer")
    (game.v17_nav_buttons["match"] as Button).pressed.emit()
    await _settle()
    var card := game.find_child("OpponentCard_" + str(first["id"]), true, false)
    _require(card != null and str(first["title_label"]) in _labels(card), "title offer label visible")
    var board := game.find_child("ReferenceFightOffers", true, false)
    _require(board != null, "offer board can refresh in place")
    if board == null:
        return
    var cards := board.find_children("OpponentCard_*", "PanelContainer", false, false)
    _require(not cards.is_empty() and cards[0] == card, "eligible title offer listed first")
    if _press("FightOfferSelect_" + str(first["id"])):
        await _settle()
        _require(state_node.state["selected_opponent"] == first["id"], "eligible title can be selected")

func _enter_game() -> void:
    var scene := load("res://scenes/Main.tscn") as PackedScene
    game = scene.instantiate()
    root.add_child(game)
    await _settle()

func _press(node_name: String) -> bool:
    var button := game.find_child(node_name, true, false) as Button
    _require(button != null, node_name + " is present")
    if button == null:
        return false
    button.pressed.emit()
    return true

func _settle() -> void:
    await process_frame
    await process_frame

func _labels(node: Node) -> Array[String]:
    var result: Array[String] = []
    for label in node.find_children("*", "Label", true, false):
        result.append(label.text)
    return result

func _require(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
        push_error(reason)

func _finish() -> void:
    if failures.is_empty():
        print("PASS: current offers, contract details, preview, selection, back, title offer and resume")
        quit(0)
    else:
        printerr("FAIL: ", failures)
        quit(1)
