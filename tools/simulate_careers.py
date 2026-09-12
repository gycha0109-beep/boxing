#!/usr/bin/env python3
from __future__ import annotations
import json, random, statistics
from collections import Counter
from pathlib import Path
from sim_combat import fight

ROOT=Path(__file__).resolve().parents[1]
OPPS=json.loads((ROOT/'data/opponents.json').read_text())
CAMP=json.loads((ROOT/'data/camp_actions.json').read_text())
TRAITS=json.loads((ROOT/'data/traits.json').read_text())
IDENTITIES=json.loads((ROOT/'data/fighter_identities.json').read_text())
EQUIPMENT=json.loads((ROOT/'data/equipment.json').read_text())
EVENTS=json.loads((ROOT/'data/events.json').read_text())
INJURIES=json.loads((ROOT/'data/injuries.json').read_text())
CB=json.loads((ROOT/'data/career_balance.json').read_text())
TIERS=[t['id'] for t in CB['career_points']['tiers']]
TRAINABLE=['power','speed','technique','defense','conditioning']
PLAYABLE_IDENTITIES=IDENTITIES
BASE_STAT=44
TITLE_ORDER=['district','regional','national','continental','world_eliminator']
TITLE_REQUIREMENTS={
    'district':(2,2),
    'regional':(5,4),
    'national':(8,6),
    'continental':(11,8),
    'world_eliminator':(14,10),
}
WORLD_GATE=(16,12,88)


def tier_for(points):
    for t in CB['career_points']['tiers']:
        if t['min'] <= points <= t['max']:
            return t['id']
    return 'title'


def base_offers(points):
    cur=tier_for(points); idx=TIERS.index(cur); same=[]; lower=[]; higher=[]
    for o in OPPS:
        if o.get('title_fight'): continue
        oi=TIERS.index(o['tier'])
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


def next_title_kind(s):
    for kind in TITLE_ORDER:
        if kind not in s['titles']:
            return kind
    return 'world'


def eligible_title_kind(s):
    kind=next_title_kind(s)
    if kind=='world':
        fights,wins,points=WORLD_GATE
        return 'world' if 'world_eliminator' in s['titles'] and s['fights']>=fights and s['wins']>=wins and s['points']>=points else None
    fights,wins=TITLE_REQUIREMENTS[kind]
    return kind if s['fights']>=fights and s['wins']>=wins else None


def title_opponent(kind):
    return next((o for o in OPPS if o.get('title_kind')==kind),None)


def offers(s):
    out=[]
    kind=eligible_title_kind(s)
    if kind:
        title=title_opponent(kind)
        if title: out.append(title)
    for o in base_offers(s['points']):
        if o not in out: out.append(o)
        if len(out)>=3: break
    if len(out)<3:
        for o in OPPS:
            if o.get('title_fight'): continue
            if o not in out: out.append(o)
            if len(out)>=3: break
    return out


def choose_action(rng,s):
    b=s['boxer']; money=s['money']; by={a['id']:a for a in CAMP}
    if b['injury'] and money>=by['rehab']['cost'] and rng.random()<.65:
        return by['rehab']
    if b['weight_kg'] > CB['weight_class']['limit_kg'] + .45 and money>=by['weight_cut']['cost']:
        return by['weight_cut']
    if (b['fatigue']>58 or b['health']<72) and money>=by['full_rest']['cost']:
        return by['full_rest']
    pool=[by['heavy_bag'],by['mitts'],by['roadwork'],by['defense_drill'],by['sparring']]
    affordable=[a for a in pool if money>=a['cost']]
    return rng.choice(affordable or [by['full_rest']])


def choose_plan(rng, opponent):
    suggested=list(opponent.get('scouting',{}).get('suggested_plans',[]))
    if not suggested: return 'balanced'
    roll=rng.random()
    if roll < .55: return suggested[0]
    if len(suggested)>1 and roll < .90: return suggested[1]
    return 'balanced'


def unlocked(item,s):
    req=item.get('required_title','')
    return not req or req in s['titles']


def equipped_item(s,section,slot):
    item_id=s['equipment'][section].get(slot)
    if not item_id: return None
    return next((i for i in EQUIPMENT[section] if i['id']==item_id),None)


def next_upgrade(s,section,slot):
    cur=equipped_item(s,section,slot); tier=int(cur.get('tier',0)) if cur else 0
    return next((i for i in EQUIPMENT[section] if i['slot']==slot and i['tier']==tier+1),None)


