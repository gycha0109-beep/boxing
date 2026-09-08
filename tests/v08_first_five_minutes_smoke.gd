extends SceneTree

const Save = preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_save_files()
    await process_frame

    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState autoload was not available")
    if not is_instance_valid(game_state):
        _finish()
        return

    var opponents: Array = _load_array("res://data/opponents.json")
    var camps: Array = _load_array("res://data/camp_actions.json")
    _check(not opponents.is_empty(), "v0.8 fixture has no opponents")
    _check(not camps.is_empty(), "v0.8 fixture has no camp actions")
    if opponents.is_empty() or camps.is_empty():
        _finish()
        return

    game_state.new_career("Launch Boxer", "technician")
    game_state.state.erase("first_launch_acknowledged")
    game_state.state.erase("weigh_in_acknowledged")
    Save.save_game(game_state.state)

    var packed: PackedScene = load("res://scenes/Main.tscn")
    _check(is_instance_valid(packed), "Main scene could not load for v0.8")
    if not is_instance_valid(packed):
        _finish()
        return

    main_view = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    _check(str(main_view.get_script().resource_path) == "res://scripts/main_v15.gd", "Main scene is not using the active audio/economy shell that preserves the v1.0/v0.8 flow")
    var music_node: Node = main_view.get_node_or_null("MusicDirector")
    _check(is_instance_valid(music_node), "launch flow did not create music director")
    if is_instance_valid(music_node):
        _check(str(music_node.get("current_mode")) == "menu", "launch title did not use menu BGM")

    var title_text := "\n".join(_collect_text(main_view))
    _check(title_text.contains("ONE FIGHTER. ONE CAREER."), "fresh career did not show launch title gate")
    _check(title_text.contains("프로 커리어 시작"), "launch title missing start CTA")
    _check(_find_stage(main_view) == null, "launch title unexpectedly rendered a fight stage")

    main_view._start_new_career_from_title()
    await process_frame
    _check(bool(game_state.state.get("first_launch_acknowledged", false)), "title acknowledgement was not persisted")
    _check(str(game_state.state.phase) == "style_select", "title CTA did not enter boxer style selection")
    var natural_talent_id := str(game_state.state.boxer.get("trait_id", ""))
    var natural_talent: Dictionary = game_state.talent_definition()
    _check(not natural_talent_id.is_empty(), "new boxer did not receive an innate talent")
    _check(not natural_talent.is_empty(), "new boxer innate talent has no definition")

    var style_text := "\n".join(_collect_text(main_view))
    _check(style_text.contains("BOXER CREATION · BOXING STYLE"), "style selection missing creation framing")
    _check(style_text.contains("어떤 복서로 시작하시겠습니까?"), "style selection missing player-choice prompt")
    _check(style_text.contains("능력치가 하는 일"), "style selection missing stat explanation")
    _check(style_text.contains("아웃복서"), "style selection missing out-boxer option")

    main_view._choose_boxing_style("out_boxer")
    await process_frame
    _check(str(game_state.state.phase) == "talent_reveal", "style choice did not enter natural-talent reveal")
    _check(str(game_state.state.boxer.get("identity_id", "")) == "out_boxer", "chosen boxing style was not persisted")
    _check(str(game_state.state.boxer.get("trait_id", "")) == natural_talent_id, "style choice changed the innate talent")
    var talent_text := "\n".join(_collect_text(main_view))
    _check(talent_text.contains("NATURAL TALENT"), "talent reveal missing creation framing")
    _check(talent_text.contains("타고난 재능 · %s" % str(natural_talent.get("name", ""))), "talent reveal does not identify the innate talent")
    for stat in ["power", "speed", "technique", "defense", "conditioning"]:
        var bonus := int(natural_talent.get("stat_bonus", {}).get(stat, 0))
        if bonus == 0:
            continue
        var bonus_text := "%s %s%d" % [_stat_label_upper(stat), "+" if bonus > 0 else "", bonus]
        _check(talent_text.contains(bonus_text), "talent reveal hides direct stat bonus: %s" % bonus_text)
    for hidden_value in ["0.025", "1.28", "1.12", "0.72", "0.94", "0.78", "1.18", "1.2", "0.82"]:
        _check(not talent_text.contains(hidden_value), "talent reveal exposes internal tuning coefficient: %s" % hidden_value)

    main_view._confirm_talent()
    await process_frame
    _check(str(game_state.state.phase) == "camp", "talent confirmation did not enter camp")
    if is_instance_valid(music_node):
        _check(str(music_node.get("current_mode")) == "career", "camp did not switch to career BGM")
    var camp_text := "\n".join(_collect_text(main_view))
    _check(camp_text.contains("PRO DEBUT · CAMP 01"), "first camp missing debut framing")
    _check(camp_text.contains("CAREER LADDER"), "first camp missing career ladder framing")
    _check(camp_text.contains("장비 · 체육관 투자"), "first camp missing optional equipment investment entry")

    main_view._choose_camp_action(camps[0])
    await process_frame
    _check(str(game_state.state.phase) == "fight_offer", "camp choice did not enter fight offers")
    if is_instance_valid(music_node):
        _check(str(music_node.get("current_mode")) == "fight_week", "fight offer did not switch to fight-week BGM")
    var offer_text := "\n".join(_collect_text(main_view))
    _check(offer_text.contains("FIGHT WEEK · CONTRACT BOARD"), "fight offers missing fight-week framing")
    _check(offer_text.contains("CAREER LADDER"), "fight offers missing visible career ladder")

    var opponent: Dictionary = opponents[0]
    main_view._choose_opponent(opponent)
    await process_frame
    _check(str(game_state.state.phase) == "tactical_prep", "opponent choice did not enter tactical preparation")
    var tactical_text := "\n".join(_collect_text(main_view))
    _check(tactical_text.contains("FIGHT CAMP · TACTICAL PREP"), "tactical preparation missing fight-camp framing")
    _check(tactical_text.contains(str(opponent.name)), "tactical preparation missing opponent")
    _check(tactical_text.contains("영구 스탯은 더 오르지 않습니다"), "tactical preparation does not explain the one-growth rule")

    main_view._choose_tactical_preparation("distance_drill")
    await process_frame
    _check(str(game_state.state.phase) == "condition_prep", "tactical choice did not enter final condition")
    var condition_text := "\n".join(_collect_text(main_view))
    _check(condition_text.contains("FIGHT CAMP · FINAL CONDITION"), "condition preparation missing fight-camp framing")
    _check(condition_text.contains("추가 성장은 없습니다"), "condition preparation does not explain the no-growth rule")

    main_view._choose_condition_preparation("sharpness")
    await process_frame
    _check(str(game_state.state.phase) == "game_plan", "condition choice did not enter game plan")
    var plan_text := "\n".join(_collect_text(main_view))
    _check(plan_text.contains("FIGHT WEEK · SCOUTING DOSSIER"), "game plan missing scouting dossier framing")
    _check(plan_text.contains(str(opponent.name)), "scouting dossier missing opponent")
    _check(plan_text.contains("이번 준비"), "game plan missing preparation summary")

    main_view._choose_game_plan("balanced")
    await process_frame
    await process_frame
    _check(str(game_state.state.phase) == "fight", "game plan no longer prepares fight state")
    _check(not bool(game_state.state.get("weigh_in_acknowledged", true)), "weigh-in gate was not persisted")
    var weigh_text := "\n".join(_collect_text(main_view))
    _check(weigh_text.contains("FIGHT WEEK · OFFICIAL WEIGH-IN"), "weigh-in interstitial did not render")
    _check(weigh_text.contains("FIGHT NIGHT 입장"), "weigh-in screen missing fight-night CTA")
    _check(_find_stage(main_view) == null, "fight stage rendered before weigh-in acknowledgement")

    main_view._acknowledge_weigh_in()
    await process_frame
    await process_frame
    _check(bool(game_state.state.get("weigh_in_acknowledged", false)), "weigh-in acknowledgement was not persisted")
    _check(_find_stage(main_view) != null, "fight stage did not render after weigh-in acknowledgement")
    if is_instance_valid(music_node):
        _check(str(music_node.get("current_mode")) == "fight", "fight night did not switch to fight BGM")

    game_state.apply_fight_result("WIN_DEC", opponent, {"player_hp": 72.0, "opponent_hp": 44.0})
    main_view._render_phase()
    await process_frame
    if is_instance_valid(music_node):
        _check(str(music_node.get("current_mode")) == "career", "result did not return to career BGM")
    var result_text := "\n".join(_collect_text(main_view))
    _check(result_text.contains("FIGHT NIGHT · OFFICIAL RESULT"), "result screen missing official-result framing")
    _check(result_text.contains("판정승"), "result screen missing localized result")
    _check(result_text.contains("CAREER UPDATE"), "result screen missing career progression card")
    _check(result_text.contains("커리어 계속"), "result screen missing continuation CTA")

    _finish()

func _stat_label_upper(stat: String) -> String:
    match stat:
        "power": return "파워"
        "speed": return "스피드"
        "technique": return "테크닉"
        "defense": return "수비"
        "conditioning": return "컨디셔닝"
        _: return stat

func _find_stage(node: Node) -> FightStage:
    for child in node.get_children():
        if child is FightStage:
            return child as FightStage
        var nested := _find_stage(child)
        if nested != null:
            return nested
    return null

func _collect_text(root: Node) -> Array[String]:
    var output: Array[String] = []
    if root is Label:
        output.append(str(root.text))
    elif root is Button:
        output.append(str(root.text))
    for child in root.get_children():
        output.append_array(_collect_text(child))
    return output

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, Save.PREVIOUS_SAVE_PATH, Save.PREVIOUS_BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("v08-first-five-minutes-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)