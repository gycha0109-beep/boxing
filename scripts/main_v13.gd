extends "res://scripts/main_v12.gd"

const PREP_ACCENT := Color(0.92, 0.70, 0.34, 1.0)
const PREP_MUTED := Color(0.68, 0.70, 0.75, 1.0)

func _render_phase() -> void:
    var phase := str(GameState.state.get("phase", ""))
    if phase not in ["tactical_prep", "condition_prep"]:
        super._render_phase()
        return

    fighter_profile_root = null
    _clear_body()
    _render_status()
    if phase == "tactical_prep":
        _render_tactical_preparation()
    else:
        _render_condition_preparation()

    if _should_insert_persistent_fighter_profile():
        _render_player_visual_card()
        if is_instance_valid(fighter_profile_root) and fighter_profile_root.get_parent() == body:
            body.move_child(fighter_profile_root, 0)
    _configure_mobile_scroll()

func _render_tactical_preparation() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        super._render_phase()
        return

    _eyebrow("FIGHT CAMP · TACTICAL PREP")
    _section("이번 상대에 맞출 한 가지", "영구 스탯은 더 오르지 않습니다. 이번 경기에서 어떤 흐름을 준비할지만 고릅니다.")

    var scouting: Dictionary = current_opponent.get("scouting", {})
    var opponent_box := _card_box(str(current_opponent.get("name", "OPPONENT")))
    _add_wrapped_label(opponent_box, "%s · 랭킹 #%d" % [str(current_opponent.get("style", "")), int(current_opponent.get("rank", 0))], false)
    _add_wrapped_label(opponent_box, "강점 · %s" % str(scouting.get("strength", "정보 부족")), true)
    _add_wrapped_label(opponent_box, "약점 · %s" % str(scouting.get("weakness", "정보 부족")), true)

    for value in GameState.tactical_preparations():
        var prep: Dictionary = value
        var card := _card_box(str(prep.get("name", "준비")))
        _add_wrapped_label(card, str(prep.get("description", "")), true)
        var choose := Button.new()
        choose.text = "이 흐름을 준비"
        choose.custom_minimum_size = Vector2(0, 60)
        choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choose.mouse_filter = Control.MOUSE_FILTER_PASS
        choose.pressed.connect(Callable(self, "_choose_tactical_preparation").bind(str(prep.get("id", ""))))
        card.add_child(choose)

    var back := Button.new()
    back.text = "← 상대 다시 선택"
    back.custom_minimum_size = Vector2(0, 58)
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.mouse_filter = Control.MOUSE_FILTER_PASS
    back.pressed.connect(Callable(self, "_return_from_tactical_to_offers"))
    body.add_child(back)

func _render_condition_preparation() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        super._render_phase()
        return

    _eyebrow("FIGHT CAMP · FINAL CONDITION")
    _section("마지막 몸 상태 결정", "추가 성장은 없습니다. 쉬어 갈지, 체중을 정리할지, 감각을 살릴지만 결정합니다.")

    var tactical := GameState.preparation_definition("tactical", str(GameState.state.get("selected_tactical_prep", "")))
    if not tactical.is_empty():
        var selected := _card_box("TACTICAL · %s" % str(tactical.get("name", "")))
        _add_wrapped_label(selected, str(tactical.get("description", "")), true)

    for value in GameState.condition_preparations():
        var prep: Dictionary = value
        var card := _card_box(str(prep.get("name", "컨디션")))
        _add_wrapped_label(card, str(prep.get("description", "")), true)
        var choose := Button.new()
        choose.text = "이 상태로 마무리"
        choose.custom_minimum_size = Vector2(0, 60)
        choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choose.mouse_filter = Control.MOUSE_FILTER_PASS
        choose.pressed.connect(Callable(self, "_choose_condition_preparation").bind(str(prep.get("id", ""))))
        card.add_child(choose)

    var back := Button.new()
    back.text = "← 전술 준비 다시 선택"
    back.custom_minimum_size = Vector2(0, 58)
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.mouse_filter = Control.MOUSE_FILTER_PASS
    back.pressed.connect(Callable(self, "_return_to_tactical_preparation"))
    body.add_child(back)

func _render_game_plan() -> void:
    var tactical := GameState.preparation_definition("tactical", str(GameState.state.get("selected_tactical_prep", "")))
    var condition := GameState.preparation_definition("condition", str(GameState.state.get("selected_condition_prep", "")))
    if not tactical.is_empty() or not condition.is_empty():
        var summary := _card_box("이번 준비")
        var parts: Array[String] = []
        if not tactical.is_empty():
            parts.append(str(tactical.get("name", "")))
        if not condition.is_empty():
            parts.append(str(condition.get("name", "")))
        _add_wrapped_label(summary, " · ".join(parts), false)

        var back := Button.new()
        back.text = "← 컨디션 다시 선택"
        back.custom_minimum_size = Vector2(0, 56)
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back.mouse_filter = Control.MOUSE_FILTER_PASS
        back.pressed.connect(Callable(self, "_return_to_condition_preparation"))
        summary.add_child(back)
    super._render_game_plan()

func _return_to_fight_offers() -> void:
    if str(GameState.state.get("phase", "")) == "game_plan" and not str(GameState.state.get("selected_condition_prep", "")).is_empty():
        GameState.return_to_condition_preparation()
        GameState.return_to_tactical_preparation()
        GameState.return_to_fight_offers_from_preparation()
        current_opponent = {}
        _render_phase()
        return
    super._return_to_fight_offers()

func _choose_tactical_preparation(preparation_id: String) -> void:
    var result := GameState.select_tactical_preparation(preparation_id)
    if bool(result.get("ok", false)):
        _render_phase()

func _choose_condition_preparation(preparation_id: String) -> void:
    var result := GameState.select_condition_preparation(preparation_id)
    if bool(result.get("ok", false)):
        _render_phase()

func _return_to_tactical_preparation() -> void:
    var result := GameState.return_to_tactical_preparation()
    if bool(result.get("ok", false)):
        _render_phase()

func _return_to_condition_preparation() -> void:
    var result := GameState.return_to_condition_preparation()
    if bool(result.get("ok", false)):
        _render_phase()

func _return_from_tactical_to_offers() -> void:
    var result := GameState.return_to_fight_offers_from_preparation()
    if bool(result.get("ok", false)):
        current_opponent = {}
        _render_phase()

func _sync_current_opponent() -> void:
    if current_opponent.is_empty():
        current_opponent = _find_opponent(str(GameState.state.get("selected_opponent", "")))
