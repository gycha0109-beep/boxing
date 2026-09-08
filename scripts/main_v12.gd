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
        recovery.text = "LEGACY RECOVERY · 지난 사이클 피로 %d 추가 회복" % recovery_bonus
        recovery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        recovery.add_theme_color_override("font_color", LEGACY_ACCENT)
        body.add_child(recovery)

func _render_offers() -> void:
    super._render_offers()
    var bonuses: Dictionary = GameState.state.get("career_state", {}).get("last_legacy_camp_bonus", {})
    if bonuses.is_empty():
        return
    var effect_box := _card_box("LEGACY EFFECT")
    _add_wrapped_label(effect_box, "이번 캠프에서 계승된 체육관 노하우가 실제 성장에 반영되었습니다.", true)
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
    _section("남길 유산을 하나 선택하십시오", "한 선수는 정확히 하나의 복싱 철학만 다음 세대에 남깁니다. 선택한 유산은 현재 체육관의 활성 Legacy 슬롯에 저장됩니다.")

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
    _section("Legacy 슬롯이 가득 찼습니다", "이번 선수의 유산은 이미 선택되었습니다. 활성 슬롯 하나를 교체하거나, 새 유산을 포기해야 다음 세대로 넘어갈 수 있습니다.")

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
        _section("유산 기록 완료", "이 선수는 하나의 유산을 남겼지만 활성 슬롯에는 보관하지 않았습니다. 계보 기록에는 그대로 남습니다.")
    else:
        _section("유산 확정", "이 선수의 커리어에서 선택할 수 있는 Legacy는 이것으로 확정되었습니다.")

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
        "diminishing": return "중첩 효율 감소"
        "capped": return "중첩 상한"
        _: return "중첩 가능"

func _legacy_effect_text(effect: Dictionary) -> String:
    if effect.is_empty():
        return "효과 데이터 없음"
    var parts: Array[String] = []
    for key_value in effect.keys():
        var key := str(key_value)
        if key in ["cap", "camp_limit", "fight_limit", "requires_read"]:
            continue
        var value = effect[key]
        match key:
            "early_camp_growth_percent": parts.append("초기 캠프 성장 +%d%%" % int(value))
            "cycle_recovery_bonus": parts.append("사이클 피로 회복 +%d" % int(value))
            "early_fatigue_reduction": parts.append("초반 경기 피로 획득 -%d" % int(value))
            "training_power_percent": parts.append("파워 훈련 성장 +%d%%" % int(value))
            "training_conditioning_percent": parts.append("컨디셔닝 성장 +%d%%" % int(value))
            "training_technique_bonus": parts.append("테크닉 훈련 +%d" % int(value))
            "jab_training_bonus": parts.append("미트 집중 테크닉 +%d" % int(value))
            "read_bonus": parts.append("READ +%d" % int(value))
            "body_technique_bonus": parts.append("바디 테크닉 +%d" % int(value))
            "counter_technique_bonus": parts.append("카운터 테크닉 +%d" % int(value))
            "title_first_round_defense_bonus": parts.append("타이틀전 1R 수비 +%d" % int(value))
            "post_heavy_damage_recovery": parts.append("강한 피격 후 회복 +%d" % int(value))
            "high_fatigue_defense_bonus": parts.append("고피로 수비 +%d" % int(value))
            "late_round_technique_bonus": parts.append("후반 테크닉 +%d" % int(value))
            "late_round_defense_bonus": parts.append("후반 수비 +%d" % int(value))
            "repeat_action_counter_bonus": parts.append("반복 패턴 대응 +%d" % int(value))
            _: parts.append("%s %s" % [key.replace("_", " "), str(value)])
    var condition := ""
    if effect.has("camp_limit"):
        condition = " · 첫 %d캠프" % int(effect.get("camp_limit", 0))
    elif effect.has("fight_limit"):
        condition = " · 첫 %d경기" % int(effect.get("fight_limit", 0))
    elif effect.has("requires_read"):
        condition = " · READ %d+" % int(effect.get("requires_read", 0))
    return "효과 · %s%s" % [" · ".join(parts), condition]

func _stat_label(stat: String) -> String:
    match stat:
        "power": return "파워"
        "speed": return "스피드"
        "technique": return "테크닉"
        "defense": return "수비"
        "conditioning": return "컨디셔닝"
        _: return stat
