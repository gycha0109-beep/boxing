extends SceneTree

const Save := preload("res://scripts/core/save_service.gd")
const Creation := preload("res://scripts/ui/reference_creation_view.gd")

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    game_state = root.get_node("GameState")
    game_state.new_career("Launch Boxer", "technician")
    game_state.state.erase("first_launch_acknowledged")
    game_state.state.erase("weigh_in_acknowledged")
    Save.save_game(game_state.state)

    var scene := load("res://scenes/Main.tscn") as PackedScene
    main_view = scene.instantiate()
    root.add_child(main_view)
    await _settle()
    _check(main_view.find_child("ReferenceTitle", true, false) != null, "fresh career renders the title")
    _check(_music_mode() == "menu", "title uses menu music")
    _check(main_view.find_child("FightStage", true, false) == null, "no ring before fight entry")
    await _press("TitleNewCareer")
    _saved_phase("style_select")
    _check(bool(Save.load_game().get("first_launch_acknowledged", false)), "title acknowledgement persists")
    _check(main_view.find_children("BoxerStyle_*", "Button", true, false).size() == game_state.boxing_styles().size(), "all defined styles are selectable")
    _check(main_view.find_child("BoxerStyleIntro", true, false) != null, "style selection explains what the player is choosing")
    var style_instructions := main_view.find_child("BoxerStyleInstructions", true, false) as Label
    _check(style_instructions != null and style_instructions.text.contains("2/2단계") and style_instructions.text.contains("다음 카드"), "style selection explains selection and the next card")
    _check(main_view.find_child("BoxerStatGuide", true, false) != null, "style selection explains the stat guide")
    for style: Dictionary in game_state.boxing_styles():
        var style_id := str(style.get("id", ""))
        var description := main_view.find_child("BoxerStyleDescription_" + style_id, true, false) as Label
        _check(description != null and description.text == str(style.get("description", "")), "style card explains " + style_id)
    var balanced_guide := main_view.find_child("BoxerStyleWalkthrough_balanced", true, false) as HBoxContainer
    _check(balanced_guide != null and balanced_guide.visible, "style walkthrough starts by highlighting balanced")
    await _press("BoxerStyleNext_balanced")
    var pressure_guide := main_view.find_child("BoxerStyleWalkthrough_pressure_fighter", true, false) as HBoxContainer
    _check(pressure_guide != null and pressure_guide.visible, "style walkthrough advances to pressure fighter")
    await _press("BoxerStyleNext_pressure_fighter")
    var outside_guide := main_view.find_child("BoxerStyleWalkthrough_out_boxer", true, false) as HBoxContainer
    _check(outside_guide != null and outside_guide.visible, "style walkthrough advances to out boxer")
    for stat: String in Creation.STATS:
        var help := main_view.find_child("BoxerStatHelp_" + stat, true, false) as Label
        _check(help != null and help.text == game_state.stat_help(stat), "style selection explains " + stat)
    var conditioning_help := main_view.find_child("BoxerStatHelp_conditioning", true, false) as Label
    var conditioning_label := conditioning_help.get_parent().get_child(0) as Label if conditioning_help != null else null
    _check(conditioning_label != null and conditioning_label.text == "체력(지구력)", "stat guide distinguishes stamina from health")

    var trait_id := str(game_state.state.boxer.trait_id)
    var talent: Dictionary = game_state.talent_definition()
    _check(not trait_id.is_empty() and not talent.is_empty(), "new boxer receives one defined talent")
    await _press("BoxerStyle_out_boxer")
    _saved_phase("talent_reveal")
    var boxer: Dictionary = Save.load_game().boxer
    _check(boxer.identity_id == "out_boxer" and boxer.trait_id == trait_id, "chosen style and original talent persist")
    var talent_name := main_view.find_child("BoxerTalentName", true, false) as Label
    _check(talent_name != null and talent_name.text == talent.get("name"), "reveal shows the correct talent")
    var talent_text := _text(main_view)
    for stat: String in Creation.STATS:
        var bonus := int(talent.get("stat_bonus", {}).get(stat, 0))
        if bonus != 0:
            _check(talent_text.contains("%s %+d" % [Creation.STATS[stat], bonus]), "reveal shows the actual talent bonus")
        var value := main_view.find_child("BoxerStat_" + stat, true, false) as Label
        _check(value != null and int(value.text) == int(boxer[stat]), "reveal shows the actual starting " + stat)
    for hidden_value in ["0.025", "1.28", "1.12", "0.72", "0.94", "0.78", "1.18", "1.2", "0.82"]:
        _check(not talent_text.contains(hidden_value), "reveal hides internal tuning coefficient " + hidden_value)

    var first_style_boxer: Dictionary = boxer.duplicate(true)
    var styles_by_id: Dictionary = {}
    for style: Dictionary in game_state.boxing_styles():
        styles_by_id[str(style.get("id", ""))] = style
    _check(main_view.find_child("BoxerReselectStyle", true, false) is Button, "talent reveal lets the player reselect the boxing style")
    await _press("BoxerReselectStyle")
    _saved_phase("style_select")
    _check(str(Save.load_game().boxer.trait_id) == trait_id, "returning to style selection preserves the revealed talent")
    await _press("BoxerStyle_pressure_fighter")
    _saved_phase("talent_reveal")
    var reselection_boxer: Dictionary = Save.load_game().boxer
    _check(reselection_boxer.identity_id == "pressure_fighter", "reselected boxing style persists")
    _check(reselection_boxer.trait_id == trait_id, "reselecting the style preserves the same talent")
    var pressure_bonus: Dictionary = styles_by_id.get("pressure_fighter", {}).get("stat_bonus", {})
    var out_bonus: Dictionary = styles_by_id.get("out_boxer", {}).get("stat_bonus", {})
    for stat: String in Creation.STATS:
        var expected := clampi(int(first_style_boxer.get(stat, 50)) - int(out_bonus.get(stat, 0)) + int(pressure_bonus.get(stat, 0)), 1, 100)
        _check(int(reselection_boxer.get(stat, 0)) == expected, "reselection replaces rather than stacks the " + stat + " style bonus")

    await _press("BoxerBeginCareer")
    _saved_phase("camp")
    _check(_music_mode() == "career", "camp uses career music")
    var guide_enabled: bool = main_view._first_bout_guide_enabled()
    _guide_visibility("FirstBoutTrainingGuide", guide_enabled)
    _guide_visibility("FirstBoutGuideSkip", guide_enabled)
    _check(_text(main_view).contains("장비 · 체육관 투자"), "camp offers optional equipment investment")
    var training := main_view.find_child("TrainingPrimaryGrid", true, false)
    _check(training != null and training.find_children("TrainingSelect_*", "Button", true, false).size() >= 4, "camp shows at least four primary training options")
    main_view.v17_nav_buttons["profile"].pressed.emit()
    await _settle()
    var profile := main_view.find_child("ReferenceProfile", true, false)
    if profile != null:
        var meters := profile.find_children("*", "ProgressBar", true, false)
        _check(meters.size() == Creation.STATS.size(), "profile shows all five stat meters")
    else:
        _check(false, "profile opens from camp")
    main_view.v17_nav_buttons["training"].pressed.emit()
    await _settle()
    await _press("TrainingSelect_mitts")
    _saved_phase("fight_offer")
    var camp := Save.load_game()
    _check(int(camp.boxer.technique) > int(reselection_boxer.technique) and int(camp.boxer.fatigue) > int(reselection_boxer.fatigue), "training saves the actual stat gain and fatigue")
    _check(_music_mode() == "fight_week", "offers use fight-week music")
    var offers: Array = game_state.get_fight_offers(main_view.opponents)
    if offers.is_empty():
        _check(false, "career receives an opponent offer")
        await _finish()
        return
    _check(main_view.find_children("FightOfferSelect_*", "Button", true, false).size() == offers.size(), "all current offers appear")
    if guide_enabled:
        var safe_offer_count := 0
        for offer: Dictionary in offers:
            if offer.get("difficulty") == "safe":
                safe_offer_count += 1
        _guide_visibility("FirstBoutOpponentRecommendation", safe_offer_count > 0)
    var opponent: Dictionary = offers[0]
    _check(_text(main_view).contains(str(opponent.name)), "offers show the actual roster name")
    await _press("FightOfferSelect_" + str(opponent.id))
    _saved_phase("tactical_prep")
    _check(Save.load_game().selected_opponent == opponent.id, "selected opponent persists")
    _check(_text(main_view).contains(str(opponent.name)), "tactical preparation shows the selected opponent")
    await _press("PreparationSelect_distance_drill")
    await _press("PreparationConfirm")
    _saved_phase("condition_prep")
    _check(Save.load_game().selected_tactical_prep == "distance_drill", "confirmed tactical preparation persists")
    await _press("PreparationSelect_sharpness")
    await _press("PreparationConfirm")
    _saved_phase("game_plan")
    _check(Save.load_game().selected_condition_prep == "sharpness", "confirmed condition preparation persists")
    var reading := main_view.find_child("ScoutingTendency_body", true, false) as Label
    _check(reading != null and reading.text == "%d%%" % roundi(float(opponent.tendencies.body) * 100.0), "scouting uses selected opponent data")
    await _press("ScoutingShowPlans")
    _check(main_view.find_children("GamePlanSelect_*", "Button", true, false).size() == game_state.game_plans.size(), "all defined game plans appear")
    await _press("GamePlanSelect_balanced")
    _saved_phase("fight")
    var weighed := Save.load_game()
    _check(weighed.selected_game_plan == "balanced" and not weighed.last_weigh_in.is_empty(), "plan and weigh-in verdict persist")
    _check(not weighed.weigh_in_acknowledged and main_view.find_child("FightStage", true, false) == null, "weigh-in gates fight entry")
    await _press("WeighInEnterFight")
    _check(Save.load_game().weigh_in_acknowledged and main_view.find_child("FightStage", true, false) != null, "confirmation enters the ring")
    _check(_music_mode() == "fight", "fight uses fight music")
    _guide_visibility("FirstBoutFightGuide", guide_enabled)

    # The fixed-HUD smoke plays the full bout. This fixture focuses on
    # first-launch transitions and the separately rendered result.
    game_state.apply_fight_result("WIN_DEC", opponent, {"player_hp": 72.0, "opponent_hp": 44.0})
    main_view._render_phase()
    await _settle()
    _saved_phase("result")
    _guide_visibility("FirstBoutResultGuide", guide_enabled)
    var verdict := main_view.find_child("FightResultVerdict", true, false) as Label
    _check(verdict != null and verdict.text == "판정승", "result shows the localized verdict")
    _check(main_view.find_child("FightResultContinue", true, false) is Button, "result offers continuation")
    _check(_music_mode() == "career", "result returns to career music")
    await _finish()

func _press(id: String) -> void:
    var button := main_view.find_child(id, true, false) as Button
    var available := button != null and button.is_visible_in_tree() and not button.disabled
    _check(available, "current screen offers " + id)
    if available:
        button.pressed.emit()
    await _settle()

func _saved_phase(expected: String) -> void:
    _check(game_state.state.phase == expected and Save.load_game().get("phase") == expected, "runtime and saved phase are " + expected)

func _guide_visibility(id: String, expected: bool) -> void:
    _check((main_view.find_child(id, true, false) != null) == expected, "guide visibility: " + id)

func _music_mode() -> String:
    var music := main_view.get_node_or_null("MusicDirector") as MusicDirector
    return music.current_mode if music != null else ""

func _text(node: Node) -> String:
    var labels: Array[String] = []
    for label in node.find_children("*", "Label", true, false):
        labels.append(label.text)
    for button in node.find_children("*", "Button", true, false):
        labels.append(button.text)
    return "\n".join(labels)

func _settle() -> void:
    await process_frame
    await process_frame

func _finish() -> void:
    main_view.queue_free()
    await _settle()
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    if failures.is_empty():
        print("first-five-minutes-smoke: PASS")
    for failure in failures:
        push_error(failure)
    quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
