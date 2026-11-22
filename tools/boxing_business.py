"""Mirror of sponsorship and gate rules in scripts/core/boxing_business_service.gd."""
import math

BASE_ATTENDANCE = 180
ATTENDANCE_PER_REPUTATION = 24
ATTENDANCE_PER_OPPONENT_DRAW = 18
TICKET_PRICE = 9000
FIGHTER_GATE_SHARE = .0125
MAX_ATTENDANCE = 5000
MAX_GATE_SHARE_OF_PURSE = .20
CONTRACT_LENGTH = 4
STARTER_SUPPORT = 25000
WORLD_DEFENSE_BONUS = 30000
TITLES = ["district", "regional", "national", "continental", "world_eliminator"]
SPONSOR_IDS = ["local", "regional", "national", "continental", "global"]
TITLE_ATTENDANCE_BONUS = {
    "district":120, "regional":180, "national":240, "continental":320,
    "world_eliminator":420, "world":520
}
SPONSORS = {
    "local":{"name":"지역 스포츠 브랜드","title":"district","minimum_reputation":0,"per_fight":12000,"win_bonus":5000,"ko_bonus":3000},
    "regional":{"name":"광역 스포츠 업체","title":"regional","minimum_reputation":12,"per_fight":20000,"win_bonus":8000,"ko_bonus":5000},
    "national":{"name":"전국 스포츠 브랜드","title":"national","minimum_reputation":28,"per_fight":35000,"win_bonus":15000,"ko_bonus":8000},
    "continental":{"name":"아시아 스포츠 파트너","title":"continental","minimum_reputation":40,"per_fight":55000,"win_bonus":25000,"ko_bonus":12000},
    "global":{"name":"글로벌 스포츠 파트너","title":"world_eliminator","minimum_reputation":50,"per_fight":80000,"win_bonus":35000,"ko_bonus":20000}
}

def title_level(titles: list[str]) -> int:
    return max((i for i, name in enumerate(TITLES) if name in titles), default=-1)


def eligible_sponsors(reputation: int, titles: list[str]) -> list[tuple[str, dict]]:
    upper = title_level(titles)
    return [(sid, SPONSORS[sid]) for i, sid in enumerate(SPONSOR_IDS)
            if i <= upper and reputation >= SPONSORS[sid]["minimum_reputation"]][::-1]


def best_sponsor_offer(reputation: int, titles: list[str]) -> tuple[str, dict] | None:
    options = eligible_sponsors(reputation, titles)
    return options[0] if options else None


def gate_receipts(reputation: int, opponent: dict, booked_purse: int | None = None,
                  has_district_title: bool = False) -> dict:
    rank = max(1, min(100, int(opponent.get("rank", 50))))
    draw = max(0, min(50, 51 - rank))
    attendance = max(BASE_ATTENDANCE, min(MAX_ATTENDANCE, BASE_ATTENDANCE
        + max(0, int(reputation)) * ATTENDANCE_PER_REPUTATION
        + draw * ATTENDANCE_PER_OPPONENT_DRAW
        + TITLE_ATTENDANCE_BONUS.get(str(opponent.get("title_kind", "")), 0)))
    gross_gate = attendance * TICKET_PRICE
    purse = int(opponent.get("purse", 0) if booked_purse is None else booked_purse)
    share = min(round(purse * MAX_GATE_SHARE_OF_PURSE),
                round(gross_gate * FIGHTER_GATE_SHARE)) if has_district_title else 0
    return {"attendance":attendance, "gate_gross":gross_gate, "gate_share":share}


def payment_for_style(sponsor: dict, style: str, result: str) -> dict:
    base = int(sponsor["per_fight"])
    win = int(sponsor["win_bonus"]) if result.startswith("WIN") else 0
    ko = int(sponsor["ko_bonus"]) if result == "WIN_KO" else 0
    if style == "performance":
        base = round(base * .5)
        win = round(win * 2.5)
        ko = round(ko * 2.5)
    total = base + win + ko
    if style == "performance":
        total = math.floor(total / 1000 + .5) * 1000
    return {"base":base, "win_bonus":win, "ko_bonus":ko, "total":total}


def sponsor_payment(sponsor: dict, result: str,
                    world_defense_win: bool = False) -> tuple[int, dict]:
    if not sponsor or int(sponsor.get("remaining_fights", 0)) <= 0:
        return 0, {}
    updated = dict(sponsor)
    payment = payment_for_style(updated, updated.get("style", "steady"), result)["total"]
    if world_defense_win:
        payment += WORLD_DEFENSE_BONUS
    updated["remaining_fights"] = int(updated["remaining_fights"]) - 1
    return payment, updated if updated["remaining_fights"] > 0 else {}
