extends "res://scripts/core/game_state_v14.gd"

const League := preload("res://scripts/core/league_career.gd")
const STARTING_BASE_STAT := 44
const EQUIPMENT_PATH := "res://data/equipment.json"
const EQUIPMENT_SECTIONS := ["personal", "gym"]

func new_career(boxer_name: String, trait_id: String = "") -> void:
    SaveService.begin_transition()
    super.new_career(boxer_name, trait_id)
    _rebase_starting_stats()
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    career_state["equipment_state"] = {
        "personal": {},
        "gym": {},
        "growth_carry": {},
        "total_spent": 0
    }
    state["career_state"] = career_state
    career_state.season_start = League.snapshot(state)
    career_state.career_start = career_state.season_start.duplicate(true)
    SaveService.finish_transition(state)

func equipment_catalog(section: String = "") -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EQUIPMENT_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        return []
    if section.is_empty():
        var merged: Array = []
        for section_id in EQUIPMENT_SECTIONS:
            var values: Variant = parsed.get(section_id, [])
            if typeof(values) == TYPE_ARRAY:
                for value in values:
                    var item: Dictionary = value
                    var copy := item.duplicate(true)
                    copy["section"] = section_id
                    merged.append(copy)
        return merged
    var values: Variant = parsed.get(section, [])
    if typeof(values) != TYPE_ARRAY:
        return []
    var result: Array = []
    for value in values:
        var item: Dictionary = value
        var copy := item.duplicate(true)
        copy["section"] = section
        result.append(copy)
    return result

func equipment_slots(section: String) -> Array[String]:
    var slots: Array[String] = []
    for value in equipment_catalog(section):
        var item: Dictionary = value
        var slot := str(item.get("slot", ""))
        if not slot.is_empty() and slot not in slots:
            slots.append(slot)
    return slots

func equipment_definition(item_id: String) -> Dictionary:
    for value in equipment_catalog():
        var item: Dictionary = value
        if str(item.get("id", "")) == item_id:
            return item.duplicate(true)
    return {}

func current_equipment(section: String, slot: String) -> Dictionary:
    var equipment_state := _equipment_state()
    var section_state: Dictionary = equipment_state.get(section, {})
    var item_id := str(section_state.get(slot, ""))
    return equipment_definition(item_id) if not item_id.is_empty() else {}

func next_equipment_upgrade(section: String, slot: String) -> Dictionary:
    var current := current_equipment(section, slot)
    var current_tier := int(current.get("tier", 0))
    var candidate: Dictionary = {}
    for value in equipment_catalog(section):
        var item: Dictionary = value
        if str(item.get("slot", "")) != slot:
            continue
        if int(item.get("tier", 0)) == current_tier + 1:
            candidate = item.duplicate(true)
            break
    return candidate

func equipment_unlock_label(item: Dictionary) -> String:
    var required := str(item.get("required_title", ""))
    match required:
        "regional": return "지역 챔피언 이후"
        "continental": return "아시아 챔피언 이후"
        _: return "지금 구매 가능"

func can_purchase_equipment(section: String, item_id: String) -> Dictionary:
    if str(state.get("phase", "")) not in ["camp", "equipment_shop"]:
        return {"ok": false, "reason": "wrong_phase"}
    if section not in EQUIPMENT_SECTIONS:
        return {"ok": false, "reason": "unknown_section"}
    var item := equipment_definition(item_id)
    if item.is_empty() or str(item.get("section", "")) != section:
        return {"ok": false, "reason": "unknown_item"}

    var slot := str(item.get("slot", ""))
    var expected := next_equipment_upgrade(section, slot)
    if expected.is_empty() or str(expected.get("id", "")) != item_id:
        return {"ok": false, "reason": "not_next_upgrade"}

    var required := str(item.get("required_title", ""))
    if not required.is_empty() and not _has_ladder_title(required):
        return {"ok": false, "reason": "locked", "unlock": equipment_unlock_label(item)}

    var price := int(item.get("price", 0))
    if int(state.get("career", {}).get("money", 0)) < price:
        return {"ok": false, "reason": "money"}
    return {"ok": true}

func equipment_stat_changes(previous: Dictionary, item: Dictionary) -> Dictionary:
    var changes := {}
    var previous_bonus: Dictionary = previous.get("stat_bonus", {})
    var next_bonus: Dictionary = item.get("stat_bonus", {})
    for stat in TRAINABLE_STATS:
        var delta := int(next_bonus.get(stat, 0)) - int(previous_bonus.get(stat, 0))
        if delta != 0:
            var before := int(state.boxer.get(stat, STARTING_BASE_STAT))
            changes[stat] = {"from": before, "to": clampi(before + delta, 1, 100)}
    return changes


