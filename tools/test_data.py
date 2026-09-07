#!/usr/bin/env python3
import json, pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]

def load(name): return json.loads((ROOT/'data'/name).read_text())

def main():
    bal=load('balance.json'); opp=load('opponents.json'); camp=load('camp_actions.json')
    traits=load('traits.json'); events=load('events.json'); injuries=load('injuries.json'); career=load('career_balance.json')
    assert set(bal['actions']) == {'jab','power','body','guard','counter'}
    assert len(opp) >= 12 and set(o['style'] for o in opp) == {'swarmer','out_boxer','slugger','counter'}
    assert len(camp) >= 8 and {'training','recovery','weight'} <= set(a['kind'] for a in camp)
    assert len(traits) >= 6 and len({t['id'] for t in traits}) == len(traits)
    assert len(events) >= 8 and len(injuries) >= 4
    tiers=[t['id'] for t in career['career_points']['tiers']]
    assert tiers == ['prospect','regional','national','continental','world','title']
    for o in opp:
        assert o['tier'] in tiers
        assert all(1 <= o['stats'][s] <= 100 for s in ['power','speed','technique','defense','conditioning'])
        assert o['purse'] > 0 and o['career_points_win'] > 0 and o['career_points_loss'] >= 0
    for a in camp:
        assert 0 <= a['risk'] <= 1 and a['cost'] >= 0
        assert 'fatigue' in a['effects'] or a['kind'] == 'weight'
    assert 59 <= career['weight_class']['limit_kg'] <= 64
    print('data-validation: PASS')

if __name__=='__main__': main()
