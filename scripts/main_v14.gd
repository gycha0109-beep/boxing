extends "res://scripts/main_v13.gd"

func _render_phase() -> void:
    if str(GameState.state.get("phase", "")) == "equipment_shop":
        fighter_profile_root = null
        _clear_body()
        _render_status()
        _render_equipment_shop()
        _configure_mobile_scroll()
        _normalize_fighter_language(self)
        return
    super._render_phase()

func _render_status() -> void:
    super._render_status()
    if launch_gate_active or GameState.state.is_empty():
        return
    if str(GameState.state.get("phase", "")) == "equipment_shop":
        status.text = "CAREER · EQUIPMENT / GYM"

func _render_camp() -> void:
    super._render_camp()
    var invest := Button.new()
    invest.text = "장비 · 체육관 투자"
    invest.custom_minimum_size = Vector2(0, 62)
    invest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    invest.mouse_filter = Control.MOUSE_FILTER_PASS
    invest.pressed.connect(Callable(self, "_open_equipment_shop"))
    body.add_child(invest)

func _open_equipment_shop() -> void:
    if str(GameState.state.get("phase", "")) != "camp":
        return
    GameState.state["phase"] = "equipment_shop"
    SaveService.save_game(GameState.state)
    _render_phase()

func _return_from_equipment_shop() -> void:
    if str(GameState.state.get("phase", "")) != "equipment_shop":
        return
    GameState.state["phase"] = "camp"
    SaveService.save_game(GameState.state)
    _render_phase()

func _render_equipment_shop() -> void:
    _eyebrow("CAREER INVESTMENT · EQUIPMENT")
    _section("번 돈을 복서에게 다시 투자", "개인 장비는 능력치를 조금 보완하고, 체육관 장비는 해당 훈련의 성장 성과를 높입니다. 장비는 이번 복서의 커리어가 끝나면 리셋됩니다.")

    var career: Dictionary = GameState.state.get("career", {})
    var money_box := _card_box("보유 자금")
    _add_wrapped_label(money_box, "%d원" % int(career.get("money", 0)), false)
    if GameState.equipment_total_spent() > 0:
        _add_wrapped_label(money_box, "이번 커리어 장비 투자 · %d원" % GameState.equipment_total_spent(), true)

    _render_equipment_section("personal", "개인 장비", "경기에서 쓰는 장비입니다. 구매 즉시 선수 능력치에 반영됩니다.")
    _render_equipment_section("gym", "체육관 장비", "훈련 자체를 한 번 더 하게 만들지 않고, 같은 훈련의 누적 성장만 더 좋게 만듭니다.")

    var back := Button.new()
    back.text = "← 캠프로 돌아가기"
    back.custom_minimum_size = Vector2(0, 60)
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.mouse_filter = Control.MOUSE_FILTER_PASS
    back.pressed.connect(Callable(self, "_return_from_equipment_shop"))
    body.add_child(back)

func _render_equipment_section(section_id: String, title_text: String, description: String) -> void:
    _section(title_text, description)
    for slot in GameState.equipment_slots(section_id):
        var current: Dictionary = GameState.current_equipment(section_id, slot)
        var next_item: Dictionary = GameState.next_equipment_upgrade(section_id, slot)
        var slot_name := _equipment_slot_name(section_id, slot, current, next_item)
        var card := _card_box(slot_name)

        if current.is_empty():
            _add_wrapped_label(card, "현재 · 기본 장비", true)
        else:
            _add_wrapped_label(card, "현재 · %s" % str(current.get("name", "장비")), false)
            if section_id == "personal":
                _add_wrapped_label(card, _visible_stat_bonus(current.get("stat_bonus", {})), true)
            else:
                _add_wrapped_label(card, str(current.get("description", "훈련 성과가 좋아집니다.")), true)

        if next_item.is_empty():
            _add_wrapped_label(card, "최대 단계", true)
            continue

        _add_wrapped_label(card, "다음 · %s · %d원" % [str(next_item.get("name", "업그레이드")), int(next_item.get("price", 0))], false)
        _add_wrapped_label(card, str(next_item.get("description", "")), true)
        if section_id == "personal":
            _add_wrapped_label(card, _visible_stat_bonus(next_item.get("stat_bonus", {})), true)

        var check: Dictionary = GameState.can_purchase_equipment(section_id, str(next_item.get("id", "")))
        var buy := Button.new()
        buy.custom_minimum_size = Vector2(0, 58)
        buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        buy.mouse_filter = Control.MOUSE_FILTER_PASS
        if bool(check.get("ok", false)):
            buy.text = "구매"
        else:
            match str(check.get("reason", "")):
                "locked": buy.text = "잠김 · %s" % str(check.get("unlock", GameState.equipment_unlock_label(next_item)))
                "money": buy.text = "자금 부족"
                _: buy.text = "구매 불가"
            buy.disabled = true
        buy.pressed.connect(Callable(self, "_purchase_equipment").bind(section_id, str(next_item.get("id", ""))))
        card.add_child(buy)

func _purchase_equipment(section_id: String, item_id: String) -> void:
    var result: Dictionary = GameState.purchase_equipment(section_id, item_id)
    if bool(result.get("ok", false)):
        _render_phase()

func _equipment_slot_name(section_id: String, slot: String, current: Dictionary, next_item: Dictionary) -> String:
    if not current.is_empty():
        return str(current.get("slot_name", slot))
    if not next_item.is_empty():
        return str(next_item.get("slot_name", slot))
    for value in GameState.equipment_catalog(section_id):
        var item: Dictionary = value
        if str(item.get("slot", "")) == slot:
            return str(item.get("slot_name", slot))
    return slot
