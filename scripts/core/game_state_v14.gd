extends "res://scripts/core/game_state_v12.gd"

const WORLD_TITLE_MIN_FIGHTS := 16
const WORLD_TITLE_MIN_WINS := 12

const CAREER_LADDER := [
    {"id":"local_rookie", "label":"동네 신인", "min_fights":0, "min_wins":0},
    {"id":"district", "label":"구·시 챔피언", "min_fights":3, "min_wins":2},
    {"id":"regional", "label":"지역 챔피언", "min_fights":6, "min_wins":4},
    {"id":"national", "label":"대한민국 챔피언", "min_fights":9, "min_wins":6},
    {"id":"continental", "label":"아시아 챔피언", "min_fights":12, "min_wins":8},
    {"id":"world_ranked", "label":"세계 랭커", "min_fights":14, "min_wins":10},
    {"id":"world_contender", "label":"세계 타이틀 도전자", "min_fights":16, "min_wins":12}
]

const STAT_HELP := {
    "power": "펀치 피해와 KO 위력",
    "speed": "선공과 적중에 유리",
    "technique": "공격 정확도와 피해 안정성",
    "defense": "피격과 KO 위험을 줄임",
    "conditioning": "체력 소모를 줄이고 후반을 버팀"
}

func begin_boxer_creation() -> void:
    if state.is_empty():
        return
    state["phase"] = "style_select"
    state["boxer_creation_complete"] = false
    state["talent_revealed"] = false
    SaveService.save_game(state)

func boxing_styles() -> Array:
    return fighter_identities.duplicate(true)

func select_boxing_style(identity_id: String) -> Dictionary:
    if str(state.get("phase", "")) != "style_select":
        return {"ok": false, "reason": "wrong_phase"}
    var selected := _identity_by_id(identity_id)
    if selected.is_empty():
        return {"ok": false, "reason": "unknown_style"}

    var boxer: Dictionary = state.get("boxer", {})
    var current := _identity_by_id(str(boxer.get("identity_id", "balanced")))
    var current_bonus: Dictionary = current.get("stat_bonus", {})
    var selected_bonus: Dictionary = selected.get("stat_bonus", {})
    for stat in TRAINABLE_STATS:
        var without_old := int(boxer.get(stat, 50)) - int(current_bonus.get(stat, 0))
        boxer[stat] = clamp(without_old + int(selected_bonus.get(stat, 0)), 1, 100)

    boxer["identity_id"] = str(selected.get("id", "balanced"))
    boxer["identity_name"] = str(selected.get("name", "균형형"))
    boxer["identity_description"] = str(selected.get("description", ""))
    boxer["identity_signature"] = str(selected.get("signature", ""))
    state["phase"] = "talent_reveal"
    state["talent_revealed"] = true
    SaveService.save_game(state)
    return {"ok": true, "style": selected.duplicate(true)}

func talent_definition() -> Dictionary:
    var trait_id := str(state.get("boxer", {}).get("trait_id", ""))
    for value in traits:
        var trait: Dictionary = value
        if str(trait.get("id", "")) == trait_id:
            return trait.duplicate(true)
    return {}

func confirm_talent() -> Dictionary:
    if str(state.get("phase", "")) != "talent_reveal":
        return {"ok": false, "reason": "wrong_phase"}
    state["boxer_creation_complete"] = true
    state["phase"] = "camp"
    SaveService.save_game(state)
    return {"ok": true}

func stat_help(stat_id: String) -> String:
    return str(STAT_HELP.get(stat_id, ""))

func career_ladder_stage() -> Dictionary:
    var career: Dictionary = state.get("career", {})
    var fights := int(career.get("fights", 0))
    var wins := int(career.get("wins", 0))
    var resolved: Dictionary = CAREER_LADDER[0].duplicate(true)
    for value in CAREER_LADDER:
        var stage: Dictionary = value
        if fights >= int(stage.get("min_fights", 0)) and wins >= int(stage.get("min_wins", 0)):
            resolved = stage.duplicate(true)
        else:
            break
    return resolved

func career_ladder_next_stage() -> Dictionary:
    var current := career_ladder_stage()
    var found_current := false
    for value in CAREER_LADDER:
        var stage: Dictionary = value
        if found_current:
            return stage.duplicate(true)
        if str(stage.get("id", "")) == str(current.get("id", "")):
            found_current = true
    return {}

func world_title_ready() -> bool:
    var career: Dictionary = state.get("career", {})
    return int(career.get("fights", 0)) >= WORLD_TITLE_MIN_FIGHTS and int(career.get("wins", 0)) >= WORLD_TITLE_MIN_WINS

func get_fight_offers(all_opponents: Array) -> Array:
    var offers: Array = super.get_fight_offers(all_opponents)
    if world_title_ready():
        return offers

    var filtered: Array = []
    for value in offers:
        var opponent: Dictionary = value
        if bool(opponent.get("title_fight", false)):
            continue
        filtered.append(opponent)

    if filtered.size() < 3:
        for value in all_opponents:
            var opponent: Dictionary = value
            if bool(opponent.get("title_fight", false)):
                continue
            if str(opponent.get("tier", "")) != "world":
                continue
            if not filtered.has(opponent):
                filtered.append(opponent)
            if filtered.size() >= 3:
                break
    return filtered

func start_next_generation() -> Dictionary:
    var result: Dictionary = super.start_next_generation()
    if bool(result.get("ok", false)):
        begin_boxer_creation()
    return result
