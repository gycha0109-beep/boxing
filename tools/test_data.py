#!/usr/bin/env python3
import json, pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]

def load(name): return json.loads((ROOT/'data'/name).read_text())

def main():
    bal=load('balance.json'); opp=load('opponents.json'); camp=load('camp_actions.json')
    traits=load('traits.json'); events=load('events.json'); injuries=load('injuries.json'); career=load('career_balance.json')
    styles=load('fighter_identities.json'); equipment=load('equipment.json')
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

    stats = ['power','speed','technique','defense','conditioning']
    assert {s['id'] for s in styles} == {'balanced','pressure_fighter','out_boxer','slugger','counter_puncher'}
    for style in styles:
        total = sum(int(style.get('stat_bonus', {}).get(stat, 0)) for stat in stats)
        assert total == 0, f"style must be zero-sum: {style['id']} total={total}"

    assert set(equipment) == {'personal','gym'}
    assert len(equipment['personal']) == 9 and len(equipment['gym']) == 12
    for section in ['personal','gym']:
        by_slot = {}
        for item in equipment[section]:
            assert item['tier'] in (1,2,3) and item['price'] > 0
            assert item['required_title'] in ('','regional','continental')
            by_slot.setdefault(item['slot'], []).append(item)
            if section == 'personal':
                assert item.get('stat_bonus')
            else:
                assert item.get('training_percent', 0) > 0 and item.get('action_ids')
        for slot, items in by_slot.items():
            assert sorted(i['tier'] for i in items) == [1,2,3], f"equipment tiers incomplete: {section}/{slot}"
            ordered = sorted(items, key=lambda i:i['tier'])
            assert ordered[0]['price'] < ordered[1]['price'] < ordered[2]['price']
    print('data-validation: PASS')

if __name__=='__main__': main()
