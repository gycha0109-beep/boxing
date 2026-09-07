#!/usr/bin/env python3
import json
from pathlib import Path
from sim_combat import fight

ROOT = Path(__file__).resolve().parents[1]
OPPONENTS = {o["id"]: o for o in json.loads((ROOT / "data/opponents.json").read_text())}
PLANS = [p["id"] for p in json.loads((ROOT / "data/game_plans.json").read_text())]
REPRESENTATIVES = ["han_do-yun", "seo_min-jae", "park_tae-ho", "lee_jun-seok"]
PLAYER = {"power":56,"speed":56,"technique":56,"defense":56,"conditioning":56,"fatigue":0,"health":100,"modifiers":{}}


def win_rate(opponent, plan_id, n=2000):
    # Use the same seed range for every plan against an opponent so plan comparisons
    # are not biased by unrelated random samples.
    seed_base = (REPRESENTATIVES.index(opponent["id"]) + 1) * 100_000_000
    wins = 0
    for i in range(n):
        result = fight(seed_base + i, opponent, PLAYER, plan_id)["result"]
        wins += int(result.startswith("WIN"))
    return wins / n


def main():
    best_counts = {p: 0 for p in PLANS}
    for opponent_id in REPRESENTATIVES:
        opponent = OPPONENTS[opponent_id]
        rates = {plan_id: win_rate(opponent, plan_id) for plan_id in PLANS}
        best_plan = max(rates, key=rates.get)
        best_counts[best_plan] += 1
        spread = max(rates.values()) - min(rates.values())
        suggested = opponent["scouting"]["suggested_plans"]
        print(
            f"{opponent['name']} [{opponent['style']}] "
            + " ".join(f"{p}={rates[p]:.3f}" for p in PLANS)
            + f" best={best_plan} suggested={suggested} spread={spread:.3f}"
        )
        assert spread >= 0.025, f"game plans do not materially change outcome vs {opponent_id}: spread={spread:.3f}"
        assert best_plan in suggested, (
            f"scouting recommendation does not contain actual best plan vs {opponent_id}: "
            f"best={best_plan} suggested={suggested}"
        )

    dominant_plan = max(best_counts, key=best_counts.get)
    assert best_counts[dominant_plan] <= 2, f"game plan dominates too many representative matchups: {best_counts}"
    non_balanced_best = sum(count for plan, count in best_counts.items() if plan != "balanced")
    assert non_balanced_best == len(REPRESENTATIVES), f"balanced plan unexpectedly optimal in specialist matchup set: {best_counts}"
    assert sum(1 for count in best_counts.values() if count > 0) >= 3, f"matchup adaptation lacks variety: {best_counts}"
    print(f"gameplan-best-counts={best_counts}")
    print("gameplan-simulation: PASS")


if __name__ == "__main__":
    main()
