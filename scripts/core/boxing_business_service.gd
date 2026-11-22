extends RefCounted
## Career sponsorships: title-gated tiers, independent four-bout agreements and gate receipts.

const TITLE_ORDER := ["district", "regional", "national", "continental", "world_eliminator"]
const SPONSOR_IDS := ["local", "regional", "national", "continental", "global"]
const TITLE_LABELS := {"district":"구·시 챔피언", "regional":"지역 챔피언", "national":"대한민국 챔피언", "continental":"아시아 챔피언", "world_eliminator":"세계 타이틀 도전자 결정전"}
const SPONSORS := {
    "local": {"name":"지역 스포츠 브랜드", "title":"district", "minimum_reputation":0, "per_fight":12000, "win_bonus":5000, "ko_bonus":3000},
    "regional": {"name":"광역 스포츠 업체", "title":"regional", "minimum_reputation":12, "per_fight":20000, "win_bonus":8000, "ko_bonus":5000},
    "national": {"name":"전국 스포츠 브랜드", "title":"national", "minimum_reputation":28, "per_fight":35000, "win_bonus":15000, "ko_bonus":8000},
    "continental": {"name":"아시아 스포츠 파트너", "title":"continental", "minimum_reputation":40, "per_fight":55000, "win_bonus":25000, "ko_bonus":12000},
    "global": {"name":"글로벌 스포츠 파트너", "title":"world_eliminator", "minimum_reputation":50, "per_fight":80000, "win_bonus":35000, "ko_bonus":20000}
}
const STYLES := {"steady":"안정형", "performance":"성과형"}
const CONTRACT_LENGTH := 4
const BASE_ATTENDANCE := 180
const ATTENDANCE_PER_REPUTATION := 24
const ATTENDANCE_PER_OPPONENT_DRAW := 18
const TICKET_PRICE := 9000
const FIGHTER_GATE_SHARE := 0.0125
const MAX_ATTENDANCE := 5000
const MAX_GATE_SHARE_OF_PURSE := 0.20
const WORLD_DEFENSE_BONUS := 30000
const STARTER_SUPPORT := 25000

static func ensure_state(state: Dictionary) -> void:
    if state.is_empty():
        return
    var career_state: Dictionary = state.get("career_state", {})
    var business: Dictionary = career_state.get("business_state", {})
    business["active_sponsor"] = business.get("active_sponsor", {})
    business["sponsor_decision_fights"] = int(business.get("sponsor_decision_fights", -1))
    business["last_offer_title_level"] = int(business.get("last_offer_title_level", -1))
    business["offer_return_phase"] = str(business.get("offer_return_phase", ""))
    business["total_gate_income"] = int(business.get("total_gate_income", 0))
    business["total_sponsor_income"] = int(business.get("total_sponsor_income", 0))
    business["total_attendance"] = int(business.get("total_attendance", 0))
    business["sponsored_fights"] = int(business.get("sponsored_fights", 0))
    business["last_settlement_index"] = int(business.get("last_settlement_index", -1))
    career_state["business_state"] = business
    state["career_state"] = career_state

static func title_level(state: Dictionary) -> int:
    var titles: Array = state.get("career_state", {}).get("ladder_titles", [])
    for index in range(TITLE_ORDER.size() - 1, -1, -1):
        if TITLE_ORDER[index] in titles:
            return index
    return -1

static func eligible_sponsors(state: Dictionary) -> Array:
    var level := title_level(state)
    var reputation := int(state.get("career", {}).get("reputation", 0))
    var eligible: Array = []
    for index in range(SPONSOR_IDS.size()):
        if index > level:
            break
        var id: String = SPONSOR_IDS[index]
        var offer: Dictionary = SPONSORS[id]
        if reputation >= int(offer.minimum_reputation):
            var entry := offer.duplicate(true)
            entry["id"] = id
            eligible.append(entry)
    eligible.reverse()
    return eligible

static func sponsorship_offers(state: Dictionary) -> Array:
    ensure_state(state)
    if str(state.get("phase", "")) != "sponsor_offer":
        return []
    if not state.career_state.business_state.active_sponsor.is_empty():
        return []
    return eligible_sponsors(state)

