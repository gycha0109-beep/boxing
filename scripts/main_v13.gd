extends "res://scripts/main_v12.gd"

func _start_new_career_from_title() -> void:
    GameState.new_career("무명 복서")
    GameState.state["first_launch_acknowledged"] = true
    GameState.state["weigh_in_acknowledged"] = true
    GameState.begin_boxer_creation()
    launch_gate_active = false
    _render_phase()

func _render_phase() -> void:
    var phase := str(GameState.state.get("phase", ""))
    if phase in ["style_select", "talent_reveal"]:
        fighter_profile_root = null
        _clear_body()
        _render_status()
        if phase == "style_select":
            _render_style_select()
        else:
            _render_talent_reveal()
        _configure_mobile_scroll()
        return

    if phase not in ["tactical_prep", "condition_prep"]:
        super._render_phase()
        _normalize_fighter_language(self)
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
    _normalize_fighter_language(self)

func _render_status() -> void:
    super._render_status()
    if launch_gate_active or GameState.state.is_empty():
        return
    var phase := str(GameState.state.get("phase", ""))
    if phase == "style_select":
        status.text = "BOXER CREATION · STEP 1 / 2"
        return
    if phase == "talent_reveal":
        status.text = "BOXER CREATION · STEP 2 / 2"
        return
    if phase == "career_summary":
        return
    var stage := GameState.career_ladder_stage()
    if not stage.is_empty():
        status.text += "\nCAREER · %s" % str(stage.get("label", "동네 신인"))

func _render_style_select() -> void:
    _eyebrow("BOXER CREATION · BOXING STYLE")
    _section("어떤 복서로 시작하시겠습니까?", "복싱 스타일은 이 선수의 출발점입니다. 이후 훈련으로 다른 방향으로 키울 수도 있습니다.")

    var guide := _card_box("능력치가 하는 일")
    for stat in ["power", "speed", "technique", "defense", "conditioning"]:
        _add_wrapped_label(guide, "%s · %s" % [_stat_label(stat).to_upper(), GameState.stat_help(stat)], false)

    for value in GameState.boxing_styles():
        var style: Dictionary = value
        var card := _card_box(str(style.get("name", "균형형")))
        _add_wrapped_label(card, str(style.get("signature", "")), true)
        _add_wrapped_label(card, str(style.get("description", "")), false)
        _add_wrapped_label(card, _visible_stat_bonus(style.get("stat_bonus", {})), true)
        _add_wrapped_label(card, _style_training_hint(str(style.get("id", "balanced"))), true)
        var choose := Button.new()
        choose.text = "이 스타일로 시작"
        choose.custom_minimum_size = Vector2(0, 62)
        choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choose.mouse_filter = Control.MOUSE_FILTER_PASS
        choose.pressed.connect(Callable(self, "_choose_boxing_style").bind(str(style.get("id", "balanced"))))
        card.add_child(choose)

func _render_talent_reveal() -> void:
    _eyebrow("BOXER CREATION · NATURAL TALENT")
    _section("이 선수의 타고난 재능", "스타일은 직접 정했지만 타고난 재능은 선수마다 다릅니다. 이 세대에서는 바꿀 수 없습니다.")

    var boxer: Dictionary = GameState.state.get("boxer", {})
    var style_box := _card_box("복싱 스타일 · %s" % str(boxer.get("identity_name", "균형형")))
    _add_wrapped_label(style_box, str(boxer.get("identity_signature", "")), true)

    var talent: Dictionary = GameState.talent_definition()
    var card := _card_box("타고난 재능 · %s" % str(talent.get("name", boxer.get("trait_name", "무특성"))))
    _add_wrapped_label(card, str(talent.get("description", "")), false)
    _add_wrapped_label(card, _visible_stat_bonus(talent.get("stat_bonus", {})), true)
    _add_wrapped_label(card, _talent_passive_text(str(talent.get("id", ""))), true)

    var begin := Button.new()
    begin.text = "이 복서로 커리어 시작"
    begin.custom_minimum_size = Vector2(0, 68)
    begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    begin.add_theme_font_size_override("font_size", 18)
    begin.pressed.connect(Callable(self, "_confirm_talent"))
    body.add_child(begin)

