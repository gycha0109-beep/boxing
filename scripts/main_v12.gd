extends "res://scripts/main_v10.gd"

const LEGACY_ACCENT := Color(0.96, 0.78, 0.36, 1.0)
const LEGACY_MUTED := Color(0.68, 0.70, 0.75, 1.0)
const LEGACY_DANGER := Color(0.95, 0.38, 0.34, 1.0)

var legacy_notice: String = ""

func _render_status() -> void:
    super._render_status()
    var state: Dictionary = GameState.state
    if state.is_empty() or str(state.get("phase", "")) == "career_summary":
        return
    var meta: Dictionary = state.get("meta_state", {})
    var generation := int(meta.get("generation", 1))
    var slots: Array = meta.get("legacy_slots", [])
    var capacity := int(meta.get("legacy_capacity", 3))
    if generation > 1 or not slots.is_empty():
        status.text += "\nGENERATION %d · GYM LEGACY %d/%d" % [generation, slots.size(), capacity]

func _render_camp() -> void:
    super._render_camp()
    _render_active_legacy_summary()
    var recovery_bonus := int(GameState.state.get("career_state", {}).get("last_legacy_cycle_recovery", 0))
    if recovery_bonus > 0:
        var recovery := Label.new()
        recovery.text = "LEGACY RECOVERY · 회복이 한결 빨라졌습니다."
        recovery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        recovery.add_theme_color_override("font_color", LEGACY_ACCENT)
        body.add_child(recovery)

func _render_offers() -> void:
    super._render_offers()
    var bonuses: Dictionary = GameState.state.get("career_state", {}).get("last_legacy_camp_bonus", {})
    if bonuses.is_empty():
        return
    var effect_box := _card_box("LEGACY EFFECT")
    _add_wrapped_label(effect_box, "계승된 노하우가 이번 훈련에 반영됐습니다.", true)
    var parts: Array[String] = []
    for stat in ["power", "speed", "technique", "defense", "conditioning"]:
        if bonuses.has(stat) and int(bonuses[stat]) > 0:
            parts.append("%s +%d" % [_stat_label(stat), int(bonuses[stat])])
    if not parts.is_empty():
        _add_wrapped_label(effect_box, " · ".join(parts), false)

func _render_career_summary() -> void:
    var career: Dictionary = GameState.state.get("career", {})
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var meta: Dictionary = GameState.state.get("meta_state", {})
    var career_state: Dictionary = GameState.state.get("career_state", {})
    var profile: Dictionary = GameState.retirement_legacy_profile()
    var generation := int(meta.get("generation", 1))

    _eyebrow("GYM LEGACY · GENERATION %d" % generation)

    var title := Label.new()
    title.text = "커리어 종료"
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", LEGACY_ACCENT)
    body.add_child(title)

    var summary := _card_box("")
    _add_wrapped_label(summary, GameState.ending_text(), false)
    _add_wrapped_label(summary, "%s · %s" % [str(profile.get("role", "코치")), str(profile.get("flavor", ""))], true)
    _add_wrapped_label(summary, "%s · %d전 %d승 %d패 %d무" % [
        str(boxer.get("name", "무명 복서")), int(career.get("fights", 0)), int(career.get("wins", 0)),
        int(career.get("losses", 0)), int(career.get("draws", 0))
    ], false)
    _add_wrapped_label(summary, "생애 최고 %dpt · 최고 랭킹 #%d · 최종 랭킹 #%d" % [
        int(profile.get("career_high_points", 0)), int(profile.get("career_high_rank", 50)), int(career.get("rank", 50))
    ], true)

    if not legacy_notice.is_empty():
        var notice := Label.new()
        notice.text = legacy_notice
        notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        notice.add_theme_color_override("font_color", LEGACY_DANGER)
        body.add_child(notice)

    career_state = GameState.state.get("career_state", {})
    var selected: Dictionary = career_state.get("retirement_legacy_selected", {})
    var pending: Dictionary = GameState.pending_retirement_legacy()
    if not selected.is_empty():
        _render_selected_legacy(selected)
    elif not pending.is_empty():
        _render_legacy_slot_decision(pending)
    else:
        _render_legacy_candidates(profile)

