extends "res://scripts/main_v10.gd"

const LEGACY_ACCENT := Color(0.96, 0.78, 0.36, 1.0)
const LEGACY_MUTED := Color(0.68, 0.70, 0.75, 1.0)
const LEGACY_DANGER := Color(0.95, 0.38, 0.34, 1.0)

var legacy_notice: String = ""

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
    if selected.is_empty():
        _render_legacy_candidates(profile)
    else:
        _render_selected_legacy(selected)

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

func _render_selected_legacy(selected: Dictionary) -> void:
    var definition: Dictionary = GameState.legacy_definition(str(selected.get("definition_id", "")))
    _section("유산 확정", "이 선수의 커리어에서 선택할 수 있는 Legacy는 이것으로 확정되었습니다.")

    var selected_card := _card_box(str(definition.get("name", selected.get("definition_id", "LEGACY"))))
    _add_wrapped_label(selected_card, str(definition.get("description", "")), false)
    _add_wrapped_label(selected_card, "%s · %s" % [str(selected.get("source_boxer_name", "")), str(selected.get("source_flavor", ""))], true)

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

func _choose_retirement_legacy(definition_id: String) -> void:
    legacy_notice = ""
    var result: Dictionary = GameState.select_retirement_legacy(definition_id)
    if not bool(result.get("ok", false)):
        match str(result.get("reason", "")):
            "already_selected": legacy_notice = "이 선수는 이미 하나의 유산을 남겼습니다."
            "legacy_slots_full": legacy_notice = "활성 Legacy 슬롯이 가득 찼습니다. 기존 유산 교체가 필요합니다."
            _: legacy_notice = "유산 선택을 저장하지 못했습니다."
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
    for key in effect.keys():
        if str(key) == "cap":
            continue
        parts.append("%s %s" % [str(key).replace("_", " "), str(effect[key])])
    return "효과 · %s" % " · ".join(parts)
