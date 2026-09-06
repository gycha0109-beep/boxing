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
EVENTS=json.loads((ROOT/'data/events.json').read_text())
INJURIES=json.loads((ROOT/'data/injuries.json').read_text())
CB=json.loads((ROOT/'data/career_balance.json').read_text())
TIERS=[t['id'] for t in CB['career_points']['tiers']]
TRAINABLE=['power','speed','technique','defense','conditioning']

def tier_for(points):
    for t in CB['career_points']['tiers']:
        if t['min'] <= points <= t['max']:
            return t['id']
    return 'title'

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

def choose_action(rng,s):
    b=s['boxer']; money=s['money']
    by={a['id']:a for a in CAMP}
    if b['injury'] and money>=by['rehab']['cost'] and rng.random()<.65:
        return by['rehab']
    if b['weight_kg'] > CB['weight_class']['limit_kg'] + .45 and money>=by['weight_cut']['cost']:
        return by['weight_cut']
    if (b['fatigue']>58 or b['health']<72) and money>=by['full_rest']['cost']:
        return by['full_rest']
    pool=[by['heavy_bag'],by['mitts'],by['roadwork'],by['defense_drill'],by['sparring']]
    affordable=[a for a in pool if money>=a['cost']]
    return rng.choice(affordable or [by['full_rest']])

def apply_camp(rng,s,a):
    b=s['boxer']; s['money']-=a['cost']; e=a['effects']; mods=b['modifiers']
    growth=mods.get('growth_multiplier',1.0)
    for stat in TRAINABLE:
        if stat in e:
            raw=e[stat]; gain=max(1,round(raw*growth)) if raw>0 else raw
            b[stat]=max(1,min(100,b[stat]+gain))
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
    scored=sorted(choices,key=lambda o:sum(o['stats'].values()))
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
    rng=random.Random(seed); trait=rng.choice(TRAITS)
    b={'power':50,'speed':50,'technique':50,'defense':50,'conditioning':50,'fatigue':0,'health':100,'weight_kg':CB['weight_class']['start_weight_kg'],'modifiers':dict(trait.get('modifiers',{})),'injury':{}}
    for stat,v in trait.get('stat_bonus',{}).items(): b[stat]=max(1,min(100,b[stat]+v))
    s={'boxer':b,'money':120000,'reputation':0,'wins':0,'losses':0,'draws':0,'fights':0,'points':0,'age_months':19*12,'champion':False,'injury_fights':0}
    while not ending(s):
        a=choose_action(rng,s); apply_camp(rng,s,a)
        if b['injury']: s['injury_fights']+=1
        opts=offers(s['points']); opp=choose_opp(rng,opts)
        if opp is None: break
        purse_mult=weigh_in(s)*b['modifiers'].get('purse_multiplier',1.0)
        out=fight(seed*1000+s['fights'],opp,effective_player(b)); result=out['result']
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
            if opp.get('title_fight'): s['champion']=True
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
    s['ending']=ending(s) or 'stalled'; s['trait']=trait['id']; return s

def main(n=10000):
    runs=[simulate(i+1) for i in range(n)]; end=Counter(r['ending'] for r in runs); traits=Counter(r['trait'] for r in runs)
    champ=end['world_champion']/n; avg_f=statistics.mean(r['fights'] for r in runs); avg_w=statistics.mean(r['wins'] for r in runs); avg_money=statistics.mean(r['money'] for r in runs); injury_share=statistics.mean(r['injury_fights']/max(1,r['fights']) for r in runs)
    print(f"careers={n}")
    print(f"champion_rate={champ:.3f}")
    print(f"avg_fights={avg_f:.2f} avg_wins={avg_w:.2f} avg_final_money={avg_money:.0f}")
    print(f"injury_fight_share={injury_share:.3f}")
    print("endings="+", ".join(f"{k}:{v/n:.3f}" for k,v in end.most_common()))
    print("traits="+", ".join(f"{k}:{v/n:.3f}" for k,v in traits.most_common()))
    assert .08 <= champ <= .45, champ
    assert 8 <= avg_f <= 30, avg_f
    assert end['bankrupt']/n < .08, end
    assert end['stalled'] == 0, end
    print('career-simulation: PASS')

if __name__=='__main__': main()
