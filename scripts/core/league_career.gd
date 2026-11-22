extends RefCounted

const STATS := ["power", "speed", "technique", "defense", "conditioning"]
const BACKGROUNDS := {
    "rookie": {"name":"무명 신인", "stats":{}, "money":0, "fans":0, "match":0},
    "amateur": {"name":"아마추어 유망주", "stats":{"technique":5, "speed":3}, "money":35000, "fans":4, "match":6},
    "gym": {"name":"명문 체육관 후계자", "stats":{"defense":3, "conditioning":2}, "money":65000, "fans":9, "match":10}
}
const CONTRACTS := {
    "steady": {"name":"안정 계약", "rate":1.10, "match":-2, "detail":"가까운 실력대의 상대"},
    "challenge": {"name":"도전 계약", "rate":1.35, "match":5, "detail":"한 단계 강한 상대"},
    "draw": {"name":"흥행 계약", "rate":1.20, "match":1, "detail":"흥행 대진 우선"}
}

static func skill(stats: Dictionary) -> float:
    var total := 0
    for key in STATS:
        total += int(stats.get(key, 44))
    return float(total) / STATS.size()

static func snapshot(state: Dictionary) -> Dictionary:
    var c: Dictionary = state.career
    return {"fights":int(c.fights), "wins":int(c.wins), "losses":int(c.losses), "rank":int(c.rank),
        "fans":int(c.reputation), "skill":skill(state.boxer)}

static func ensure(state: Dictionary) -> void:
    var book: Dictionary = state.career_state
    if not book.has("season_start"):
        book.season_start = snapshot(state)
        book.career_start = book.season_start.duplicate(true)
        book.background = "rookie"
        book.contract = "steady"
        book.purse_rate = 1.0
        book.streak = 0
        book.defenses = 0
    if str(state.world_state.champion_boxer_id).is_empty():
        state.world_state.champion_boxer_id = "viktor_kozlov"

static func contract_rate(state: Dictionary, id: String) -> float:
    var bonus := mini(15, int(state.career.reputation) / 5) if id == "draw" else 0
    var ranking_bonus := clampi((50 - int(state.career.rank)) / 5, 0, 10)
    return float(CONTRACTS[id].rate) + (bonus + ranking_bonus) / 100.0

static func target_strength(state: Dictionary) -> float:
    var c: Dictionary = state.career
    var book: Dictionary = state.career_state
    var debut := int(c.fights) == 0
    var target := 42.0 + (skill(state.boxer) - 44.0) * 0.5
    target += (50 - int(c.rank)) * 0.32 + clampf((int(c.wins) - int(c.losses)) * 0.35, -3, 4)
    target += clampi(int(book.streak), -2, 2)
    if debut:
        target += int(BACKGROUNDS[book.background].match) + mini(3, state.meta_state.legacy_slots.size())
    else:
        if book.has("signed_at"):
            target += int(CONTRACTS[book.contract].match)
        if bool(state.get("last_fight_summary", {}).get("upset", false)):
            target += 2.0
    return target

static func offers(state: Dictionary, roster: Array, title: Dictionary) -> Array:
    var result := []
    if not title.is_empty():
        result.append(title)
    var pool := roster.filter(func(o): return str(o.get("title_kind", "")).is_empty())
    var target := target_strength(state)
    var popular := int(state.career.reputation) >= 15 or str(state.career_state.contract) == "draw"
    for offset: float in [0.0, -4.0, 8.0 if popular else 4.0]:
        if pool.is_empty() or result.size() == 3:
            break
        var best: Dictionary = pool[0]
        var best_score := INF
        for opponent: Dictionary in pool:
            var score := absf(skill(opponent.stats) - target - offset)
            if opponent.id == state.get("last_fight_summary", {}).get("opponent_id", ""):
                score += 3.0
            if score < best_score:
                best = opponent
                best_score = score
        result.append(best)
        pool.erase(best)
    return result

static func review(state: Dictionary, start: Dictionary, eligible: bool) -> Dictionary:
    var now := snapshot(state)
    return {"fights":now.fights, "wins":now.wins, "losses":now.losses, "draws":int(state.career.draws),
        "rank":now.rank, "rank_gain":int(start.rank) - int(now.rank), "fans":now.fans,
        "fan_gain":int(now.fans) - int(start.fans), "skill_gain":float(now.skill) - float(start.skill),
        "since":int(start.fights), "health":int(state.boxer.health), "injury":str(state.boxer.injury.get("name", "없음")),
        "title_ready":eligible}

static func event_id(state: Dictionary) -> String:
    var streak := int(state.career_state.streak)
    if not state.boxer.injury.is_empty():
        return "quiet_week"
    if streak <= -2:
        return "family_support"
    if str(state.last_result) == "WIN_KO":
        return "viral_clip"
    if streak >= 2:
        return "rival_callout"
    if bool(state.last_fight_summary.get("upset", false)) or int(state.career.reputation) >= 18:
        return "rival_callout"
    return ""