func _choose_boxing_style(style_id: String) -> void:
    var result: Dictionary = GameState.select_boxing_style(style_id)
    if bool(result.get("ok", false)):
        _render_phase()

func _confirm_talent() -> void:
    var result: Dictionary = GameState.confirm_talent()
    if bool(result.get("ok", false)):
        _render_phase()

func _visible_stat_bonus(bonuses: Dictionary) -> String:
    var parts: Array[String] = []
    for stat in ["power", "speed", "technique", "defense", "conditioning"]:
        var value := int(bonuses.get(stat, 0))
        if value == 0:
            continue
        parts.append("%s %s%d" % [_stat_label(stat).to_upper(), "+" if value > 0 else "", value])
    return "시작 능력치 보정 없음" if parts.is_empty() else " · ".join(parts)

func _style_training_hint(style_id: String) -> String:
    match style_id:
        "pressure_fighter": return "추천 성장 · 파워 / 컨디셔닝"
        "out_boxer": return "추천 성장 · 스피드 / 테크닉"
        "slugger": return "추천 성장 · 파워 / 컨디셔닝"
        "counter_puncher": return "추천 성장 · 테크닉 / 수비"
        _: return "추천 성장 · 원하는 방향으로 자유롭게"

func _talent_passive_text(talent_id: String) -> String:
    match talent_id:
        "iron_chin": return "큰 펀치를 잘 버티지만 성장 속도는 조금 느립니다."
        "glass_cannon": return "한 방은 강하지만 큰 타격과 부상에 취약합니다."
        "workhorse": return "훈련할 때 피로가 덜 쌓입니다."
        "technician": return "공격이 더 정교하지만 순수 파워는 낮습니다."
        "crowd_favorite": return "파이트머니와 인지도가 더 빨리 오릅니다."
        "quick_healer": return "피로와 부상에서 더 빨리 회복합니다."
        _: return "이 선수만의 타고난 장단점입니다."

func _render_career_ladder_card() -> void:
    var current := GameState.career_ladder_stage()
    var next := GameState.career_ladder_next_stage()
    var career: Dictionary = GameState.state.get("career", {})
    var card := _card_box("CAREER LADDER · %s" % str(current.get("label", "동네 신인")))
    if next.is_empty():
        if GameState.world_title_ready():
            _add_wrapped_label(card, "월드 타이틀 도전 자격 확보 · 이제 세계 챔피언전을 노릴 수 있습니다.", true)
        else:
            _add_wrapped_label(card, "세계 타이틀 도전 조건 · 최소 16전 / 12승", true)
    else:
        _add_wrapped_label(card, "다음 단계 · %s" % str(next.get("label", "")), false)
        _add_wrapped_label(card, "현재 %d전 %d승 · 필요 %d전 %d승" % [
            int(career.get("fights", 0)), int(career.get("wins", 0)),
            int(next.get("min_fights", 0)), int(next.get("min_wins", 0))
        ], true)

func _render_camp() -> void:
    super._render_camp()
    _render_career_ladder_card()

func _render_offers() -> void:
    super._render_offers()
    _render_career_ladder_card()

func _render_player_visual_card() -> void:
    super._render_player_visual_card()
    var guide := _card_box("스탯 설명")
    for stat in ["power", "speed", "technique", "defense", "conditioning"]:
        _add_wrapped_label(guide, "%s · %s" % [_stat_label(stat), GameState.stat_help(stat)], false)

func _normalize_fighter_language(root: Node) -> void:
    if root is Label:
        var label := root as Label
        label.text = label.text.replace("특성 [", "타고난 재능 [")
        label.text = label.text.replace("복싱 정체성", "복싱 스타일")
    for child in root.get_children():
        _normalize_fighter_language(child)

func _should_insert_persistent_fighter_profile() -> bool:
    var phase := str(GameState.state.get("phase", ""))
    if phase in ["tactical_prep", "condition_prep"]:
        return not launch_gate_active and is_instance_valid(body) and not GameState.state.is_empty()
    return super._should_insert_persistent_fighter_profile()

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
