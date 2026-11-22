from boxing_business import (
    STARTER_SUPPORT, SPONSORS, eligible_sponsors, gate_receipts,
    payment_for_style, best_sponsor_offer, sponsor_payment
)

def main():
    assert STARTER_SUPPORT == 25000
    assert best_sponsor_offer(100, []) is None
    assert best_sponsor_offer(100, ["district"])[0] == "local"
    assert best_sponsor_offer(11, ["district","regional"])[0] == "local"
    assert best_sponsor_offer(12, ["district","regional"])[0] == "regional"
    assert best_sponsor_offer(28, ["district","regional","national"])[0] == "national"
    assert best_sponsor_offer(40, ["district","regional","national","continental"])[0] == "continental"
    assert best_sponsor_offer(50, ["district","regional","national","continental","world_eliminator"])[0] == "global"

    opponent = {"rank": 1, "purse": 500000, "title_kind":"district"}
    before = gate_receipts(100, opponent, has_district_title=False)
    after = gate_receipts(100, opponent, has_district_title=True)
    assert before["gate_share"] == 0 and before["attendance"] > 0
    assert 0 < after["gate_share"] <= 100000
    assert gate_receipts(100, opponent, has_district_title=False)["gate_share"] == 0

    local = SPONSORS["local"]
    assert payment_for_style(local, "steady", "LOSS_DEC")["total"] == 12000
    assert payment_for_style(local, "steady", "WIN_KO")["total"] == 20000
    assert payment_for_style(local, "performance", "LOSS_DEC")["total"] == 6000
    assert payment_for_style(local, "performance", "WIN_DEC")["total"] == 19000
    assert payment_for_style(local, "performance", "WIN_KO")["total"] == 26000

    sponsor = dict(local, style="performance", remaining_fights=4)
    first, sponsor = sponsor_payment(sponsor, "WIN_KO")
    assert first == 26000 and sponsor["remaining_fights"] == 3
    total = first
    for i in range(3):
        payment, sponsor = sponsor_payment(sponsor, "LOSS_DEC")
        total += payment
    assert total == 44000 and sponsor == {}

    world = dict(SPONSORS["global"], style="steady", remaining_fights=4)
    world_bonus, world = sponsor_payment(world, "WIN_DEC", world_defense_win=True)
    assert world_bonus == 80000 + 35000 + 30000

    print("business-economy: PASS")

if __name__ == "__main__":
    main()
