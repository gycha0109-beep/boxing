#!/usr/bin/env python3
from __future__ import annotations
import json, random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BAL = json.loads((ROOT / "data/balance.json").read_text())
PLANS = {p["id"]: p for p in json.loads((ROOT / "data/game_plans.json").read_text())} if (ROOT / "data/game_plans.json").exists() else {}
STYLE_WEIGHTS = {
    "swarmer": [("body",.34),("jab",.30),("power",.20),("guard",.10),("counter",.06)],
    "out_boxer": [("jab",.48),("guard",.19),("counter",.16),("body",.10),("power",.07)],
    "slugger": [("power",.48),("body",.22),("jab",.12),("guard",.10),("counter",.08)],
    "counter": [("counter",.38),("jab",.26),("guard",.16),("body",.11),("power",.09)],
}
PLAN_POLICIES = {
    "outside_boxing": [("jab",.48),("counter",.20),("guard",.17),("body",.10),("power",.05)],
    "body_breakdown": [("body",.48),("jab",.20),("guard",.14),("counter",.10),("power",.08)],
    "pressure": [("power",.38),("body",.34),("jab",.16),("guard",.07),("counter",.05)],
    "counter_trap": [("counter",.46),("jab",.28),("guard",.14),("body",.08),("power",.04)],
}
STATS = ("power", "speed", "technique", "defense", "conditioning")


def weighted(rng, items):
    x = rng.random(); acc = 0.0
    for name, w in items:
        acc += w
        if x <= acc:
            return name
    return items[-1][0]


def _opponent_weights(opponent):
    tendencies = opponent.get("tendencies", {})
    if tendencies:
        order = ("jab", "power", "body", "guard", "counter")
        return [(name, float(tendencies.get(name, 0.0))) for name in order]
    return STYLE_WEIGHTS[opponent["style"]]


def player_policy(rng, opp_style, p_sta, _o_sta, plan_id="balanced"):
    if p_sta < 28:
        return "guard"
    if plan_id in PLAN_POLICIES:
        return weighted(rng, PLAN_POLICIES[plan_id])
    if opp_style == "slugger":
        return weighted(rng, [("counter",.42),("jab",.30),("guard",.18),("body",.10)])
    if opp_style == "counter":
        return weighted(rng, [("jab",.48),("body",.24),("guard",.18),("power",.10)])
    if opp_style == "out_boxer":
        return weighted(rng, [("body",.38),("jab",.30),("power",.18),("guard",.14)])
    return weighted(rng, [("jab",.32),("body",.30),("guard",.18),("counter",.12),("power",.08)])


def _apply_global_plan(player, plan):
    out = {**player, "modifiers": dict(player.get("modifiers", {}))}
    for stat, delta in plan.get("global_stats", {}).items():
        out[stat] = max(1, min(100, int(out.get(stat, 50)) + int(delta)))
    return out


def _apply_action_plan(actor, plan, action_id, target_action, reactive_window):
    mods = plan.get("action_modifiers", {}).get(action_id, {})
    if not mods:
        return actor
    required = mods.get("requires_target_actions", [])
    if required and (not reactive_window or target_action not in required):
        return actor
    out = {**actor, "modifiers": dict(actor.get("modifiers", {}))}
    for stat in STATS:
        if stat in mods:
            out[stat] = max(1, min(100, int(out.get(stat, 50)) + int(mods[stat])))
    return out


def _hit(rng, actor, target, action_id, target_action, stamina, reactive_window):
    action = BAL["actions"][action_id]
    if action_id == "guard":
        return 0.0, action["stamina"], 0.0
    cost = action["stamina"] * (1.10 - actor["conditioning"] / 500)
    stamina = max(0.0, stamina - cost)
    acc = action["accuracy"] + (actor["technique"] - target["defense"]) * .003 + (actor["speed"] - target["speed"]) * .0015
    acc += actor.get("modifiers", {}).get("accuracy_bonus", 0.0)
    acc -= max(0.0, 45 - stamina) * BAL["fight"]["fatigue_accuracy_penalty"]
    mult = 1.0; matchups = BAL["matchups"]
    if reactive_window and action_id == "counter" and target_action == "power":
        acc += matchups["counter_vs_power"]["accuracy"]; mult *= matchups["counter_vs_power"]["damage"]
    elif reactive_window and action_id == "counter" and target_action == "body":
        acc += matchups["counter_vs_body"]["accuracy"]; mult *= matchups["counter_vs_body"]["damage"]
    elif action_id == "jab" and target_action == "counter":
        acc += matchups["jab_vs_counter"]["accuracy"]; mult *= matchups["jab_vs_counter"]["damage"]
    elif action_id == "power" and target_action == "guard":
        acc += matchups["power_vs_guard"]["accuracy"]; mult *= matchups["power_vs_guard"]["damage"]
    elif action_id == "body" and target_action == "guard":
        acc += matchups["body_vs_guard"]["accuracy"]; mult *= matchups["body_vs_guard"]["damage"]
    acc = max(.18, min(.93, acc))
    if rng.random() > acc:
        return 0.0, cost, 0.0
    dmg = action["damage"] * (.62 + actor["power"] / 100 * .72) * (.86 + actor["technique"] / 100 * .22) * mult * rng.uniform(.88, 1.12)
    dmg *= 1 - max(0, 35 - stamina) * BAL["fight"]["fatigue_damage_penalty"]
    if target_action == "guard":
        dmg *= BAL["fight"]["guard_mitigation"]
    return max(0.0, dmg), cost, action["body_stamina_damage"]