static func sponsorship_status(state: Dictionary) -> Dictionary:
    ensure_state(state)
    var business: Dictionary = state.career_state.business_state
    var active: Dictionary = business.active_sponsor
    var next_tier: Dictionary = {}
    var title_level_now := title_level(state)
    if title_level_now + 1 < SPONSOR_IDS.size():
        next_tier = SPONSORS[SPONSOR_IDS[title_level_now + 1]].duplicate(true)
        next_tier["title_label"] = TITLE_LABELS.get(str(next_tier.get("title", "")), "")
    return {
        "active": not active.is_empty(),
        "sponsor": active.duplicate(true),
        "decision_made": int(business.sponsor_decision_fights) == int(state.get("career", {}).get("fights", 0)),
        "total_gate_income": int(business.total_gate_income),
        "total_sponsor_income": int(business.total_sponsor_income),
        "total_attendance": int(business.total_attendance),
        "sponsored_fights": int(business.sponsored_fights),
        "next_tier": next_tier,
        "title_level": title_level_now
    }

static func should_offer(state: Dictionary) -> bool:
    ensure_state(state)
    if bool(state.get("career", {}).get("finished", false)) or title_level(state) < 0:
        return false
    var business: Dictionary = state.career_state.business_state
    if not business.active_sponsor.is_empty():
        return false
    if eligible_sponsors(state).is_empty():
        return false
    var last_at := int(business.sponsor_decision_fights)
    return last_at < 0 or int(state.career.fights) >= last_at + CONTRACT_LENGTH or title_level(state) > int(business.last_offer_title_level)

static func enter_offer_if_due(state: Dictionary) -> bool:
    if str(state.get("phase", "")) not in ["camp", "season_review"]:
        return false
    if not should_offer(state):
        return false
    var business: Dictionary = state.career_state.business_state
    business["offer_return_phase"] = str(state.phase)
    state.phase = "sponsor_offer"
    return true

static func payment_for_style(offer: Dictionary, style: String, result: String) -> Dictionary:
    var base := int(offer.get("per_fight", 0))
    var win_bonus := int(offer.get("win_bonus", 0)) if result.begins_with("WIN") else 0
    var ko_bonus := int(offer.get("ko_bonus", 0)) if result == "WIN_KO" else 0
    if style == "performance":
        base = roundi(float(base) * 0.5)
        win_bonus = roundi(float(win_bonus) * 2.5)
        ko_bonus = roundi(float(ko_bonus) * 2.5)
    var total := base + win_bonus + ko_bonus
    if style == "performance":
        total = roundi(float(total) / 1000.0) * 1000
    return {"base":base, "win_bonus":win_bonus, "ko_bonus":ko_bonus, "total":total}

static func sign_sponsorship(state: Dictionary, sponsor_id: String, style: String = "steady") -> bool:
    if str(state.get("phase", "")) != "sponsor_offer" or not STYLES.has(style):
        return false
    for offer: Dictionary in sponsorship_offers(state):
        if str(offer.get("id", "")) != sponsor_id:
            continue
        var business: Dictionary = state.career_state.business_state
        business["active_sponsor"] = {
            "id":sponsor_id,
            "name":str(offer.name),
            "style":style,
            "per_fight":int(offer.per_fight),
            "win_bonus":int(offer.win_bonus),
            "ko_bonus":int(offer.ko_bonus),
            "remaining_fights":CONTRACT_LENGTH,
            "signed_at_fights":int(state.career.fights)
        }
        _complete_offer(state)
        return true
    return false

static func decline_sponsorship(state: Dictionary) -> bool:
    if str(state.get("phase", "")) != "sponsor_offer":
        return false
    ensure_state(state)
    if not state.career_state.business_state.active_sponsor.is_empty():
        return false
    _complete_offer(state)
    return true

static func _complete_offer(state: Dictionary) -> void:
    var business: Dictionary = state.career_state.business_state
    business["sponsor_decision_fights"] = int(state.career.fights)
    business["last_offer_title_level"] = title_level(state)
    var resume := str(business.get("offer_return_phase", "camp"))
    state.phase = resume if resume in ["camp", "season_review"] else "camp"
    business["offer_return_phase"] = ""