def equipment_priority(identity_id,item):
    slot=item['slot']
    preferred={
        'balanced':['mouthguard','mitts','shoes','defense','gloves','heavy_bag','roadwork'],
        'pressure_fighter':['heavy_bag','roadwork','gloves','defense','mouthguard','mitts','shoes'],
        'out_boxer':['mitts','shoes','roadwork','mouthguard','defense','gloves','heavy_bag'],
        'slugger':['heavy_bag','gloves','mouthguard','defense','roadwork','mitts','shoes'],
        'counter_puncher':['defense','mitts','mouthguard','shoes','roadwork','gloves','heavy_bag'],
    }.get(identity_id,[])
    try: return preferred.index(slot)
    except ValueError: return 99


def maybe_buy_equipment(rng,s):
    current_tier=tier_for(s['points'])
    reserve=max(60000, int(CB['economy']['cycle_cost_by_tier'].get(current_tier,0)))
    candidates=[]
    for section in ('personal','gym'):
        for slot in sorted({i['slot'] for i in EQUIPMENT[section]}):
            item=next_upgrade(s,section,slot)
            if not item or not unlocked(item,s): continue
            if s['money']-item['price'] < reserve: continue
            candidates.append((equipment_priority(s['identity'],item),item['price'],section,item))
    if not candidates or rng.random()>.62: return
    candidates.sort(key=lambda x:(x[0],x[1]))
    _,_,section,item=candidates[0]
    slot=item['slot']; previous=equipped_item(s,section,slot)
    s['money']-=item['price']; s['equipment_spent']+=item['price']; s['equipment'][section][slot]=item['id']
    if section=='personal':
        old_bonus=previous.get('stat_bonus',{}) if previous else {}
        for stat in TRAINABLE:
            delta=int(item.get('stat_bonus',{}).get(stat,0))-int(old_bonus.get(stat,0))
            if delta: s['boxer'][stat]=max(1,min(100,s['boxer'][stat]+delta))


def gym_percent(s,action_id):
    best=0.0
    for slot in s['equipment']['gym']:
        item=equipped_item(s,'gym',slot)
        if item and action_id in item.get('action_ids',[]):
            best=max(best,float(item.get('training_percent',0)))
    return best


def apply_camp(rng,s,a):
    b=s['boxer']; s['money']-=a['cost']; e=a['effects']; mods=b['modifiers']
    growth=mods.get('growth_multiplier',1.0)
    for stat in TRAINABLE:
        if stat in e:
            raw=e[stat]; gain=max(1,round(raw*growth)) if raw>0 else raw
            b[stat]=max(1,min(100,b[stat]+gain))
    if a.get('kind','training')=='training':
        pct=gym_percent(s,a['id'])
        if pct>0:
            for stat in TRAINABLE:
                raw=int(e.get(stat,0))
                if raw<=0: continue
                key=f"{a['id']}:{stat}"
                fractional=s['growth_carry'].get(key,0.0)+raw*pct/100.0
                bonus=int(fractional+1e-9)
                s['growth_carry'][key]=fractional-bonus
                if bonus>0: b[stat]=max(1,min(100,b[stat]+bonus))
    fd=e.get('fatigue',0)
    if fd>0 and a['kind']=='training': fd=round(fd*mods.get('training_fatigue_multiplier',1.0))
    b['fatigue']=max(0,min(100,b['fatigue']+fd)); b['health']=max(0,min(100,b['health']+e.get('health',0))); b['weight_kg']=max(57,min(68,b['weight_kg']+e.get('weight',0)))
    if b['injury'] and 'injury_camps' in e:
        b['injury']['remaining_camps']=max(0,b['injury']['remaining_camps']+e['injury_camps'])
        if b['injury']['remaining_camps']<=0: b['injury']={}
    if a['risk']>0:
        risk=CB['injury']['base_training_chance']+a['risk']
        if b['fatigue']>=75: risk+=CB['injury']['high_fatigue_bonus']
        risk*=mods.get('injury_risk_multiplier',1.0)
        if rng.random()<risk: assign_injury(rng,b)


def assign_injury(rng,b,injury_id=None):
    inj=next((i for i in INJURIES if i['id']==injury_id),None) if injury_id else rng.choice(INJURIES)
    if not inj: return
    inj=json.loads(json.dumps(inj))
    if not b['injury'] or inj['remaining_camps']>=b['injury'].get('remaining_camps',0): b['injury']=inj