func _render_legacy_candidates(profile: Dictionary) -> void:
    _section("남길 유산을 하나 선택하십시오", "한 선수는 하나의 복싱 철학만 다음 세대에 남깁니다.")

    var candidates: Array = GameState.retirement_legacy_candidates()
    if candidates.is_empty():
        var missing := Label.new()
        missing.text = "현재 은퇴 성취에 대응하는 Legacy 후보를 만들 수 없습니다."
        missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        missing.add_theme_color_override("font_color", LEGACY_DANGER)
        body.add_child(missing)
        return

    for definition_value in candidates:
        var definition: Dictionary = definition_value
        var card := _card_box(str(definition.get("name", "LEGACY")))
        var tier := Label.new()
        tier.text = "%s · %s" % [_legacy_tier_label(str(profile.get("legacy_tier", "early_pro"))), _stacking_label(str(definition.get("stacking", "additive")))]
        tier.add_theme_font_size_override("font_size", 12)
        tier.add_theme_color_override("font_color", LEGACY_ACCENT)
        card.add_child(tier)
        _add_wrapped_label(card, str(definition.get("description", "")), false)
        _add_wrapped_label(card, _legacy_effect_text(definition.get("effect", {})), true)

        var choose := Button.new()
        choose.text = "이 유산을 남긴다"
        choose.custom_minimum_size = Vector2(0, 62)
        choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choose.pressed.connect(Callable(self, "_choose_retirement_legacy").bind(str(definition.get("id", ""))))
        card.add_child(choose)

func _render_legacy_slot_decision(pending: Dictionary) -> void:
    var definition: Dictionary = GameState.legacy_definition(str(pending.get("definition_id", "")))
    _section("Legacy 슬롯이 가득 찼습니다", "기존 하나를 교체하거나 새 유산을 포기해야 합니다.")

    var pending_card := _card_box("NEW LEGACY · %s" % str(definition.get("name", pending.get("definition_id", "LEGACY"))))
    _add_wrapped_label(pending_card, str(definition.get("description", "")), false)
    _add_wrapped_label(pending_card, _legacy_effect_text(definition.get("effect", {})), true)

    var meta: Dictionary = GameState.state.get("meta_state", {})
    var slots: Array = meta.get("legacy_slots", [])
    for index in range(slots.size()):
        var instance: Dictionary = slots[index]
        var old_definition: Dictionary = GameState.legacy_definition(str(instance.get("definition_id", "")))
        var slot_card := _card_box("SLOT %d · %s" % [index + 1, str(old_definition.get("name", instance.get("definition_id", "")))])
        _add_wrapped_label(slot_card, "%s · GENERATION %d" % [
            str(instance.get("source_boxer_name", "")), int(instance.get("source_generation", 0))
        ], true)
        var replace := Button.new()
        replace.text = "이 슬롯을 새 유산으로 교체"
        replace.custom_minimum_size = Vector2(0, 60)
        replace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        replace.pressed.connect(Callable(self, "_replace_retirement_legacy").bind(index))
        slot_card.add_child(replace)

    var abandon := Button.new()
    abandon.text = "새 유산 포기 · 기존 슬롯 유지"
    abandon.custom_minimum_size = Vector2(0, 60)
    abandon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    abandon.add_theme_color_override("font_color", LEGACY_DANGER)
    abandon.pressed.connect(Callable(self, "_abandon_retirement_legacy"))
    body.add_child(abandon)

func _render_selected_legacy(selected: Dictionary) -> void:
    var definition: Dictionary = GameState.legacy_definition(str(selected.get("definition_id", "")))
    var legacy_status := str(selected.get("legacy_status", "active"))
    if legacy_status == "abandoned":
        _section("유산 기록 완료", "계보에는 남지만 현재 체육관에는 보관하지 않습니다.")
    else:
        _section("유산 확정", "이 선수의 유산이 다음 세대로 이어집니다.")

    var selected_card := _card_box(str(definition.get("name", selected.get("definition_id", "LEGACY"))))
    _add_wrapped_label(selected_card, str(definition.get("description", "")), false)
    _add_wrapped_label(selected_card, "%s · %s" % [str(selected.get("source_boxer_name", "")), str(selected.get("source_flavor", ""))], true)
    if legacy_status == "abandoned":
        _add_wrapped_label(selected_card, "STATUS · 포기됨 / 활성 효과 없음", true)

    var meta: Dictionary = GameState.state.get("meta_state", {})
    var slots: Array = meta.get("legacy_slots", [])
    var capacity := int(meta.get("legacy_capacity", 3))
    var slots_box := _card_box("GYM LEGACY %d / %d" % [slots.size(), capacity])
    for i in range(slots.size()):
        var instance: Dictionary = slots[i]
        var slot_definition: Dictionary = GameState.legacy_definition(str(instance.get("definition_id", "")))
        _add_wrapped_label(slots_box, "[%d] %s · %s" % [i + 1, str(instance.get("source_boxer_name", "")), str(slot_definition.get("name", instance.get("definition_id", "")))], false)

    var next := Button.new()
    next.text = "다음 제자 시작"
    next.custom_minimum_size = Vector2(0, 68)
    next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    next.add_theme_font_size_override("font_size", 18)
    next.pressed.connect(Callable(self, "_start_next_generation"))
    body.add_child(next)