func purchase_equipment(section: String, item_id: String) -> Dictionary:
    var allowed := can_purchase_equipment(section, item_id)
    if not bool(allowed.get("ok", false)):
        return allowed

    var item := equipment_definition(item_id)
    var slot := str(item.get("slot", ""))
    var previous := current_equipment(section, slot)
    var price := int(item.get("price", 0))
    state.career.money = int(state.career.money) - price

    var stat_changes := equipment_stat_changes(previous, item) if section == "personal" else {}
    for stat in stat_changes:
        state.boxer[stat] = stat_changes[stat]["to"]


    var equipment_state := _equipment_state()
    var section_state: Dictionary = equipment_state.get(section, {}).duplicate(true)
    section_state[slot] = item_id
    equipment_state[section] = section_state
    equipment_state["total_spent"] = int(equipment_state.get("total_spent", 0)) + price
    _store_equipment_state(equipment_state)
    state.last_camp_action = item_id
    state.phase = "fight_offer"
    SaveService.save_game(state)
    return {"ok": true, "item": item.duplicate(true), "previous": previous.duplicate(true), "money": int(state.career.money), "stat_changes": stat_changes}

func apply_camp_action(action: Dictionary) -> Dictionary:
    var result: Dictionary = super.apply_camp_action(action)
    if not bool(result.get("ok", false)):
        return result
    if str(action.get("kind", "training")) != "training":
        return result

    var percent := gym_training_percent(str(action.get("id", "")))
    if state.career_state.background == "gym":
        percent += 20.0
    if percent <= 0.0:
        return result

    var equipment_state := _equipment_state()
    var carry: Dictionary = equipment_state.get("growth_carry", {}).duplicate(true)
    var bonuses: Dictionary = {}
    var effects: Dictionary = action.get("effects", {})
    var action_id := str(action.get("id", ""))
    for stat in TRAINABLE_STATS:
        var raw_gain := int(effects.get(stat, 0))
        if raw_gain <= 0:
            continue
        var carry_key := "%s:%s" % [action_id, stat]
        var fractional := float(carry.get(carry_key, 0.0)) + float(raw_gain) * percent / 100.0
        var bonus := int(floor(fractional + 0.000001))
        carry[carry_key] = fractional - float(bonus)
        if bonus <= 0:
            continue
        var before := int(state.boxer.get(stat, STARTING_BASE_STAT))
        var after := int(clamp(before + bonus, 1, 100))
        state.boxer[stat] = after
        if after > before:
            bonuses[stat] = after - before

    equipment_state["growth_carry"] = carry
    _store_equipment_state(equipment_state)
    if not bonuses.is_empty():
        result["equipment_growth_bonus"] = bonuses.duplicate(true)
    SaveService.save_game(state)
    return result

func gym_training_percent(action_id: String) -> float:
    var best := 0.0
    for slot in equipment_slots("gym"):
        var item := current_equipment("gym", slot)
        if item.is_empty():
            continue
        var actions: Array = item.get("action_ids", [])
        if action_id in actions:
            best = max(best, float(item.get("training_percent", 0.0)))
    return best

func equipment_total_spent() -> int:
    return int(_equipment_state().get("total_spent", 0))

func _rebase_starting_stats() -> void:
    var boxer: Dictionary = state.get("boxer", {})
    var trait_data := talent_definition()
    var identity := _identity_by_id(str(boxer.get("identity_id", "balanced")))
    var trait_bonus: Dictionary = trait_data.get("stat_bonus", {})
    var identity_bonus: Dictionary = identity.get("stat_bonus", {})
    for stat in TRAINABLE_STATS:
        boxer[stat] = clamp(STARTING_BASE_STAT + int(trait_bonus.get(stat, 0)) + int(identity_bonus.get(stat, 0)), 1, 100)

func _equipment_state() -> Dictionary:
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    var equipment_state: Dictionary = {}
    if typeof(career_state.get("equipment_state", {})) == TYPE_DICTIONARY:
        equipment_state = career_state.get("equipment_state", {}).duplicate(true)
    if not equipment_state.has("personal") or typeof(equipment_state.get("personal")) != TYPE_DICTIONARY:
        equipment_state["personal"] = {}
    if not equipment_state.has("gym") or typeof(equipment_state.get("gym")) != TYPE_DICTIONARY:
        equipment_state["gym"] = {}
    if not equipment_state.has("growth_carry") or typeof(equipment_state.get("growth_carry")) != TYPE_DICTIONARY:
        equipment_state["growth_carry"] = {}
    equipment_state["total_spent"] = int(equipment_state.get("total_spent", 0))
    return equipment_state