def effective_player(b):
    p={k:b[k] for k in TRAINABLE}; p.update({'fatigue':b['fatigue'],'health':b['health'],'modifiers':b['modifiers']})
    if b['injury']:
        for stat,val in b['injury'].get('penalties',{}).items(): p[stat]=max(1,min(100,p[stat]+val))
    return p


def weigh_in(s):
    b=s['boxer']; over=b['weight_kg']-CB['weight_class']['limit_kg']
    if over<=0: return 1.0
    if over<=CB['weigh_in']['soft_over_kg']:
        b['weight_kg']=CB['weight_class']['limit_kg']; b['fatigue']=min(100,b['fatigue']+CB['weigh_in']['emergency_cut_fatigue']); b['health']=max(0,b['health']-CB['weigh_in']['emergency_cut_health']); return 1.0
    s['reputation']=max(0,s['reputation']-CB['weigh_in']['miss_reputation_penalty']); mult=CB['weigh_in']['miss_purse_multiplier']
    if b['weight_kg']>=CB['weight_class']['hard_miss_kg']: mult*=.75
    return mult


def choose_opp(rng, choices):
    if not choices: return None
    titles=[o for o in choices if o.get('title_fight')]
    if titles and rng.random()<.72:
        return titles[0]
    regular=[o for o in choices if not o.get('title_fight')]
    pool=regular or choices
    scored=sorted(pool,key=lambda o:sum(o['stats'].values()))
    r=rng.random()
    if r<.58: return scored[0]
    if r<.82: return scored[min(1,len(scored)-1)]
    return scored[-1]


def apply_event(rng,s,last_result):
    if rng.random()>=CB['events']['post_fight_chance']: return
    eligible=[]
    for e in EVENTS:
        prefix=e.get('requires',{}).get('last_result_prefix','')
        if prefix and not last_result.startswith(prefix): continue
        eligible.extend([e]*max(1,int(e.get('weight',1))))
    if not eligible: return
    e=rng.choice(eligible); eff=e['effects']; b=s['boxer']
    s['money']+=eff.get('money',0); s['reputation']=max(0,s['reputation']+eff.get('reputation',0)); b['fatigue']=max(0,min(100,b['fatigue']+eff.get('fatigue',0))); b['health']=max(0,min(100,b['health']+eff.get('health',0)))
    if 'injury' in eff: assign_injury(rng,b,eff['injury'])


def ending(s):
    b=s['boxer']
    if s['champion']: return 'world_champion'
    if b['health']<=CB['retirement']['health_floor']: return 'health_retirement'
    if s['losses']>=CB['retirement']['loss_limit']: return 'loss_retirement'
    if s['money']<=CB['retirement']['debt_floor']: return 'bankrupt'
    if s['age_months']>=CB['calendar']['max_age_years']*12: return 'age_retirement'
    if s['fights']>=CB['calendar']['max_fights']: return 'fight_limit'
    return None