def fight(seed, opponent, player, plan_id="balanced"):
    rng = random.Random(seed)
    plan = PLANS.get(plan_id, PLANS.get("balanced", {}))
    p = _apply_global_plan(player, plan)
    p.setdefault("modifiers", {})
    o = {**opponent["stats"], "modifiers": {}}
    p_health = float(p.get("health", 100)); p_fatigue = float(p.get("fatigue", 0))
    p_hp = max(50.0, min(100.0, 75.0 + p_health * .25))
    o_hp = 100.0
    p_sta = max(42.0, min(100.0, 100.0 - p_fatigue * .55 - max(0.0, 100.0 - p_health) * .25))
    o_sta = 100.0; cards = []
    opponent_weights = _opponent_weights(opponent)
    for _rnd in range(BAL["fight"]["rounds"]):
        ps = os = 0.0
        for _ in range(BAL["fight"]["exchanges_per_round"]):
            pa = player_policy(rng, opponent["style"], p_sta, o_sta, plan_id)
            oa = weighted(rng, opponent_weights)
            order = [True, False] if p["speed"] + rng.uniform(-10,10) >= o["speed"] + rng.uniform(-10,10) else [False, True]
            for order_index, is_player in enumerate(order):
                actor, target = (p, o) if is_player else (o, p)
                act, tact = (pa, oa) if is_player else (oa, pa)
                reactive_window = order_index == 1
                effective_actor = _apply_action_plan(actor, plan, act, tact, reactive_window) if is_player else actor
                sta = p_sta if is_player else o_sta
                dmg, cost, body = _hit(rng, effective_actor, target, act, tact, sta, reactive_window)
                if act == "guard":
                    if is_player: p_sta = min(100.0, p_sta - cost); ps += BAL["actions"][act]["score"]
                    else: o_sta = min(100.0, o_sta - cost); os += BAL["actions"][act]["score"]
                    continue
                if is_player:
                    p_sta = max(0.0, p_sta - cost); o_sta = max(0.0, o_sta - body); o_hp = max(0.0, o_hp - dmg); ps += dmg * BAL["actions"][act]["score"]
                    target_hp, target_stats = o_hp, o
                else:
                    o_sta = max(0.0, o_sta - cost); p_sta = max(0.0, p_sta - body); p_hp = max(0.0, p_hp - dmg); os += dmg * BAL["actions"][act]["score"]
                    target_hp, target_stats = p_hp, p
                if target_hp <= 0:
                    return {"result":"WIN_KO" if is_player else "LOSS_KO", "player_hp":p_hp, "opponent_hp":o_hp}
                if dmg >= 10:
                    chin = (target_stats["defense"] + target_stats["conditioning"]) / 2
                    chance = BAL["fight"]["ko_base_threshold"] + max(0, dmg-10) * BAL["fight"]["ko_damage_scale"] + max(0,45-chin)*.004 + max(0,35-target_hp)*.008
                    chance *= target_stats.get("modifiers", {}).get("ko_taken_multiplier", 1.0)
                    if rng.random() < min(.72, max(0.0, chance)):
                        return {"result":"WIN_KO" if is_player else "LOSS_KO", "player_hp":p_hp, "opponent_hp":o_hp}
        cards.append((10,10) if abs(ps-os)<.75 else ((10,9) if ps>os else (9,10)))
        p_sta = min(100.0, p_sta + 9 + p["conditioning"]*.05)
        o_sta = min(100.0, o_sta + 9 + o["conditioning"]*.05)
    pt = sum(a for a,_ in cards); ot = sum(b for _,b in cards)
    result = "WIN_DEC" if pt>ot else "LOSS_DEC" if ot>pt else "DRAW"
    return {"result":result, "player_hp":p_hp, "opponent_hp":o_hp}