static func preview_bout(state: Dictionary, opponent: Dictionary) -> Dictionary:
    var reputation := maxi(0, int(state.get("career", {}).get("reputation", 0)))
    var rank := clampi(int(opponent.get("rank", 50)), 1, 100)
    var opponent_draw := clampi(51 - rank, 0, 50)
    var title_bonus := 0
    match str(opponent.get("title_kind", "")):
        "district": title_bonus = 120
        "regional": title_bonus = 180
        "national": title_bonus = 240
        "continental": title_bonus = 320
        "world_eliminator": title_bonus = 420
        "world": title_bonus = 520
    var attendance := clampi(BASE_ATTENDANCE + reputation * ATTENDANCE_PER_REPUTATION + opponent_draw * ATTENDANCE_PER_OPPONENT_DRAW + title_bonus, BASE_ATTENDANCE, MAX_ATTENDANCE)
    var gross_gate := attendance * TICKET_PRICE
    var gate_share := mini(
        roundi(float(opponent.get("purse", 0)) * MAX_GATE_SHARE_OF_PURSE),
        roundi(float(gross_gate) * FIGHTER_GATE_SHARE)
    ) if title_level(state) >= 0 else 0
    return {"attendance":attendance, "gate_gross":gross_gate, "gate_share":gate_share}

static func settle_bout(state: Dictionary, opponent: Dictionary, result: String) -> Dictionary:
    ensure_state(state)
    var business: Dictionary = state.career_state.business_state
    var index := int(state.get("career", {}).get("fights", 0))
    if int(business.last_settlement_index) == index:
        return {}
    var gate_preview := preview_bout(state, opponent)
    var gate_share := int(gate_preview.gate_share)
    var sponsor: Dictionary = business.active_sponsor.duplicate(true)
    var base := 0
    var win_bonus := 0
    var ko_bonus := 0
    var defense_bonus := 0
    var sponsor_name := ""
    var sponsor_style := ""
    var remaining := 0
    if not sponsor.is_empty() and int(sponsor.get("remaining_fights", 0)) > 0:
        sponsor_name = str(sponsor.get("name", "스폰서"))
        sponsor_style = str(sponsor.get("style", "steady"))
        var item: Dictionary = payment_for_style(sponsor, sponsor_style, result)
        base = int(item.base)
        win_bonus = int(item.win_bonus)
        ko_bonus = int(item.ko_bonus)
        if bool(state.career.get("champion", false)) and str(opponent.get("title_kind", "")) == "world" and result.begins_with("WIN"):
            defense_bonus = WORLD_DEFENSE_BONUS
        sponsor["remaining_fights"] = int(sponsor.remaining_fights) - 1
        remaining = int(sponsor.remaining_fights)
        business["sponsored_fights"] = int(business.sponsored_fights) + 1
        business["active_sponsor"] = sponsor if remaining > 0 else {}
    var sponsor_payment := base + win_bonus + ko_bonus + defense_bonus
    if sponsor_style == "performance":
        sponsor_payment = roundi(float(base + win_bonus + ko_bonus) / 1000.0) * 1000 + defense_bonus
    var rounding_adjustment := sponsor_payment - base - win_bonus - ko_bonus - defense_bonus
    business["total_sponsor_income"] = int(business.total_sponsor_income) + sponsor_payment
    business["total_gate_income"] = int(business.total_gate_income) + gate_share
    business["total_attendance"] = int(business.total_attendance) + int(gate_preview.attendance)
    business["last_settlement_index"] = index
    state.career.money = int(state.career.money) + gate_share + sponsor_payment
    return {
        "attendance":int(gate_preview.attendance), "gate_gross":int(gate_preview.gate_gross), "gate_share":gate_share,
        "sponsor_name":sponsor_name, "sponsor_style":sponsor_style, "sponsor_base":base,
        "sponsor_win_bonus":win_bonus, "sponsor_ko_bonus":ko_bonus, "sponsor_defense_bonus":defense_bonus,
        "sponsor_rounding_adjustment":rounding_adjustment,
        "sponsor_payment":sponsor_payment, "sponsor_bonus":sponsor_payment - base,
        "sponsor_remaining_fights":remaining, "business_income":gate_share + sponsor_payment
    }