func _render_active_legacy_summary() -> void:
    var meta: Dictionary = GameState.state.get("meta_state", {})
    var slots: Array = meta.get("legacy_slots", [])
    if slots.is_empty():
        return
    var capacity := int(meta.get("legacy_capacity", 3))
    var box := _card_box("GYM LEGACY %d / %d" % [slots.size(), capacity])
    for index in range(slots.size()):
        var instance: Dictionary = slots[index]
        var definition: Dictionary = GameState.legacy_definition(str(instance.get("definition_id", "")))
        _add_wrapped_label(box, "[%d] %s · %s" % [index + 1, str(definition.get("name", instance.get("definition_id", ""))), str(instance.get("source_boxer_name", ""))], false)
        _add_wrapped_label(box, _legacy_effect_text(definition.get("effect", {})), true)

func _choose_retirement_legacy(definition_id: String) -> void:
    legacy_notice = ""
    var result: Dictionary = GameState.select_retirement_legacy(definition_id)
    if not bool(result.get("ok", false)):
        match str(result.get("reason", "")):
            "already_selected": legacy_notice = "이 선수는 이미 하나의 유산을 남겼습니다."
            "slot_decision_pending": legacy_notice = "새 유산의 교체 또는 포기 결정을 먼저 완료해야 합니다."
            _: legacy_notice = "유산 선택을 저장하지 못했습니다."
    _render_phase()

func _replace_retirement_legacy(slot_index: int) -> void:
    legacy_notice = ""
    var result: Dictionary = GameState.replace_retirement_legacy(slot_index)
    if not bool(result.get("ok", false)):
        legacy_notice = "Legacy 슬롯 교체를 저장하지 못했습니다."
    _render_phase()

func _abandon_retirement_legacy() -> void:
    legacy_notice = ""
    var result: Dictionary = GameState.abandon_retirement_legacy()
    if not bool(result.get("ok", false)):
        legacy_notice = "새 Legacy 포기 결정을 저장하지 못했습니다."
    _render_phase()

func _start_next_generation() -> void:
    legacy_notice = ""
    var result: Dictionary = GameState.start_next_generation()
    if not bool(result.get("ok", false)):
        legacy_notice = "다음 세대를 시작하기 전에 유산 하나를 확정해야 합니다."
        _render_phase()
        return
    current_opponent = {}
    _render_phase()

func _legacy_tier_label(tier_id: String) -> String:
    match tier_id:
        "early_pro": return "EARLY LEGACY"
        "mid_pro": return "PRO LEGACY"
        "ranked": return "RANKED LEGACY"
        "title_contender": return "CONTENDER LEGACY"
        "world_class": return "WORLD CLASS LEGACY"
        _: return tier_id.to_upper()

func _stacking_label(stacking: String) -> String:
    match stacking:
        "diminishing": return "겹칠수록 약해짐"
        "capped": return "효과 상한 있음"
        _: return "함께 사용 가능"

func _legacy_effect_text(effect: Dictionary) -> String:
    if effect.is_empty():
        return "체육관의 경험이 다음 세대에 이어집니다."
    var parts: Array[String] = []
    for key_value in effect.keys():
        var key := str(key_value)
        var text := ""
        match key:
            "early_camp_growth_percent": text = "초반 훈련이 더 잘 붙습니다"
            "cycle_recovery_bonus": text = "회복이 조금 더 빠릅니다"
            "early_fatigue_reduction": text = "초반 경기의 피로 부담이 줄어듭니다"
            "training_power_percent": text = "파워 훈련 성과가 좋아집니다"
            "training_conditioning_percent": text = "체력 훈련 성과가 좋아집니다"
            "training_technique_bonus": text = "기술 훈련이 더 잘 붙습니다"
            "jab_training_bonus": text = "미트 훈련에서 잽 감각을 빨리 익힙니다"
            "read_bonus": text = "상대 움직임을 읽기 쉬워집니다"
            "body_technique_bonus": text = "바디 공략이 더 정교해집니다"
            "counter_technique_bonus": text = "카운터 타이밍이 날카로워집니다"
            "title_first_round_defense_bonus": text = "타이틀전 초반 수비가 안정됩니다"
            "post_heavy_damage_recovery": text = "큰 충격 뒤 회복이 빨라집니다"
            "high_fatigue_defense_bonus": text = "지쳐도 수비가 쉽게 무너지지 않습니다"
            "late_round_technique_bonus": text = "후반에도 기술이 흐트러지지 않습니다"
            "late_round_defense_bonus": text = "후반 수비가 단단해집니다"
            "repeat_action_counter_bonus": text = "반복되는 패턴을 더 잘 받아칩니다"
            _:
                continue
        if not text.is_empty() and not parts.has(text):
            parts.append(text)
    if parts.is_empty():
        return "체육관의 경험이 다음 세대에 이어집니다."
    return " · ".join(parts)

