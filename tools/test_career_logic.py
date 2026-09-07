#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OPPS=json.loads((ROOT/'data/opponents.json').read_text())
CB=json.loads((ROOT/'data/career_balance.json').read_text())
TIERS=[t['id'] for t in CB['career_points']['tiers']]

def tier_for(points):
    for t in CB['career_points']['tiers']:
        if t['min'] <= points <= t['max']:
            return t['id']
    raise AssertionError(points)

def offers(points):
    cur=tier_for(points); idx=TIERS.index(cur); same=[]; lower=[]; higher=[]
    for o in OPPS:
        oi=TIERS.index(o['tier'])
        if o['tier']=='title' and points<88: continue
        if oi==idx: same.append(o)
        elif oi==idx-1: lower.append(o)
        elif oi==idx+1: higher.append(o)
    out=[]
    if lower: out.append(lower[0])
    for o in same:
        if len(out)<2: out.append(o)
    if higher and len(out)<3: out.append(higher[0])
    for bucket in (same,higher):
        for o in bucket:
            if len(out)>=3: break
            if o not in out: out.append(o)
    return out

def main():
    assert len({o['id'] for o in OPPS}) == len(OPPS)
    for tier in TIERS:
        assert any(o['tier']==tier for o in OPPS), tier
    for points in [0,10,20,35,40,55,60,70,75,85,88,90,100]:
        os=offers(points)
        assert 1 <= len(os) <= 3, (points,len(os))
        if points < 88:
            assert not any(o.get('title_fight') for o in os), points
    assert any(o.get('title_fight') for o in offers(90))
    econ=CB['economy']
    assert 0 < econ['purse_net_multiplier'] <= 1
    assert set(econ['cycle_cost_by_tier']) == set(TIERS)
    assert CB['retirement']['health_floor'] < 20
    assert CB['retirement']['loss_limit'] >= 10
    print('career-logic: PASS')

if __name__=='__main__': main()
