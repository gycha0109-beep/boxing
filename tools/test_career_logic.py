#!/usr/bin/env python3
from simulate_careers import CB, OPPS, TIERS, TITLE_ORDER, TRAINABLE, offers


def main():
    assert len({o["id"] for o in OPPS}) == len(OPPS)
    assert {o["tier"] for o in OPPS} == set(TIERS)
    state = dict(boxer=dict.fromkeys(TRAINABLE, 48), titles=[], background=0, fights=0,
                 streak=0, reputation=0, points=0, wins=0, losses=0, last_opp="",
                 contract=None, champion=False)
    debuts = set()
    for background in range(3):
        state["background"] = background
        choices = offers(state)
        assert len({o["id"] for o in choices}) == 3
        debuts.add(choices[0]["id"])
    assert len(debuts) == 3
    for points in range(0, 101, 5):
        state["points"] = points
        assert not any(o.get("title_fight") for o in offers(state))
    state.update(fights=12, wins=12, titles=TITLE_ORDER.copy())
    assert not any(o.get("title_kind") == "world" for o in offers(state))
    state.update(fights=16, points=88)
    assert offers(state)[0].get("title_kind") == "world"
    assert 0 < CB["economy"]["purse_net_multiplier"] <= 1
    assert set(CB["economy"]["cycle_cost_by_tier"]) == set(TIERS)
    assert CB["retirement"]["health_floor"] < 20
    assert CB["retirement"]["loss_limit"] >= 10
    print("career-logic: PASS")


if __name__ == "__main__":
    main()
