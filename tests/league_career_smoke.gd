extends SceneTree

var game: Node
var view: Control
var roster: Array
var errors: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        errors.append(message)
        push_error(message)

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        quit(2)
        return
    game = root.get_node("GameState")
    roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    var debuts := []
    for id: String in game.League.BACKGROUNDS:
        game.new_career("QA", "workhorse")
        game.begin_boxer_creation()
        check(game.select_background(id, id), "background selection")
        check(game.select_boxing_style("balanced").ok and game.confirm_talent().ok, "creation")
        debuts.append(game.get_fight_offers(roster)[0].id)
        check(game.state.career.money == 120000 + game.League.BACKGROUNDS[id].money, "starting purse")
        check(game.state.career.reputation == game.League.BACKGROUNDS[id].fans, "starting reputation")
        for stat: String in game.League.STATS:
            check(game.state.boxer[stat] == 44 + int(game.talent_definition().stat_bonus.get(stat, 0)) + int(game.League.BACKGROUNDS[id].stats.get(stat, 0)), "starting " + stat)
    check(debuts[0] != debuts[1] and debuts[1] != debuts[2] and debuts[0] != debuts[2], "three distinct debut recommendations")
    var original: Dictionary = game.get_fight_boxer()
    var purse: int = game.quoted_purse(roster[0])
    game.state.career.reputation += 50
    check(game.get_fight_boxer() == original and game.quoted_purse(roster[0]) > purse, "fans affect offers without changing the fighter")
    game.state.first_launch_acknowledged = true
    game.rng.seed = 1206
    view = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(view)
    await process_frame
    for bout in range(1, 14):
        game.state.boxer.fatigue = 20
        check(game.management_visit() and not game.management_visit(), "one activity per bout")
        var offers: Array = game.get_fight_offers(roster)
        var opponent: Dictionary = offers[0]
        game.select_opponent(opponent)
        check(game.state.phase == "game_plan", "direct scouting")
        check(game.select_game_plan("balanced").ok, "plan accepted")
        var quote: int = int(game.state.career_state.booked_purse)
        var weigh: float = float(game.state.last_weigh_in.purse_multiplier)
        game.apply_fight_result("WIN_DEC", opponent, {"player_hp":100.0})
        check(game.state.last_fight_summary.gross_purse == roundi(quote * weigh), "booked purse used")
        game.apply_fight_result("WIN_DEC", opponent)
        check(int(game.state.career.fights) == bout, "single settlement")
        if bout == 12:
            var review: Dictionary = SaveService.load_game().career_state.milestone
            check(review.fights == 12 and review.wins == 12 and review.skill_gain > 0 and not review.title_ready, "12th bout review")
        game.advance_after_result()
        if game.state.phase == "event":
            game.resolve_pending_event()
        if bout % 4 == 0:
            check(game.state.phase == "season_review", "four bouts per season")
            game.state = SaveService.load_game()
            view._render_phase()
            await process_frame
            await process_frame
            var button := view.find_child("Contract_challenge", true, false) as Button
            check(button != null and button.is_visible_in_tree(), "renewal renders at bout %d (gate=%s overlay=%s buttons=%s)" % [bout, view.launch_gate_active, view.v17_overlay, view.body.find_children("Contract_*","Button",true,false)])
            if bout == 12:
                var milestone_visible := false
                for label: Label in view.find_children("*", "Label", true, false):
                    if label.text == "12전 커리어 평가":
                        milestone_visible = true
                check(milestone_visible, "12-bout milestone appears automatically with the season review")
            if button != null:
                var rect := button.get_global_rect()
                check(rect.position.x >= -1 and rect.end.x <= view.size.x + 1, "renewal fits viewport")
                button.pressed.emit()
            check(game.state.career_state.contract == "challenge" and not game.sign_contract("steady"), "contract signed once")
        check(game.state.phase == "camp", "career continues")
        await process_frame
    var world: Dictionary = roster.filter(func(o): return o.id == "viktor_kozlov")[0]
    for bout in range(4):
        # Exercise the result branches using a qualified contender fixture.
        game.state.phase = "fight_offer"
        game.state.boxer.health = 95
        game.state.boxer.fatigue = 20
        game.state.boxer.weight_kg = 60.8
        game.select_opponent(world if bout == 0 else game.get_fight_offers(roster)[0])
        game.select_game_plan("balanced")
        var opponent_id: String = game.state.selected_opponent
        var opponent: Dictionary = roster.filter(func(o): return o.id == opponent_id)[0]
        game.apply_fight_result("WIN_KO", opponent)
        game.advance_after_result()
        if game.state.phase == "event":
            game.resolve_pending_event()
        if bout < 3:
            check(game.state.phase == "champion_choice", "champion may retire or defend")
            if bout == 0:
                var before: Dictionary = game.state.duplicate(true)
                check(game.champion_decision(false) and game.state.career.finished, "voluntary retirement")
                game.state = before
            check(game.champion_decision(true), "defense accepted")
            if game.state.phase == "season_review":
                game.sign_contract("steady")
    check(game.state.career.finished and game.state.career_state.defenses == 3, "three defense limit")
    check(str(game.state.career_state.get("pending_world_title_win", {}).get("id", "")) == "viktor_kozlov", "first world-title victory must remain the succession origin after later defenses")
    check(game.state.meta_state.legacy_capacity == 5 and game.state.world_state.title_history.size() == 4, "title history and earned slots")
    var candidates: Array = game.retirement_legacy_candidates()
    check(not candidates.is_empty() and game.select_retirement_legacy(candidates[0].id).ok, "retirement legacy")
    check(game.start_next_generation().ok, "next generation")
    var loaded := SaveService.load_game()
    check(loaded.career.fights == 0 and loaded.career_state.background == "gym" and loaded.meta_state.legacy_slots.size() == 1, "heir start")
    check(loaded.world_state.title_history.size() == 4 and loaded.world_state.champion_boxer_id == "diego_reyes", "world persisted")
    # A bruised boxer on five consecutive losses retires on the sixth loss.
    game.new_career("은퇴 기준", "workhorse")
    game.state.career_state.streak = -5
    game.state.career.fights = 11
    game.state.career.losses = 5
    game.state.boxer.health = 32
    game.state.boxer.weight_kg = 60.8
    game.management_visit()
    game.select_opponent(roster[0])
    game.select_game_plan("balanced")
    game.apply_fight_result("LOSS_DEC", roster[0], {"player_hp":85.0})
    check(game.state.career.ending == "decline_retirement" and game.state.career_state.milestone.fights == 12, "terminal 12th bout still evaluated")
    game.advance_after_result()
    check(game.state.phase == "career_summary", "early retirement reaches legacy")
    view._render_phase()
    await process_frame
    check(view.find_child("LegacyMilestone", true, false) != null, "early retirement displays the 12-bout milestone in legacy selection")
    view.queue_free()
    await process_frame
    view = null
    await create_timer(1.0).timeout
    if errors.is_empty():
        print("PASS: backgrounds, single activity, purse, 13 bouts, season UI, milestone, defenses and succession at ", root.size)
    quit(0 if errors.is_empty() else 1)