func _stat_label(stat: String) -> String:
    match stat:
        "power": return "파워"
        "speed": return "스피드"
        "technique": return "테크닉"
        "defense": return "수비"
        "conditioning": return "컨디셔닝"
        _: return stat

func _plan_effect_text(plan: Dictionary) -> String:
    match str(plan.get("id", "balanced")):
        "outside_boxing": return "잽과 거리 유지에 강함 · 난타전에는 약함"
        "body_breakdown": return "몸통을 쌓아 후반을 노림 · 초반 결정력은 낮음"
        "pressure": return "계속 몰아붙여 교환을 강제 · 카운터와 체력 소모에 취약"
        "counter_trap": return "큰 공격을 읽으면 강력 · 읽기가 틀리면 크게 손해"
        _: return "기본기에 집중해 빈틈 없이 대응"

func _tendency_text(tendencies: Dictionary) -> String:
    var top_id := ""
    var second_id := ""
    var top_value := -1.0
    var second_value := -1.0
    for action_id in ["jab", "body", "power", "guard", "counter"]:
        var probability := float(tendencies.get(action_id, 0.0))
        if probability > top_value:
            second_value = top_value
            second_id = top_id
            top_value = probability
            top_id = action_id
        elif probability > second_value:
            second_value = probability
            second_id = action_id
    if top_id.is_empty() or top_value <= 0.0:
        return "뚜렷한 습관 없음"
    var text := "%s 중심" % _action_label(top_id)
    if not second_id.is_empty() and second_value > 0.0:
        text += " · %s도 섞음" % _action_label(second_id)
    return text

func _choose_game_plan(plan_id: String) -> void:
    if str(GameState.state.get("phase", "")) != "game_plan":
        return
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    GameState.state["pre_game_plan_snapshot"] = {
        "weight_kg": float(boxer.get("weight_kg", 0.0)),
        "fatigue": int(boxer.get("fatigue", 0)),
        "health": int(boxer.get("health", 0)),
        "reputation": int(career.get("reputation", 0))
    }
    var plan_result: Dictionary = GameState.select_game_plan(plan_id)
    if not bool(plan_result.get("ok", false)):
        GameState.state.erase("pre_game_plan_snapshot")
        return
    GameState.state["weigh_in_acknowledged"] = false
    SaveService.save_game(GameState.state)
    _render_phase()

func _render_weigh_in() -> void:
    super._render_weigh_in()
    if str(GameState.state.get("phase", "")) != "fight":
        return
    if bool(GameState.state.get("weigh_in_acknowledged", true)):
        return
    if not GameState.state.get("active_fight", {}).is_empty():
        return
    if GameState.state.get("pre_game_plan_snapshot", {}).is_empty():
        return
    var back := Button.new()
    back.text = "← 게임플랜 다시 선택"
    back.custom_minimum_size = Vector2(0, 58)
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.mouse_filter = Control.MOUSE_FILTER_PASS
    back.pressed.connect(Callable(self, "_return_to_game_plan_selection"))
    body.add_child(back)
    body.move_child(back, 0)

func _return_to_game_plan_selection() -> void:
    if str(GameState.state.get("phase", "")) != "fight":
        return
    if bool(GameState.state.get("weigh_in_acknowledged", true)):
        return
    if not GameState.state.get("active_fight", {}).is_empty():
        return
    var snapshot: Dictionary = GameState.state.get("pre_game_plan_snapshot", {})
    if snapshot.is_empty():
        return
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    boxer["weight_kg"] = float(snapshot.get("weight_kg", boxer.get("weight_kg", 0.0)))
    boxer["fatigue"] = int(snapshot.get("fatigue", boxer.get("fatigue", 0)))
    boxer["health"] = int(snapshot.get("health", boxer.get("health", 0)))
    career["reputation"] = int(snapshot.get("reputation", career.get("reputation", 0)))
    GameState.state["selected_game_plan"] = ""
    GameState.state["last_weigh_in"] = {}
    GameState.state["fight_seed"] = 0
    GameState.state["active_fight"] = {}
    GameState.state["phase"] = "game_plan"
    GameState.state["weigh_in_acknowledged"] = true
    GameState.state.erase("pre_game_plan_snapshot")
    SaveService.save_game(GameState.state)
    _render_phase()

func _acknowledge_weigh_in() -> void:
    GameState.state.erase("pre_game_plan_snapshot")
    super._acknowledge_weigh_in()