func _store_equipment_state(equipment_state: Dictionary) -> void:
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    career_state["equipment_state"] = equipment_state.duplicate(true)
    state["career_state"] = career_state

func _opponent_selected_phase() -> String:
    return "game_plan"

func select_background(id: String, boxer_name: String) -> bool:
    if state.phase != "style_select" or not League.BACKGROUNDS.has(id):
        return false
    var book: Dictionary = state.career_state
    var previous: Dictionary = League.BACKGROUNDS[book.background]
    var chosen: Dictionary = League.BACKGROUNDS[id]
    for stat in TRAINABLE_STATS:
        state.boxer[stat] += int(chosen.stats.get(stat, 0)) - int(previous.stats.get(stat, 0))
    state.career.money += int(chosen.money) - int(previous.money)
    state.career.reputation += int(chosen.fans) - int(previous.fans)
    book.background = id
    var trimmed := boxer_name.strip_edges().left(16)
    if not trimmed.is_empty():
        state.boxer.name = trimmed
    SaveService.save_game(state)
    return true

func confirm_talent() -> Dictionary:
    if state.phase == "talent_reveal":
        state.career_state.season_start = League.snapshot(state)
        state.career_state.career_start = state.career_state.season_start.duplicate(true)
    return super.confirm_talent()

func management_visit() -> bool:
    if state.phase != "camp":
        return false
    state.career.reputation += 2
    state.last_camp_action = "media_visit"
    state.phase = "fight_offer"
    SaveService.save_game(state)
    return true

func quoted_purse(opponent: Dictionary) -> int:
    var draw_bonus := mini(10, int(state.career.reputation) / 5)
    return roundi(float(opponent.purse) * float(state.career_state.purse_rate) * (1.0 + draw_bonus / 100.0))

func select_opponent(opponent: Dictionary) -> void:
    if state.phase != "fight_offer":
        return
    state.career_state.booked_purse = quoted_purse(opponent)
    super.select_opponent(opponent)

func get_fight_offers(all_opponents: Array) -> Array:
    var title := {}
    if bool(state.career.champion):
        var challengers := all_opponents.filter(func(o): return str(o.get("title_kind", "")) == "world")
        if not challengers.is_empty():
            return [challengers[int(state.career_state.defenses + 1) % challengers.size()]]
    elif world_title_ready():
        for opponent: Dictionary in all_opponents:
            if opponent.id == state.world_state.champion_boxer_id and opponent.get("title_kind") == "world":
                title = opponent
                break
        if title.is_empty():
            title = _opponent_for_title_kind(all_opponents, "world")
    else:
        var kind := _eligible_ladder_title_kind()
        if not kind.is_empty():
            title = _opponent_for_title_kind(all_opponents, kind)
    return League.offers(state, all_opponents, title)

func world_title_ready() -> bool:
    return super.world_title_ready() and League.skill(state.boxer) >= 46.0