def simulate(seed):
    rng=random.Random(seed); trait=rng.choice(TRAITS); identity=rng.choice(PLAYABLE_IDENTITIES)
    b={stat:BASE_STAT for stat in TRAINABLE}
    b.update({'fatigue':0,'health':100,'weight_kg':CB['weight_class']['start_weight_kg'],'modifiers':dict(trait.get('modifiers',{})),'injury':{}})
    for source in (trait,identity):
        for stat,v in source.get('stat_bonus',{}).items():
            b[stat]=max(1,min(100,b[stat]+v))
    s={'boxer':b,'money':120000,'reputation':0,'wins':0,'losses':0,'draws':0,'fights':0,'points':0,'age_months':19*12,'champion':False,'injury_fights':0,'plan_counts':Counter(),'trait':trait['id'],'identity':identity['id'],'titles':[],'equipment':{'personal':{},'gym':{}},'growth_carry':{},'equipment_spent':0}
    while not ending(s):
        maybe_buy_equipment(rng,s)
        a=choose_action(rng,s); apply_camp(rng,s,a)
        if b['injury']: s['injury_fights']+=1
        opts=offers(s); opp=choose_opp(rng,opts)
        if opp is None: break
        plan_id=choose_plan(rng,opp); s['plan_counts'][plan_id]+=1
        purse_mult=weigh_in(s)*b['modifiers'].get('purse_multiplier',1.0)
        out=fight(seed*1000+s['fights'],opp,effective_player(b),plan_id); result=out['result']
        s['fights']+=1; s['age_months']+=CB['calendar']['months_per_fight']; gross=round(opp['purse']*purse_mult); s['money']+=round(gross*CB['economy']['purse_net_multiplier']); s['money']-=CB['economy']['cycle_cost_by_tier'].get(opp['tier'],0)
        ff=14; hl=1
        if result=='LOSS_KO': ff+=12; hl+=8
        elif result=='WIN_KO': ff+=5; hl+=2
        elif result.startswith('LOSS'): ff+=7; hl+=4
        hl+=round(max(0,100-out['player_hp'])/20)
        b['fatigue']=min(100,b['fatigue']+ff); b['health']=max(0,b['health']-hl); b['weight_kg']=min(68,b['weight_kg']+.35)
        rep_mult=b['modifiers'].get('reputation_multiplier',1.0)
        if result.startswith('WIN'):
            s['wins']+=1; s['reputation']+=round(opp['reputation_reward']*rep_mult); s['points']=min(100,s['points']+opp['career_points_win'])
            title_kind=opp.get('title_kind')
            if title_kind in TITLE_ORDER and title_kind not in s['titles']:
                s['titles'].append(title_kind)
            elif title_kind=='world':
                s['champion']=True
        elif result.startswith('LOSS'):
            s['losses']+=1; s['reputation']=max(0,s['reputation']-2); s['points']=max(0,s['points']-opp['career_points_loss'])
        else:
            s['draws']+=1; s['points']=min(100,s['points']+max(1,opp['career_points_win']//3))
        chance=CB['injury']['base_fight_chance']+(CB['injury']['ko_loss_bonus'] if result=='LOSS_KO' else 0)+(CB['injury']['high_fatigue_bonus'] if b['fatigue']>=75 else 0)
        chance*=b['modifiers'].get('injury_risk_multiplier',1.0)
        if rng.random()<chance: assign_injury(rng,b)
        apply_event(rng,s,result)
        rec=b['modifiers'].get('recovery_bonus',0); b['fatigue']=max(0,b['fatigue']-12-rec); b['health']=min(100,b['health']+2+rec//2)
        if b['injury']:
            b['injury']['remaining_camps']=max(0,b['injury']['remaining_camps']-1)
            if b['injury']['remaining_camps']==0: b['injury']={}
    s['ending']=ending(s) or 'stalled'; return s


def main(n=10000):
    runs=[simulate(i+1) for i in range(n)]
    end=Counter(r['ending'] for r in runs); identities=Counter(r['identity'] for r in runs); plans=Counter(); title_counts=Counter()
    for r in runs:
        plans.update(r['plan_counts']); title_counts.update(r['titles'])
    champ=end['world_champion']/n; avg_f=statistics.mean(r['fights'] for r in runs); avg_w=statistics.mean(r['wins'] for r in runs); avg_money=statistics.mean(r['money'] for r in runs); avg_spent=statistics.mean(r['equipment_spent'] for r in runs); injury_share=statistics.mean(r['injury_fights']/max(1,r['fights']) for r in runs)
    print(f"careers={n} policy=base44_title_ladder_equipment")
    print(f"champion_rate={champ:.3f}")
    print(f"avg_fights={avg_f:.2f} avg_wins={avg_w:.2f} avg_final_money={avg_money:.0f} avg_equipment_spent={avg_spent:.0f}")
    print(f"injury_fight_share={injury_share:.3f}")
    print("endings="+", ".join(f"{k}:{v/n:.3f}" for k,v in end.most_common()))
    print("titles="+", ".join(f"{k}:{v/n:.3f}" for k,v in title_counts.most_common()))
    print("identities="+", ".join(f"{k}:{v/n:.3f}" for k,v in identities.most_common()))
    total_plan_uses=max(1,sum(plans.values()))
    print("plans="+", ".join(f"{k}:{v/total_plan_uses:.3f}" for k,v in plans.most_common()))
    assert .02 <= champ <= .55, champ
    assert 10 <= avg_f <= 36, avg_f
    assert avg_spent >= 100000, avg_spent
    assert end['bankrupt']/n < .15, end
    assert end['stalled'] == 0, end
    assert set(identities) == {i['id'] for i in PLAYABLE_IDENTITIES}, identities
    assert all(plans[p] > 0 for p in ['outside_boxing','body_breakdown','pressure','counter_trap']), plans
    assert title_counts['district'] > 0 and title_counts['regional'] > 0, title_counts
    print('career-simulation: PASS')


if __name__=='__main__': main()