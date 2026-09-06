#!/usr/bin/env python3
import json, statistics
from pathlib import Path
from sim_combat import fight

ROOT = Path(__file__).resolve().parents[1]
OPPONENTS = json.loads((ROOT / "data/opponents.json").read_text())
PLAYER = {"power":53,"speed":51,"technique":53,"defense":50,"conditioning":51,"fatigue":0,"health":100,"modifiers":{}}

def main(n=5000):
    print(f"simulations_per_opponent={n}")
    rates=[]
    for oi, opponent in enumerate(OPPONENTS):
        results=[fight(oi*10_000_000+i, opponent, PLAYER)["result"] for i in range(n)]
        wins=sum(r.startswith("WIN") for r in results)/n
        losses=sum(r.startswith("LOSS") for r in results)/n
        draws=sum(r=="DRAW" for r in results)/n
        kos=sum(r=="WIN_KO" for r in results)/n
        rates.append(wins)
        print(f"{opponent['name']:10s} {opponent['tier']:11s} {opponent['style']:10s} win={wins:.3f} loss={losses:.3f} draw={draws:.3f} playerKO={kos:.3f}")
    print(f"mean_win={statistics.mean(rates):.3f}")

if __name__ == "__main__":
    main()
