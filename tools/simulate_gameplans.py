#!/usr/bin/env python3
import json
from pathlib import Path
from sim_combat import fight

ROOT = Path(__file__).resolve().parents[1]
OPPONENTS = {o["id"]: o for o in json.loads((ROOT / "data/opponents.json").read_text())}
PLANS = [p["id"] for p in json.loads((ROOT / "data/game_plans.json").read_text())]
REPRESENTATIVES = ["han_do-yun", "seo_min-jae", "park_tae-ho", "lee_jun-seok"]
PLAYER = {"power":56,"speed":56,"technique":56,"defense":56,"conditioning":56,"fatigue":0,"health":100,"modifiers":{}}


def win_rate(opponent, plan_id, n=1200):
    seed_base = (REPRESENTATIVES.index(opponent["id"]) + 1) * 100_000_000 + PLANS.index(plan_id) * 1_000_000
    wins = 0
    for i in range(n):
        result = fight(seed_base + i, opponent, PLAYER, plan_id)["result"]
        wins += int(result.startswith("WIN"))
    return wins / n


def main():
    matrix = {}
    best_counts = {p: 0 for p in PLANS}
    for opponent_id in REPRESENTATIVES:
        opponent = OPPONENTS[opponent_id]
        rates = {plan_id: win_rate(opponent, plan_id) for plan_id in PLANS}
        matrix[opponent_id] = rates
        best_plan = max(rates, key=rates.get)
        best_counts[best_plan] += 1
        spread = max(rates.values()) - min(rates.values())
        suggested = opponent["scouting"]["suggested_plans"]
        best_suggested = max(rates[p] for p in suggested)
        print(f"{opponent['name']} [{opponent['style']}] " + " ".join(f"{p}={rates[p]:.3f}" for p in PLANS) + f" best={best_plan} spread={spread:.3f}")
        assert spread >= 0.025, f"game plans do not materially change outcome vs {opponent_id}: spread={spread:.3f}"
        assert best_suggested >= rates[best_plan] - 0.10, f"scouting recommendation misleading vs {opponent_id}: best={best_plan}"

    dominant_plan = max(best_counts, key=best_counts.get)
    assert best_counts[dominant_plan] < len(REPRESENTATIVES), f"single universal best plan detected: {dominant_plan}"
    non_balanced_best = sum(count for plan, count in best_counts.items() if plan != "balanced")
    assert non_balanced_best >= 3, f"specialized plans rarely beat balanced: {best_counts}"
    print(f"gameplan-best-counts={best_counts}")
    print("gameplan-simulation: PASS")


if __name__ == "__main__":
    main()