func apply_fight_result(result: String, opponent: Dictionary, snapshot: Dictionary = {}) -> void:
    if state.phase != "fight":
        return
    SaveService.begin_transition()
    var paid := opponent.duplicate(true)
    paid.purse = int(state.career_state.get("booked_purse", quoted_purse(opponent)))
    var world_bout: bool = opponent.get("title_kind", "") == "world"
    var defending := bool(state.career.champion)
    if world_bout:
        paid.title_fight = false
    var won := result.begins_with("WIN")
    var upset := won and int(opponent.rank) + 5 <= int(state.career.rank)
    super.apply_fight_result(result, paid, snapshot)
    var book: Dictionary = state.career_state
    book.erase("booked_purse")
    var c: Dictionary = state.career
    if won:
        book.streak = maxi(0, int(book.streak)) + 1
        var growth_stat := "technique" if result == "WIN_DEC" else "power"
        state.boxer[growth_stat] = mini(100, int(state.boxer[growth_stat]) + 1)
        if result == "WIN_KO":
            c.reputation += 2
    elif result.begins_with("LOSS"):
        book.streak = mini(0, int(book.streak)) - 1
    else:
        book.streak = 0
    # A sustained losing run with accumulated damage can end a career before
    # the existing lifetime loss limit, even above the medical retirement floor.
    if not c.finished and not defending and int(book.streak) <= -6 and int(state.boxer.health) <= 30:
        c.finished = true
        c.ending = "decline_retirement"
    state.last_fight_summary.upset = upset
    var date: Dictionary = state.world_state.world_date
    var month := int(date.month) - 1 + int(career_balance.calendar.months_per_fight)
    date.year += month / 12
    date.month = month % 12 + 1
    if world_bout:
        if won:
            c.champion = true
            book.defenses += int(defending)
            state.world_state.champion_boxer_id = "player_%d" % int(state.meta_state.generation)
            if int(book.defenses) >= 3 or bool(c.finished):
                c.finished = true
                c.ending = "world_champion"
        elif defending and result.begins_with("LOSS"):
            c.champion = false
            c.finished = true
            c.ending = "title_lost"
            state.world_state.champion_boxer_id = str(opponent.id)
        elif defending:
            book.defenses += 1
            if int(book.defenses) >= 3:
                c.finished = true
                c.ending = "world_champion"
        if won or defending:
            state.world_state.title_history.append({"year":date.year, "month":date.month,
                "boxer":state.boxer.name, "generation":state.meta_state.generation, "opponent":opponent.id,
                "result":result, "defense":defending, "holder":state.world_state.champion_boxer_id})
        if c.champion:
            _award_slot("world_champion", 4)
            if int(book.defenses) >= 3:
                _award_slot("three_defenses", 5)
    if int(c.fights) == 12:
        book.milestone = _career_review(book.career_start)
    state.phase = "result"
    SaveService.finish_transition(state)

func _award_slot(id: String, capacity: int) -> void:
    var meta: Dictionary = state.meta_state
    if id not in meta.achievements:
        meta.achievements.append(id)
    meta.legacy_capacity = maxi(int(meta.legacy_capacity), capacity)

func _pick_event() -> Dictionary:
    var preferred := League.event_id(state)
    for event: Dictionary in events:
        if event.id == preferred:
            return event
    return super._pick_event()

func advance_after_result() -> void:
    if state.phase == "result":
        super.advance_after_result()

func resolve_pending_event() -> void:
    if state.phase == "event":
        super.resolve_pending_event()

func _begin_next_cycle() -> void:
    SaveService.begin_transition()
    super._begin_next_cycle()
    if not state.career.finished:
        if bool(state.career.champion):
            state.phase = "champion_choice"
        elif int(state.career.fights) > 0 and int(state.career.fights) % 4 == 0:
            state.phase = "season_review"
    SaveService.finish_transition(state)

func season_review() -> Dictionary:
    return _career_review(state.career_state.season_start)

func _career_review(start: Dictionary) -> Dictionary:
    var report := League.review(state, start, world_title_ready())
    var goal := career_ladder_next_stage()
    var available := not _eligible_ladder_title_kind().is_empty() or world_title_ready()
    report.next_title = "%s · %s" % [goal.get("label", "세계 타이틀"), "제안 가능" if available else "도전 준비 중"]
    if bool(state.career.champion):
        report.next_title = "세계 챔피언 · 방어 %d회" % int(state.career_state.defenses)
    return report

func sign_contract(id: String) -> bool:
    if state.phase != "season_review" or not League.CONTRACTS.has(id):
        return false
    var book: Dictionary = state.career_state
    book.last_review = season_review()
    book.contract = id
    book.purse_rate = League.contract_rate(state, id)
    book.signed_at = int(state.career.fights)
    book.season_start = League.snapshot(state)
    state.phase = "camp"
    SaveService.save_game(state)
    return true

func champion_decision(defend: bool) -> bool:
    if state.phase != "champion_choice":
        return false
    if defend:
        state.phase = "season_review" if int(state.career.fights) % 4 == 0 else "camp"
    else:
        state.career.finished = true
        state.career.ending = "world_champion"
        state.phase = "career_summary"
    SaveService.save_game(state)
    return true

func start_next_generation() -> Dictionary:
    SaveService.begin_transition()
    var result := super.start_next_generation()
    if result.get("ok", false):
        if str(state.world_state.champion_boxer_id).begins_with("player_"):
            state.world_state.champion_boxer_id = "diego_reyes"
        if not state.meta_state.legacy_slots.is_empty():
            select_background("gym", str(state.boxer.name))
    SaveService.finish_transition(state)
    return result
