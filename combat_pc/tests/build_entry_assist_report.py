"""Independent M11 acceptance auditor. Never runs physics or rewrites old evidence.

The reviewed case inventory and outcome rules are authored here, independently
of harness assertions. Large inherited suites are audited one pair at a time.
Only entry_assist_verification.json and entry_assist_verification.md are written.
"""
from __future__ import annotations
from collections import Counter
from datetime import datetime, timezone
import copy
import gc
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / 'combat_pc/tests'
RATES = (120, 60)
OLDER_SUITES = ('movement', 'combat', 'traversal', 'climb', 'wall', 'hard_landing',
                'soft_slope', 'shield', 'combo', 'held')
REVIEWED_CONTROLLER_SHA256 = '123058595238d83090cead600dc0934df527f5cd4a18c555d4da52ea971abaa1'
REVIEWED_HARNESS_SHA256 = '52417cbe52faaba4dec9fe339ed9f1d0bc73511e08fc7b73df989ac5ca9f724e'
REVIEWED_CONTRACT_SHA256 = '59d3d21f2e439d94eae17d4afd58efdfb5f83abdd224a9a448b519be28403a65'
PRESERVATION_MANIFEST_SHA256 = '943cae7a58aaf80c819d0648e5d0c009a0e1652bfe92b785d6ae4a98ebe44f7f'
PROPOSAL_SHA256 = 'ea512759333da916eef5537b92d2eb51ef69322707cdf7e3d323571f7d299b1e'
M10_ARCHIVE_SHA256 = '7a8dabe51f0b70ed21fb0bd5fa6bb9e4ec1bb500535bec32aaf25bfe01ea4ecc'
HOST_GUIDE_SHA256 = 'd2520fd662c318a96374dbba576ca6366da478c883eebdcb8694a6dd17d7ef69'
HOST_SMOKE_MANIFEST_SHA256 = 'f8f241c9ecc3069c2c4a1bd5f244904178c183c39fa2278c32800ea6dfd3abbc'

REQUIRED_GROUPS = {
 'physical': tuple(f'neutral behind target direction{d} enabled{str(b).lower()}' for d in (-1,1) for b in (False,True)) +
   tuple(f'manual windup override then target movement direction{d}' for d in (-1,1)) +
   ('target moves away and perception revoked after entry',) +
   tuple(f'airborne motion independent enabled{str(b).lower()}' for b in (False,True)),
 'gates': tuple('entry veto '+g for g in ('manual','tiny_manual','movement_locked_manual','host_turn','main_input','step_turn','input_disabled')) +
   ('denied buffered press queries only at actual admission',),
 'host': tuple('host refuses '+r for r in ('missing','ineligible','unperceived','invisible','prop','hidden','outside','occluded','removed')) +
   tuple(f'closed preview outer boundary direction{d}' for d in (-1,1)) +
   ('aim eligibility independent from target damage receiver',),
 'offers': tuple('actor rejects offer '+r for r in ('token','sample_tick','actor_id','attack_serial','candidate_id','typed_attestation','missing_perceived','classification','nonfinite_anchor','stale_anchor','moved_anchor','outside','queued_free','removed','terrain','hidden','prop_group','malformed','no_offer')) +
   ('equal X current anchor keeps facing',),
 'provenance': tuple('first fresh provenance '+r for r in ('custom_start','loop_to_zero','retained_next','repeat','charge','new_episode')),
 'lifecycle': tuple('provider callback '+m for m in ('reset','forced','replace_provider','turn_gate','ability','position','recursive_tick','pause','configuration_roundtrip','provider_roundtrip')) +
   ('decision callback reset retires old attack','old host detach cannot revoke replacement','same actor resets and toggles host without stale queries'),
 'native': tuple('parsed input entry '+r for r in ('neutral','manual','paused_tap')),
}
REQUIRED_CASES = tuple(n for group in REQUIRED_GROUPS.values() for n in group)
DIAGNOSTIC_FIELDS = {'entry_assist_query_count','entry_assist_token','entry_assist_attack_serial',
 'entry_assist_reason','entry_assist_manual_x','entry_assist_facing_before','entry_assist_facing_after'}
DECISION_FIELDS = {'token','attack_serial','query_count','request_kind','reason','manual_x',
 'facing_before','facing_after','facing','position'}  # Last two are generic actor event fields.
HOST_FIELDS = {'classification','eligible','enabled','offered_count','perceived','query_count','reason','rejected_count','visible'}
REQUEST_FIELDS = {'token','sample_tick','engine_tick','actor_id','attack_serial','input_id','request_id',
 'request_kind','hold_id','preview_left','preview_right','origin_left','origin_right','terrain_mask'}
OFFER_REASONS = {'token':'stale_offer','sample_tick':'stale_offer','actor_id':'stale_offer','attack_serial':'stale_offer',
 'candidate_id':'invalid_candidate','typed_attestation':'attestation_denied','missing_perceived':'attestation_denied',
 'classification':'not_opponent','nonfinite_anchor':'invalid_anchor','stale_anchor':'stale_anchor','moved_anchor':'stale_anchor',
 'outside':'outside_preview','queued_free':'invalid_candidate','removed':'invalid_candidate','terrain':'terrain_occluded',
 'hidden':'hidden_candidate','prop_group':'prop_candidate','malformed':'malformed_offer','no_offer':'no_offer'}

def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

m10 = load_module('preserved_m10_entry_audit', TESTS/'build_held_report.py')
VerificationError=m10.VerificationError
require=m10.require; sha=m10.sha; pin=m10.pin; read=m10.read; close=m10.close
number=m10.number; display=m10.display; project_path=m10.project_path; resource_path=m10.resource_path
PINNED=m10.PINNED

def events(s, label): return [e for e in s['events'] if e['event']==label]
def starts(s): return events(s,'attack_started')
def final(s): return s['frames'][-1]['after']
def frame_for(s, row):
    tick=row['tick']
    require(type(tick) is int and 1<=tick<=len(s['frames']),f'Observation outside callback: {s["name"]}')
    frame=s['frames'][tick-1]
    if 'engine_tick' in row: require(row['engine_tick']==frame['engine_tick'],f'Wrong engine callback: {s["name"]}')
    return frame

def verify_preservation():
    pin(TESTS/'entry_assist_preserved_evidence.json',PRESERVATION_MANIFEST_SHA256)
    p=read(TESTS/'entry_assist_preserved_evidence.json')
    require(p['milestone']==11 and len(p['files'])==707 and len(p['snapshots'])==10,'Wrong preserved inventory')
    require(p['current_mismatches_at_capture']==[],'Preservation captured exceptions')
    require(p['baseline_snapshot_sha256']==M10_ARCHIVE_SHA256,'Wrong M10 archive pin')
    for name,digest in p['files'].items(): pin(project_path(name),digest)
    for name,digest in p['snapshots'].items():
        path=(ROOT/name).resolve()
        require(path.parent==ROOT.parent/'moksha-backups' and path.suffix=='.zip','Invalid snapshot location')
        pin(path,digest)
    return p

def verify_redirects():
    rows=read(TESTS/'entry_assist_compatibility_redirects.json')
    require(set(rows)==set(OLDER_SUITES),'Incomplete M11 compatibility redirects')
    for suite,row in rows.items():
        path=project_path(row['original_harness']);pin(path,row['original_sha256'])
        content=path.read_text();require(content.count(row['old_output'])==1,f'Ambiguous redirect: {suite}')
        suffix='%dhz%s.json' if suite=='movement' else '%dhz.json'
        output=f'res://combat_pc/tests/{suite}_compat_m11_results_{suffix}'
        require(row['new_output']==output,f'Unexpected output destination: {suite}')
        require(hashlib.sha256(content.replace(row['old_output'],output,1).encode()).hexdigest()==row['redirected_sha256'],f'Historical logic changed: {suite}')
        if 'redirected_harness' in row:pin(project_path(row['redirected_harness']),row['redirected_sha256'])
    return rows

def verify_run(run,suite,hz,m7):
    ctx=f'{suite}/{hz}'
    require(type(run['physics_hz']) is int and run['physics_hz']==hz,f'Wrong physics rate: {ctx}')
    milestone={'entry_assist':11,'held':10,'combo':9,'shield':8,'soft_slope':7}.get(suite)
    if milestone:require(run['milestone']==milestone and run['selected_group']=='',f'Filtered/wrong milestone: {ctx}')
    require(run['failures']==[] and run['production_hash_stable_during_run'] is True,f'Failed/unstable run: {ctx}')
    a,b=run['starting_hashes'],run['hashes']
    require(a and b and all(b.get(k)==v for k,v in a.items()),f'Run source drift: {ctx}')
    if suite not in ('movement','combat'):require(a==b,f'Incomplete start inventory: {ctx}')
    for name,digest in b.items():pin(resource_path(name),digest)
    require(b['res://combat_pc/player.gd']==REVIEWED_CONTROLLER_SHA256,f'Wrong actor: {ctx}')
    required={'res://combat_pc/player.gd','res://combat_pc/player.tscn','res://combat_pc/resources/movement_profile.gd','res://combat_pc/resources/movement_profile.tres'}
    if suite=='entry_assist':
        required|={'res://project.godot',*(f'res://combat_pc/{p}' for p in (
          'tests/entry_assist_regression.gd','tests/held_regression.gd','tests/combo_regression.gd','tests/shield_regression.gd',
          'components/attack_entry_facing_host.gd','components/attack_entry_facing_host.tscn','components/contact_adapter.gd',
          'fixtures/contact_target.gd','fixtures/contact_target.tscn','resources/melee_chain.gd','resources/melee_step.gd',
          'resources/light_chain.tres','resources/melee_input_profile.gd','resources/held_repeat.tres','resources/held_charge.tres'))}
    require(required<=b.keys(),f'Missing source inputs: {ctx}: {required-b.keys()}')
    ss=run['scenarios'];require(ss and len({s['name'] for s in ss})==len(ss),f'Empty/duplicate scenarios: {ctx}')
    total=0;continuity={}
    for s in ss:
        require(type(s['checks']) is int and s['checks']==len(s['assertions'])>0 and s['failures']==0,f'Invalid assertion inventory: {ctx}/{s["name"]}')
        require(all(a['passed'] is True and a['label'] for a in s['assertions']),f'Failed assertion: {ctx}/{s["name"]}')
        total+=s['checks'];continuity[s['name']]=m7.verify_continuity(s,'soft_slope' if milestone else suite,hz)
    require(total==run['checks'],f'Run assertion total mismatch: {ctx}')
    log=TESTS/f'm11_{suite}_{hz}.log';pin(log);content=log.read_text()
    require(not re.search(r'SCRIPT ERROR|ERROR:|FAIL:|WARNING:',content),f'Engine diagnostic: {log}')
    summary=re.findall(r'MOKSHA [^\n]*?(\d+)Hz: (\d+) scenarios, (\d+) checks, (\d+) failures',content)
    require(len(summary)==1 and tuple(map(int,summary[0]))==(hz,len(ss),total,0),f'Incomplete/repeated completion log: {log}')
    return continuity, {display(log):PINNED[log.resolve()]}

def verify_diagnostics(s):
    name=s['name'];previous_count=previous_token=0
    for f in s['frames']:
        for side in ('before','after'):
            d=f[side]
            require({k for k in d if k.startswith('entry_assist_')}==DIAGNOSTIC_FIELDS,f'Diagnostic schema/target leakage: {name}')
            require(not {'candidate','candidate_id','anchor_world','local_anchor','aim_target','aim_target_id','target_id','target_position'}&d.keys(),f'Target offer retained in actor telemetry: {name}')
            for field in ('entry_assist_query_count','entry_assist_token','entry_assist_attack_serial'):
                require(type(d[field]) is int and d[field]>=0,f'Invalid diagnostic identity: {name}/{field}')
            count,token=d['entry_assist_query_count'],d['entry_assist_token']
            require(previous_count<=count<=previous_count+1 and previous_token<=token<=previous_token+1 and token==count,f'Recycled/multiple query identity: {name}')
            previous_count,previous_token=count,token
            require(d['entry_assist_facing_before'] in (-1,1) and d['entry_assist_facing_after'] in (-1,1),f'Invalid facing diagnostic: {name}')
            number(d['entry_assist_manual_x'],name)
    for e in events(s,'entry_assist_resolved'):
        d=e['data'];frame_for(s,e)
        require(set(d)==DECISION_FIELDS,f'Decision event schema/target leakage: {name}')
        require(d['request_kind'] in ('fresh','held_repeat','charge_commit'),f'Invalid decision request kind: {name}')
        require(d['token']==d['query_count'] and d['query_count']<=previous_count,f'Decision query mismatch: {name}')
        if d['reason'] in ('applied','already_facing','equal_x'):
            require(d['manual_x']==0 and d['request_kind']=='fresh',f'Assistance overrode nonneutral/derived intent: {name}')
        if d['reason']=='applied':require(d['facing_after']==-d['facing_before'],f'Applied decision did not turn: {name}')
        else:require(d['facing_after']==d['facing_before'],f'Rejected decision changed facing: {name}')
    require(set(s['host_diagnostics'])<=HOST_FIELDS,f'Host diagnostic target leakage: {name}')
    return {'observed_queries':previous_count,'decision_events':len(events(s,'entry_assist_resolved'))}

def vector(value,context):
    require(isinstance(value,list) and len(value)==2,f'Invalid vector: {context}')
    return [number(v,context) for v in value]

def contains(box,point):
    return all(box['position'][k]<=point[k]<=box['position'][k]+box['size'][k] for k in (0,1))

def verify_queries(s,baseline):
    """Validate fixture observations against admission and the authored contract.

    The transparent host recorder invokes the production host. Returned offers
    are test evidence, not actor diagnostics or damage authorization.
    """
    name=s['name'];rows=s['provider_queries'];variant=name.removeprefix('actor rejects offer ') if name.startswith('actor rejects offer ') else ''
    mutation=name.startswith('provider callback ')
    require(len(rows)==final(s)['entry_assist_query_count'],f'Missing/unrecorded provider query: {name}')
    route=s['params']['provider_route']
    expected_route='adversarial_direct_provider' if variant or mutation or name=='equal X current anchor keeps facing' else 'production_host'
    require(route==expected_route,f'Provider route conflated: {name}')
    proof=[]
    for index,row in enumerate(rows):
        f=frame_for(s,row);r=row['request'];before=row['before'];after=row['actor_after_provider'];offer=row['returned_offer'];candidate=row['candidate_after_provider']
        require(set(row)=={'tick','engine_tick','request','before','returned_offer','candidate_after_provider','actor_after_provider'},f'Query observation schema changed: {name}')
        require(set(r)==REQUEST_FIELDS,f'Request schema changed: {name}')
        for key in ('token','sample_tick','engine_tick','actor_id','attack_serial','input_id','request_id','hold_id','terrain_mask'):
            require(type(r[key]) is int and r[key]>=(0 if key=='hold_id' else 1),f'Invalid request identity: {name}/{key}')
        require(r['token']==index+1 and r['sample_tick']==row['tick'] and r['engine_tick']==f['engine_tick'],f'Stale/nonconsecutive request callback: {name}')
        require(before['entry_assist_token']==r['token']==before['entry_assist_query_count'] and before['entry_assist_attack_serial']==r['attack_serial'],f'Request/diagnostic identity mismatch: {name}')
        for request_key,state_key in (('attack_serial','attack_serial'),('input_id','attack_consumed_input_id'),('request_id','attack_request_id'),('hold_id','attack_origin_hold_id'),('request_kind','attack_request_kind')):
            require(r[request_key]==before[state_key],f'Request changed admitted {request_key}: {name}')
        require(r['request_kind']=='fresh' and before['attack_initial_fresh_admission'] is True and before['weapon_phase']=='windup' and before['weapon_elapsed']==0 and before['attack_step_elapsed']==0,f'Provider queried outside initial fresh windup admission: {name}')
        require(before['move_x']==0 and before['entry_assist_manual_x']==0 and before['allow_input'] is True,f'Provider queried despite manual/disabled input: {name}')
        require(f['before']['hitpause_remaining']<=0,f'Provider queried on paused callback: {name}')
        shape=m10.definition(s,{'data':{'charge_role':before['charge_role'],'step_index':before['attack_step_index']}},baseline)
        require(shape['allow_turn_windup'] is True,f'Provider queried through a step turn denial: {name}')
        size=vector(shape['strike_size'],name);offset=vector(shape['strike_center_offset'],name);origin=vector(shape['strike_origin_offset'],name)
        position=vector(before['world_position'],name);height=number(before['body_height'],name)
        offset[1]=max(offset[1],-height+size[1]*.5);origin[1]=max(origin[1],-height+3)
        for side,direction in (('left',-1),('right',1)):
            box=r['preview_'+side]
            require(set(box)=={'position','size'} and box['size']==size,f'Preview size differs from admitted starter: {name}')
            expected=[position[0]+direction*offset[0]-size[0]*.5,position[1]+offset[1]-size[1]*.5]
            for k in (0,1):close(box['position'][k],expected[k],1e-5,f'Current mirrored preview: {name}/{side}/{k}')
            expected_origin=[position[0]+direction*origin[0],position[1]+origin[1]]
            for k in (0,1):close(r['origin_'+side][k],expected_origin[k],1e-5,f'Current ray origin: {name}/{side}/{k}')
        require(r['terrain_mask']==1,f'Fixture terrain-mask specification changed: {name}')
        if not mutation:require(before==after,f'Read-only provider changed actor state: {name}')
        if variant=='malformed':require(offer=='invalid',f'Malformed-offer fixture missing: {name}')
        elif not offer:
            require(offer=={} and (name.startswith('host refuses ') or variant=='no_offer'),f'Unexpected absent offer: {name}')
            require(candidate=={'valid':False,'inside_tree':False,'queued_for_deletion':False},f'No-offer fixture retained a candidate: {name}')
        else:
            require(isinstance(offer,dict),f'Unexpected offer type: {name}')
            keys={'token','sample_tick','actor_id','attack_serial','candidate','candidate_id','local_anchor','anchor_world','classification','eligible','perceived','visible'}
            require(set(offer)==(keys-{'perceived'} if variant=='missing_perceived' else keys),f'Offer schema differs: {name}')
            for key in ('token','sample_tick','actor_id','attack_serial'):
                require(type(offer[key]) is int and offer[key]==r[key]+int(variant==key),f'Echo does not reproduce specific request fixture: {name}/{key}')
            require(candidate['valid'] is True and type(candidate['id']) is int and candidate['id']>0,f'No live candidate identity evidence: {name}')
            require(offer['candidate']['object_id']==candidate['id'] and offer['candidate_id']==candidate['id']+int(variant=='candidate_id') and offer['candidate']['object_id']!=r['actor_id'],f'Candidate handle/identity mismatch: {name}')
            require(candidate['inside_tree'] is (variant!='removed') and candidate['queued_for_deletion'] is (variant=='queued_free'),f'Candidate lifecycle observation differs: {name}')
            require(candidate['visible'] is (variant not in ('hidden','removed')) and candidate['is_prop'] is (variant=='prop_group'),f'Candidate visual/classification contradiction differs: {name}')
            require(offer['classification']==('prop' if variant=='classification' else 'opponent'),f'Wrong classification fixture: {name}')
            for key in ('eligible','perceived','visible'):
                if variant=='missing_perceived' and key=='perceived':continue
                if variant=='typed_attestation' and key=='visible':require(type(offer[key]) is int and offer[key]==1,f'Typed-attestation fixture missing: {name}')
                else:require(offer[key] is True,f'Attestation is not explicitly true: {name}/{key}')
            anchor=vector(offer['anchor_world'],name)
            if variant=='nonfinite_anchor':require(offer['local_anchor']=={'rejected_nonfinite_vector':True} and 'current_anchor' not in candidate,f'Explicit rejected nonfinite input fixture missing: {name}')
            else:
                local=vector(offer['local_anchor'],name);current=vector(candidate['current_anchor'],name);target=vector(candidate['position'],name)
                for k in (0,1):close(current[k],target[k]+local[k],1e-8,f'Independent current fixture anchor: {name}/{k}')
                if variant=='stale_anchor':close(anchor[0]-current[0],.0001,1e-5,f'Outdated reported anchor: {name}')
                elif variant=='moved_anchor':close(current[0]-anchor[0],1,1e-8,f'Target movement invalidates offered anchor: {name}')
                else:require(anchor==current,f'Offer does not report current anchor: {name}')
            inside=contains(r['preview_left'],anchor) or contains(r['preview_right'],anchor)
            require(inside is (variant!='outside'),f'Closed preview membership differs: {name}')
            if name.startswith('closed preview outer boundary '):
                direction=int(name.rsplit('direction',1)[1]);box=r['preview_left' if direction<0 else 'preview_right']
                close(anchor[0],box['position'][0]+(box['size'][0] if direction>0 else 0),1e-8,f'Exact mirrored outer boundary: {name}')
            if name=='equal X current anchor keeps facing':require(anchor[0]==position[0],f'Equal-X fixture is not equal: {name}')
            if variant=='terrain':
                ray=r['origin_left'];t=(84-ray[0])/(anchor[0]-ray[0]);y=ray[1]+t*(anchor[1]-ray[1])
                require(0<t<1 and 145<y<205,f'Terrain rejection fixture ray misses independently known blocking rectangle: {name}')
            if not mutation and not variant:
                decision=[e for e in events(s,'entry_assist_resolved') if e['tick']==row['tick'] and e['data']['token']==r['token']]
                require(len(decision)==1,f'Accepted host query lacks one decision: {name}')
                expected=before['facing'] if anchor[0]==position[0] else (1 if anchor[0]>position[0] else -1)
                require(decision[0]['data']['facing_after']==expected,f'Suggestion disagrees with validated current anchor: {name}')
        proof.append({'tick':row['tick'],'token':r['token'],'attack_serial':r['attack_serial'],'route':route,'returned_offer':bool(offer),'admission_and_offer_audited':True})
    if route=='production_host' and name!='old host detach cannot revoke replacement':
        host=s['host_diagnostics'];offered=sum(bool(r['returned_offer']) for r in rows)
        require(host['query_count']==len(rows) and host['offered_count']==offered and host['rejected_count']==len(rows)-offered,f'Host/query record count mismatch: {name}')
    if name.startswith('host refuses '):
        why={'missing':'not_opposing_combat_target','ineligible':'ineligible','unperceived':'unperceived','invisible':'visibility_not_attested','prop':'not_opposing_combat_target','hidden':'hidden','outside':'outside_preview','occluded':'occluded','removed':'candidate_unavailable'}[name.removeprefix('host refuses ')]
        require(s['host_diagnostics']['reason']==why,f'Host refusal reason differs from authored fixture: {name}')
    return proof

def verify_contacts(s,hz,baseline):
    """M10's physical-route auditor, plus explicit handling of pre-start retirement.

    A query can be cancelled synchronously before attack_started. Such a retired
    admission cannot sample/contact; its cancellation is checked separately and
    is not fabricated into a committed strike or a physical contact.
    """
    known={e['data']['serial'] for e in starts(s)}
    unstarted=[e for e in s['events'] if e['event']=='attack_cancelled' and e['data']['serial'] not in known]
    if unstarted:
        require(s['name'] in ('provider callback reset','provider callback forced','provider callback configuration_roundtrip','decision callback reset retires old attack'),f'Unreviewed pre-start retirement: {s["name"]}')
        require(not s['strike_samples'] and not s['physical_contact_receipts'] and not s['physical_target_receipts'],f'Retired entry produced physical contact: {s["name"]}')
    proxy=dict(s);proxy['events']=[e for e in s['events'] if e not in unstarted]
    result=m10.verify_contacts(proxy,hz,baseline)
    result['retired_before_attack_started']=len(unstarted)
    for sample in s['strike_samples']:
        require(not any(k.startswith('entry_assist_') or k in ('candidate','candidate_id','anchor_world','local_anchor') for k in sample['snapshot']),f'Target offer leaked into strike payload: {s["name"]}')
    hits=s['actual_target_hits']
    require(type(hits) is int and hits>=-1,f'Invalid target effect count: {s["name"]}')
    if hits>=0 and s['name']!='same actor resets and toggles host without stale queries':
        require(hits==len(s['physical_target_receipts']),f'Receiver effect/count mismatch: {s["name"]}')
    return result

def verify_case(s,hz,baseline):
    name=s['name'];d=final(s);q=d['entry_assist_query_count'];reasons=[e['data']['reason'] for e in events(s,'entry_assist_resolved')]
    attacks=starts(s);rules=[]
    def outcome(condition,label):require(condition,f'{name}/{hz}: {label}');rules.append(label)
    if name.startswith('neutral behind target '):
        enabled=s['params']['assist_enabled'];direction=s['params']['initial_facing']
        outcome(q==int(enabled) and d['facing']==(-direction if enabled else direction),'Optional neutral entry faces the approved side once')
        outcome(s['actual_target_hits']==int(enabled) and len(s['physical_contact_receipts'])==int(enabled),'Hit/whiff is established by ordinary receiver and adapter contact')
        outcome(reasons==(['applied'] if enabled else []),'Default-off emits no decision or provider query')
        origin=s['frames'][0]['after']['position']
        outcome(all(abs(f['after']['position'][k]-origin[k])<.001 for f in s['frames'] for k in (0,1)),'Stationary authored strike has no translation')
    elif name.startswith('manual windup override '):
        direction=int(name.rsplit('direction',1)[1])
        outcome(q==1 and d['attack_facing']==direction and s['actual_target_hits']==1,'Later permitted windup input wins; moving target hits only the latched active direction')
        active=[e for e in events(s,'attack_phase_changed') if e['data']['phase']=='active']
        outcome(len(active)==1 and active[0]['data']['facing']==direction,'Final contact direction is committed at ordinary active entry')
    elif name=='target moves away and perception revoked after entry':
        outcome(q==1 and d['facing']==-1 and s['actual_target_hits']==0 and not s['physical_contact_receipts'],'Entry offer creates no tracking or later hit authority')
    elif name.startswith('airborne motion independent '):
        enabled=s['params']['assist_enabled'];a=s['measurements']['air_initial'];b=s['measurements']['air_final']
        outcome(q==int(enabled) and d['facing']==(-1 if enabled else 1),'Airborne neutral drift does not veto an entry-facing decision')
        outcome(b['velocity'][1]>a['velocity'][1] and b['fall_distance']>a['fall_distance'],'Ordinary airborne gravity and fall history continue')
        outcome(b['air_jumps_left']==0 and b['air_roll_available'] is False and b['dive_available'] is False,'Facing assistance grants no airborne budget')
    elif name.startswith('entry veto '):
        gate=name.removeprefix('entry veto ')
        outcome(q==0 and d['facing']==1 and s['host_diagnostics']['query_count']==0,'Manual intent or closed effective gate prevents querying')
        if gate in ('manual','tiny_manual','movement_locked_manual'):outcome(reasons==['manual_input'] and d['entry_assist_manual_x']>0,'Every nonzero normalized input vetoes assistance')
        elif gate in ('input_disabled','main_input'):outcome(not attacks and not reasons,'Disabled inputs never admit an attack')
        else:outcome(reasons==['turn_denied'],'A denied turn capability is retained at actual entry')
    elif name=='denied buffered press queries only at actual admission':
        outcome(q==1 and len(attacks)==1 and s['actual_target_hits']==1,'Buffered input queries only after ordinary attack admission')
        start=attacks[0]['tick'];outcome(all(f['after']['entry_assist_query_count']==0 for f in s['frames'][:start-1]),'Rejected/queued callbacks carry no earlier query')
    elif name.startswith('host refuses '):
        outcome(q==1 and d['facing']==1 and s['host_diagnostics']['offered_count']==0 and reasons==['no_offer'],'Production host withholds unapproved or unavailable candidate')
        outcome(not s['physical_contact_receipts'],'Refused host offer cannot fabricate a hit')
    elif name.startswith('closed preview outer boundary '):
        direction=int(name.rsplit('direction',1)[1]);outcome(q==1 and d['facing']==direction and s['host_diagnostics']['offered_count']==1,'Both mirrored closed preview edges admit the authored anchor')
    elif name=='aim eligibility independent from target damage receiver':
        outcome(q==1 and d['facing']==-1 and not s['physical_contact_receipts'] and not s['physical_target_receipts'],'Aim eligibility grants no receiver or damage authority')
    elif name.startswith('actor rejects offer '):
        variant=name.removeprefix('actor rejects offer ')
        outcome(q==1 and d['facing']==1 and reasons==[OFFER_REASONS[variant]] and len(attacks)==1,'Actor independently rejects the precise malformed/stale/obstructed offer')
    elif name=='equal X current anchor keeps facing':
        outcome(q==1 and d['facing']==1 and reasons==['equal_x'],'Equal horizontal anchor preserves current facing')
    elif name.startswith('first fresh provenance '):
        route=name.removeprefix('first fresh provenance ');expected=2 if route=='new_episode' else 1
        outcome(q==expected and len(attacks)>=2,'Only genuine initial fresh admissions query')
        expected_steps={'custom_start':[1,2],'loop_to_zero':[0,1,0],'retained_next':[0,1],'repeat':[0,1,2,0],'charge':[0,1],'new_episode':[0,0]}[route]
        outcome([e['data']['step_index'] for e in attacks]==expected_steps,'Connected successor admissions exercise the exact provenance path')
        initial=[frame_for(s,e)['after']['attack_initial_fresh_admission'] for e in attacks]
        outcome(initial==([True,True] if route=='new_episode' else [True]+[False]*(len(attacks)-1)),'Initial fresh provenance is separate from numerical step index')
        outcome(reasons==(['applied','already_facing'] if route=='new_episode' else ['applied']+['not_initial_fresh']*(len(attacks)-1)),'Continuation/derived entries do not request another target')
    elif name.startswith('provider callback '):
        mutation=name.removeprefix('provider callback ')
        outcome(q==1 and d['facing']==1 and not reasons and len(s['provider_queries'])==1,'Mutation/reentry discards without nested query, retry or stale decision event')
        outcome(d['entry_assist_reason']==('provider_reentered' if mutation=='recursive_tick' else 'provider_mutated'),'Invalidation reason identifies provider authority change')
        outcome(not s['physical_contact_receipts'],'Discarded callback has no fabricated target contact')
        if mutation in ('reset','forced','configuration_roundtrip'):outcome(not attacks,'Retired pre-start admission cannot emit attack_started')
        if mutation=='forced':outcome(d['main_action']=='forced','New forced owner survives callback return')
    elif name=='decision callback reset retires old attack':
        outcome(q==1 and not attacks and d['weapon_phase']=='idle' and not s['physical_contact_receipts'],'Decision observer reset suppresses all stale attack/contact continuation')
    elif name=='old host detach cannot revoke replacement':
        outcome(q==1 and len(attacks)==2 and s['host_diagnostics']['query_count']==0 and d['facing']==1 and reasons==['applied','no_provider'],'Exact provider ownership survives old-host toggle and becomes manual on owning-host detach')
    elif name=='same actor resets and toggles host without stale queries':
        outcome(q==2 and len(attacks)==4 and reasons==['applied','applied'],'Actor-local query identity persists through reset and disabled cycles')
        receipt_serials=[r['serial'] for r in s['physical_contact_receipts']]
        outcome(receipt_serials==[attacks[0]['data']['serial'],attacks[2]['data']['serial']] and s['actual_target_hits']==0,'Only enabled reset cycles apply actual hits; final per-cycle receiver counter remains zero')
    elif name.startswith('parsed input entry '):
        route=name.removeprefix('parsed input entry ')
        outcome(q==(0 if route=='manual' else 1) and len(attacks)==1,'Actual parsed key press obeys entry admission and manual priority')
        edges=s['parsed_input_edges'];outcome(any(e['physical_keycode']==74 and e['pressed'] is True for e in edges) and any(e['physical_keycode']==74 and e['pressed'] is False for e in edges),'Native input evidence contains the physical attack press and release')
        if route=='paused_tap':outcome(frame_for(s,attacks[0])['before']['hitpause_remaining']<=0,'Paused tap waits for an unpaused admission callback')
    require(rules,f'No independent outcome oracle: {name}')
    return rules

def verify_motion_pairs(run):
    index={s['name']:s for s in run['scenarios']};proof=[]
    a=index['airborne motion independent enabledfalse'];b=index['airborne motion independent enabledtrue']
    require(len(a['frames'])==len(b['frames']),'Air off/on callback inventories differ')
    fields=('position','velocity','air_jumps_left','air_roll_available','dive_available','fall_distance','fall_history_active','grounded','body_height')
    for fa,fb in zip(a['frames'],b['frames']):
        require(fa['tick']==fb['tick'] and fa['delta']==fb['delta'],'Air off/on callback mismatch')
        for side in ('before','after'):
            for field in fields:require(fa[side][field]==fb[side][field],f'Air off/on changed {side}.{field} at {fa["tick"]}')
    proof.append({'physics_hz':run['physics_hz'],'comparison':'airborne off/on','callbacks':len(a['frames']),'fields':list(fields),'exact_match':True})
    for direction in (-1,1):
        pair=[index[f'neutral behind target direction{direction} enabled{enabled}'] for enabled in ('false','true')]
        for s in pair:
            origin=s['frames'][0]['after']['position']
            require(all(f['after']['position']==origin and f['after']['velocity']==[0,0] for f in s['frames']),'Stationary off/on changed ordinary position/velocity')
        require(final(pair[0])['position']==final(pair[1])['position'],'Stationary off/on final position differs')
        proof.append({'physics_hz':run['physics_hz'],'comparison':f'stationary off/on direction{direction}','exact_position_velocity_match':True,'contact_populations_differ_by_design':True})
    return proof

def verify_entry_pair(pair,baseline):
    result={'contacts':{},'oracles':{},'queries':{},'query_observations':{},'motion':[]}
    for hz,run in pair.items():
        require(tuple(s['name'] for s in run['scenarios'])==REQUIRED_CASES,f'Independent exact M11 case inventory/order differs at {hz}')
        require(run['checks']==163,f'Reviewed final M11 assertion inventory changed: {hz}')
        result['contacts'][str(hz)]={};result['oracles'][str(hz)]={};result['queries'][str(hz)]={};result['query_observations'][str(hz)]={}
        for s in run['scenarios']:
            result['queries'][str(hz)][s['name']]=verify_diagnostics(s)
            result['query_observations'][str(hz)][s['name']]=verify_queries(s,baseline)
            result['contacts'][str(hz)][s['name']]=verify_contacts(s,hz,baseline)
            result['oracles'][str(hz)][s['name']]=verify_case(s,hz,baseline)
        result['motion']+=verify_motion_pairs(run)
    signature=lambda s:(s['name'],s['params'],s['checks'],[a['label'] for a in s['assertions']],s['melee_chain'],s['input_profile_at_start'],s['input_profile_at_finish'],s['shield_profile'])
    require([signature(s) for s in pair[120]['scenarios']]==[signature(s) for s in pair[60]['scenarios']],'M11 paired fixture/profile/assertion specifications differ')
    for name in REQUIRED_CASES:
        for key in ('observed_queries','decision_events'):require(result['queries']['120'][name][key]==result['queries']['60'][name][key],f'Rate-dependent entry query semantics: {name}/{key}')
        for key in ('passive_target_applications','passive_target_acknowledgements'):require(result['contacts']['120'][name][key]==result['contacts']['60'][name][key],f'Rate-dependent physical contact population: {name}/{key}')
    return result

def negative_probes(primary,baseline):
    index={s['name']:s for s in primary['scenarios']};proof=[]
    def probe(label,name,mutation,validator):
        candidate=copy.deepcopy(index[name]);mutation(candidate)
        try:validator(candidate)
        except VerificationError as error:proof.append({'probe':label,'observed':'rejected','reason':str(error),'retained_files_modified':False})
        else:raise VerificationError('Corrupted claim incorrectly accepted: '+label)
    enabled='neutral behind target direction1 enabledtrue'
    probe('target identity leaked into decision event',enabled,lambda s:events(s,'entry_assist_resolved')[0]['data'].update(candidate_id=123),verify_diagnostics)
    probe('nonzero manual input accepted',enabled,lambda s:events(s,'entry_assist_resolved')[0]['data'].update(manual_x=.00001),verify_diagnostics)
    probe('provider query identity reused',enabled,lambda s:s['frames'][-1]['after'].update(entry_assist_token=0),verify_diagnostics)
    probe('acknowledged hit lacks target application',enabled,lambda s:s['physical_target_receipts'].clear(),lambda s:verify_contacts(s,120,baseline))
    probe('false optional hit claim',enabled,lambda s:s.update(actual_target_hits=0),lambda s:verify_case(s,120,baseline))
    probe('derived repeat becomes initial fresh','first fresh provenance repeat',lambda s:frame_for(s,starts(s)[-1])['after'].update(attack_initial_fresh_admission=True),lambda s:verify_case(s,120,baseline))
    probe('wrong stale-echo rejection accepted','actor rejects offer token',lambda s:events(s,'entry_assist_resolved')[0]['data'].update(reason='applied'),lambda s:verify_case(s,120,baseline))
    probe('provider mutation emits stale owner event','provider callback reset',lambda s:s['events'].append({'tick':5,'event':'entry_assist_resolved','data':{'reason':'applied'}}),lambda s:verify_case(s,120,baseline))
    probe('offer echo changed',enabled,lambda s:s['provider_queries'][0]['returned_offer'].update(token=999),lambda s:verify_queries(s,baseline))
    probe('live candidate identity changed',enabled,lambda s:s['provider_queries'][0]['candidate_after_provider'].update(id=999),lambda s:verify_queries(s,baseline))
    probe('current candidate anchor changed',enabled,lambda s:s['provider_queries'][0]['candidate_after_provider']['current_anchor'].__setitem__(0,0),lambda s:verify_queries(s,baseline))
    probe('preview extended beyond current admitted geometry',enabled,lambda s:s['provider_queries'][0]['request']['preview_left']['size'].__setitem__(0,999),lambda s:verify_queries(s,baseline))
    probe('request borrows physical hold instead of committed origin','first fresh provenance charge',lambda s:s['provider_queries'][0]['request'].update(hold_id=999),lambda s:verify_queries(s,baseline))
    altered=copy.deepcopy(primary);off=next(s for s in altered['scenarios'] if s['name']=='airborne motion independent enabledtrue');off['frames'][-1]['after']['velocity'][1]+=1
    try:verify_motion_pairs(altered)
    except VerificationError as error:proof.append({'probe':'assistance changes airborne velocity','observed':'rejected','reason':str(error),'retained_files_modified':False})
    else:raise VerificationError('Corrupted airborne motion accepted')
    return proof

def historical_signature(run):
    return [(s['name'],s.get('params',{}),s['checks'],[a['label'] for a in s['assertions']]) for s in run['scenarios']]

def verify_evidence_notes():
    note=read(TESTS/'entry_assist_evidence_notes.json')
    require(note['milestone']==11 and note['confirmed_production_defects']==[],'Unreviewed production-correction claim')
    rows=note['harness_corrections']
    require(len(rows)==1 and rows[0]['id']=='candidate-observation-merge','Unreviewed harness correction inventory')
    row=rows[0]
    require(row['corrected_harness_sha256']==REVIEWED_HARNESS_SHA256,'Stale corrected observation harness')
    pin(project_path(row['corrected_harness']),REVIEWED_HARNESS_SHA256)
    for name,digest in row['before_artifacts'].items():pin(project_path(name),digest)
    before=(TESTS/'entry_assist_before_candidate_record_fix_harness.gd.txt').read_text()
    old='"position": _safe(candidate.global_position)})'
    new='"position": _safe(candidate.global_position)}, true)'
    require(before.count(old)==1 and before.replace(old,new,1)==(TESTS/'entry_assist_regression.gd').read_text(),'Recorder correction changed more than the observation overwrite flag')
    for hz in RATES:
        oldrun=read(TESTS/f'entry_assist_before_candidate_record_fix_{hz}hz.json')
        case=next(s for s in oldrun['scenarios'] if s['name']=='neutral behind target direction1 enabledtrue')
        require(case['actual_target_hits']==1 and case['provider_queries'][0]['candidate_after_provider']['inside_tree'] is False,'Retained recorder-defect evidence lacks the contradictory observation')
        del oldrun
    pin(TESTS/'entry_assist_run_compatibility.py');pin(TESTS/'m11_compatibility_runner.log')
    return note

def verify_component_smoke():
    """Bounded component replay provenance; separate from the M11 suite totals."""
    path=ROOT/'combat_pc/components/tests/m11_facing_host_smoke_manifest.json'
    pin(path,HOST_SMOKE_MANIFEST_SHA256)
    manifest=read(path);guide=ROOT/'combat_pc/components/ATTACK_ENTRY_FACING_HOST.md';pin(guide,HOST_GUIDE_SHA256)
    require(manifest['expected_actor_sha256']==REVIEWED_CONTROLLER_SHA256 and manifest['source_hashes_unchanged'] is True,'Component replay used another actor or changed source')
    require(manifest['source_hashes_before']==manifest['source_hashes_after'],'Component replay source drift')
    for name,digest in manifest['source_hashes_after'].items():pin(project_path(name),digest)
    require(set(manifest['development_originals'])==set(manifest['replay_harnesses'])==set(manifest['replay_results'])=={'contract','player'},'Incomplete component replay inventory')
    result={'manifest_path':display(path),'manifest_sha256':PINNED[path.resolve()],'guide_sha256':PINNED[guide.resolve()],
      'scope':'Separate bounded host-contract double and production-actor smoke; these checks are excluded from M11 scenario/assertion/contact totals. Original development runs lack actor source pins and do not count as final-actor acceptance.','replays':{}}
    for kind,count,summary in (('contract',29,'HOST_RESULT 29/29'),('player',5,'HOST_MOTOR_RESULT 5/5')):
        originals=manifest['development_originals'][kind]
        for item in originals.values():pin(project_path(item['path']),item['sha256'])
        replay=manifest['replay_harnesses'][kind];target=project_path(replay['path']);pin(target,replay['sha256'])
        old=project_path(originals['gd.txt']['path']).read_text();change=replay['only_edit']
        require(old.count(change['old_output_path'])==1 and old.replace(change['old_output_path'],change['new_output_path'],1)==target.read_text(),'Component replay changed more than result path')
        row=manifest['replay_results'][kind]
        require(row['passed']==count and row['failures']==0 and row['exit_code']==0 and row['clean_engine_log'] is True,'Component replay did not complete cleanly')
        data_path=project_path(row['results_path']);pin(data_path,row['results_sha256']);data=read(data_path)
        require(data['passed']==len(data['checks'])==count and data['failures']==0 and all(c['passed'] is True for c in data['checks']),'Component result count/failure mismatch')
        original=read(project_path(originals['json']['path']))
        require([c['name'] for c in data['checks']]==[c['name'] for c in original['checks']],'Component replay assertion inventory changed')
        log=project_path(row['log_path']);pin(log,row['log_sha256']);content=log.read_text()
        require(not re.search(r'SCRIPT ERROR|ERROR:|FAIL|WARNING:',content) and content.count(summary)==1,'Component replay log incomplete or contains diagnostic')
        result['replays'][kind]={'checks':count,'passed':True,'result_path':row['results_path'],'log_path':row['log_path'],'route':'minimal provider-registration double' if kind=='contract' else 'production actor and ordinary ChainTarget contact'}
    return result

def verify_inherited_suite(pair,suite,m9,m8,m7,baseline,compact):
    for hz,run in pair.items():
        prefix='held_results' if suite=='held' else f'{suite}_compat_m10_results'
        old=m10.read_compact_history(TESTS/f'{prefix}_{hz}hz.json')
        require(historical_signature(run)==historical_signature(old),f'Inherited fixture/assertion inventory changed: {suite}/{hz}')
        del old
        for field in ('movement_profile','combat_profile','shield_profile','melee_chain'):
            if field in run:require(run[field]==baseline[field],f'Inherited authored profile changed: {suite}/{hz}/{field}')
    if suite in OLDER_SUITES[:6]:
        for run in pair.values():m10.discard_audited_frames(run)
        compact[suite+'_compatibility']=pair
        return {}
    if suite=='soft_slope':
        observers=[]
        for hz,run in pair.items():
            index={s['name']:s for s in run['scenarios']}
            require(m7.minimum_m7_names(run['movement_profile']['terminal_fall_speed']).issubset(index),'Inherited M7 cases missing')
            for s in run['scenarios']:
                m7.verify_plane_measurements(s,hz)
                if s['name'].endswith(' instrumented'):
                    stock=s['name'].removesuffix(' instrumented')+' stock'
                    require(m7.observation_signature(s)==m7.observation_signature(index[stock]),f'Slope observer changed physics: {s["name"]}')
                    observers.append({'physics_hz':hz,'stock':stock,'instrumented':s['name'],'exact_match':True})
        comparisons,phases,_=m7.comparisons_for({**compact,'soft_slope':pair})
        for row in comparisons:
            if row['suite']=='soft_slope':row['suite']='soft_slope_compatibility'
        return {'comparisons':comparisons,'within_rate':phases,'observers':observers}
    if suite=='shield':
        for run in pair.values():require(tuple(s['name'] for s in run['scenarios'])==m8.REQUIRED_M8_CASES,'Inherited M8 cases changed')
        comparisons,phases,timing,contacts=m8.shield_comparisons({'shield':pair})
        for row in comparisons:row['suite']='shield_compatibility'
        return {'comparisons':comparisons,'within_rate':phases,'shield_timing':timing,'shield_contacts':contacts}
    if suite=='combo':
        for run in pair.values():require(tuple(s['name'] for s in run['scenarios'])==m9.REQUIRED_M9_CASES,'Inherited M9 cases changed')
        comparisons,timing,contacts=m9.verify_combo_semantics({'combo':pair})
        for row in comparisons:row['suite']='combo_compatibility'
        return {'comparisons':comparisons,'combo_timing':timing,'combo_contacts':contacts,'prop_scaling':m9.prop_scale_rows({'combo':pair})}
    contacts,oracles,timing,comparisons=m10.verify_m10({'held':pair},baseline)
    return {'comparisons':comparisons,'held_timing':timing,'held_contacts':contacts,'held_oracles':oracles}

LIMITS=[
 'All M11 admission, timing, geometry, precedence and perception choices are authored MOKSHA policy. The reference establishes an aim-related feature family; source-exact timing, geometry, selection and Dead Cells runtime parity are not claimed.',
 'Production-host fixture offers and actual receiver/adapter contact are distinct from adversarial direct-provider API probes. Provider mutation probes do not represent normal host operation or count as physical contact evidence.',
 'The actor verifies structure, live identity, current anchor, bounds, terrain and authority. Semantic opponent/perception eligibility remains the registered host contract; the actor is not a perception or ranking system.',
 'Target offer coordinates and identities may appear only in test-fixture evidence. Actor/host decision diagnostics and strike payloads do not retain that offer.',
 'M11 and M7–M10 formats establish actual consecutive Godot callbacks and deltas. Older compatibility formats establish consecutive actor samples only. Movement/combat start-pin smaller inventories than they end-pin; this is preserved and explicitly reported.',
 'The off/on physical contact demonstration intentionally differs in hits and contact pause. Stationary position/velocity remain equal; a separate contact-free airborne comparison isolates gravity, fall history and resource budgets.',
 'Acceptance covers the named passive fixture and recorded adversarial probes at 120 and 60 Hz. Arbitrary worlds, arbitrary provider code, multiple-target choice, target-conditioned air physics and exact native feel are outside these measurements.',
]

def main():
    require(REVIEWED_HARNESS_SHA256 is not None and REVIEWED_CONTRACT_SHA256 is not None,'Final harness/contract review pins unset; publication closed')
    require(len(REQUIRED_CASES)==len(set(REQUIRED_CASES))==71,'Incomplete/duplicate independent M11 inventory')
    pin(ROOT/'combat_pc/player.gd',REVIEWED_CONTROLLER_SHA256)
    pin(TESTS/'entry_assist_regression.gd',REVIEWED_HARNESS_SHA256)
    pin(ROOT/'combat_pc/MOTOR_CONTRACT.md',REVIEWED_CONTRACT_SHA256)
    proposal=TESTS/'entry_assist_source_proposal.md';pin(proposal,PROPOSAL_SHA256)
    delivered=ROOT/'combat_pc/reference/PERCEIVED_TARGET_FACING_PROPOSAL.md';pin(delivered)
    require(delivered.read_text().split('\n',2)[2]==proposal.read_text(),'Delivered proposal differs beyond reviewed two-line status preface')
    for name in ('FACING_AIR_CONTROL_EVIDENCE.md','FACING_AIR_CONTROL_SOURCE_FACTS.json'):
        pin(ROOT/'combat_pc/reference'/name)
    pin(TESTS/'build_held_report.py');preserved=verify_preservation();redirects=verify_redirects();m9,m8,m7=m10.load_preserved_validators()
    base=m10.read_compact_history(TESTS/'combo_results_120hz.json');baseline={k:base[k] for k in ('movement_profile','combat_profile','shield_profile','melee_chain')};del base;gc.collect()
    suites={};continuity={};logs={};shared={};compact={};inherited={'comparisons':[],'within_rate':[]};entry=probes=None;engine=None;scenarios=[]
    for suite in ('entry_assist',)+OLDER_SUITES:
        prefix='entry_assist_results' if suite=='entry_assist' else f'{suite}_compat_m11_results'
        pair={};continuity[suite]={};suites[suite]={}
        for hz in RATES:
            path=TESTS/f'{prefix}_{hz}hz.json';run=read(path);pair[hz]=run
            continuity[suite][str(hz)],newlogs=verify_run(run,suite,hz,m7);logs.update(newlogs)
            if engine is None:engine=run['engine']
            require(run['engine']==engine,f'Different Godot build: {suite}/{hz}')
            for name,digest in run['hashes'].items():require(name not in shared or shared[name]==digest,f'Cross-suite source drift: {name}');shared[name]=digest
            suites[suite][str(hz)]={'scenarios':len(run['scenarios']),'assertions':run['checks'],'failures':0,'frames':sum(len(s['frames']) for s in run['scenarios']),'path':display(path),'sha256':PINNED[path.resolve()],'source_stable':True}
        require(pair[120]['hashes']==pair[60]['hashes'],f'Rate-pair source mismatch: {suite}')
        if suite=='entry_assist':
            entry=verify_entry_pair(pair,baseline);probes=negative_probes(pair[120],baseline)
            scenarios=[{'name':s['name'],'route':s['params']['provider_route'],'passed_at':list(RATES),'traces':{str(hz):{'path':f'combat_pc/tests/entry_assist_results_{hz}hz.json','json_pointer':f'/scenarios/{i}'} for hz in RATES}} for i,s in enumerate(pair[120]['scenarios'])]
        else:
            signature=m10.paired_signature if suite=='held' else lambda s:m9.paired_signature(s,'combo' if suite=='combo' else suite+'_compatibility',m8)
            require([signature(s) for s in pair[120]['scenarios']]==[signature(s) for s in pair[60]['scenarios']],f'Inherited paired specification mismatch: {suite}')
            result=verify_inherited_suite(pair,suite,m9,m8,m7,baseline,compact)
            for key,value in result.items():
                if key in ('comparisons','within_rate'):inherited[key]+=value
                else:inherited[key]=value
        del pair,run;gc.collect()
        print(f'Validated {suite}: complete source-stable 120/60 Hz pair',flush=True)
    previous=read(ROOT/'combat_pc/held_verification.json')
    fields=('suite','scenario','metric','allowed_difference','tolerance_reason')
    require([[r[k] for k in fields] for r in inherited['comparisons']]==[[r[k] for k in fields] for r in previous['cross_rate_comparisons']],'Inherited cross-rate bounds changed or omitted')
    require(len(inherited['comparisons'])==2314 and len(inherited['held_timing'])==976,'Incomplete inherited comparison/timing population')
    old_phases=previous['inherited_within_rate_contact_phase_comparisons']
    excluded={'gap38','gap40','api_attempt_seconds','physical_attempt_seconds','passed'}
    spec=lambda rows:[{k:v for k,v in r.items() if k not in excluded} for r in rows]
    require(spec(inherited['within_rate'])==spec(old_phases),'Inherited within-rate bounds changed or omitted')
    evidence_notes=verify_evidence_notes();component_smoke=verify_component_smoke();dependencies=m10.dependency_inventory()
    report={'title':'MOKSHA combat PC first-entry facing verification','milestone':11,'status':'passed','generated_utc':datetime.now(timezone.utc).isoformat(),
      'controller_sha256':REVIEWED_CONTROLLER_SHA256,'harness_sha256':REVIEWED_HARNESS_SHA256,'contract_sha256':REVIEWED_CONTRACT_SHA256,
      'report_builder_sha256':pin(Path(__file__)),'proposal_sha256':PROPOSAL_SHA256,'engine':engine,'required_case_inventory':list(REQUIRED_CASES),
      'source_proposal':{'raw_path':display(proposal),'raw_sha256':PROPOSAL_SHA256,'annotated_path':display(delivered),'annotated_sha256':PINNED[delivered.resolve()],
        'audit_origin':'../reference_sources/dead-cells-audit/PERCEIVED_TARGET_FACING_PROPOSAL.md','portable_raw_copy_verified':True},
      'group_counts':{k:len(v) for k,v in REQUIRED_GROUPS.items()},'suites':suites,'production_hashes':shared,'additional_static_dependency_hashes':dependencies,
      'sample_continuity':continuity,'entry_assist_evidence':entry,'inherited_acceptance':inherited,'negative_audit_probes':probes,'console_logs_sha256':logs,
      'compatibility_redirects':redirects,'preserved_evidence':{'manifest_sha256':PRESERVATION_MANIFEST_SHA256,'file_count':707,'snapshot_count':10,'all_recorded_bytes_unchanged':True},
      'harness_evidence_notes':evidence_notes,'separate_component_smoke':component_smoke,'scenarios':scenarios,'limits':LIMITS}
    report['observed_populations']={str(hz):{
      'provider_calls':sum(v['observed_queries'] for v in entry['queries'][str(hz)].values()),
      'production_host_calls':sum(len(rows) for rows in entry['query_observations'][str(hz)].values() if rows and rows[0]['route']=='production_host'),
      'adversarial_direct_provider_calls':sum(len(rows) for rows in entry['query_observations'][str(hz)].values() if rows and rows[0]['route']=='adversarial_direct_provider'),
      'decision_events':sum(v['decision_events'] for v in entry['queries'][str(hz)].values()),
      'passive_target_effects':sum(v['passive_target_applications'] for v in entry['contacts'][str(hz)].values()),
      'adapter_acknowledgements':sum(v['passive_target_acknowledgements'] for v in entry['contacts'][str(hz)].values())} for hz in RATES}
    report['directly_referenced_evidence_sha256']={display(p):h for p,h in sorted(PINNED.items())}
    markdown=render_markdown(report)
    for path,digest in PINNED.items():require(sha(path)==digest,f'Evidence changed while auditing: {path}')
    if '--check-only' in sys.argv:print('PASS (read-only): M11 and all ten inherited suite pairs');return
    (ROOT/'combat_pc/entry_assist_verification.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    (ROOT/'combat_pc/entry_assist_verification.md').write_text(markdown)
    print(f'PASS: {len(REQUIRED_CASES)} M11 cases; 22 complete runs; 2,314 inherited bounds; 976 held timing checks; 707 files and ten archives unchanged')

def render_markdown(r):
    suites=r['suites'];n=len(REQUIRED_CASES);entry=suites['entry_assist']
    lines=['# First-entry facing verification','',
      f'**Passed at 120 Hz and 60 Hz:** {n} independently inventoried M11 cases, {entry["120"]["assertions"]} harness assertions per rate, plus all ten inherited suites on the same final actor. All 22 complete runs have stable recorded source hashes, zero failed assertions and clean engine logs.','',
      f'Actor SHA-256: `{r["controller_sha256"]}`. The [detailed report](entry_assist_verification.json) pins the reviewed actor, harness, contract, proposal, report builder, raw traces, logs and every directly referenced proof file.','',
      '## Authored policy and observed behavior','',
      'The optional helper is disabled by default. Only an initial fresh starter at admitted windup may request one current offer. Every nonzero horizontal input vetoes assistance; input, host and current-step turning permissions must all permit it. Custom start indices do not imply continuation, and a retained step, loop back, held repeat or charged followup does not imply a new initial admission.','',
      'The production host explicitly registers one perceived eligible opposing passive target. The actor checks the current identity, anchor, closed mirrored preview union, terrain visibility and unchanged callback authority. It applies only a facing suggestion. Manual windup input can replace that direction; ordinary active entry commits contact direction. Later target movement can produce a miss and never triggers tracking. Existing configured grounded forward motion follows the chosen facing; no new force, homing, approach rule or range extension is added.','',
      'The mirrored off/on demonstration records actual receiver effects and ordinary adapter acknowledgements. The stationary comparison sets the authored active_ground_speed to 0; under that configuration positions and velocities match. A separate off/on airborne trace compares each callback’s position, velocity, gravity-driven fall history and remaining action budgets. An approved aim target without a damage receiver produces no hit.','',
      '## Independent verification','',
      'The auditor checks exact case order and specifications, consecutive actual Godot callbacks and deltas, query counts/tokens, explicit initial-admission provenance, diagnostic schemas, committed contact direction, strike identities, target deduplication and actual receiver/adapter linkage. Per-case outcome rules are independent of the harness’s passed flags. In-memory corruption probes must be rejected without modifying retained evidence.','',
      'Production-host offers, adversarial direct-provider calls and ordinary physical contacts remain separately labelled. Provider reset, forced ownership, configuration round trip, permission changes, recursive callback and other mutations invalidate a stale offer. An old host cannot clear or disable a replacement provider.','',
      'Each rate records 32 production-host calls and 30 adversarial direct-provider calls, 67 decision events, 28 actual target effects and 28 adapter acknowledgements. Vetoed or ineligible entries can emit a decision without a provider call. Retired provider callbacks emit no stale decision event. These populations are not interchangeable.','',
      '## Preserved acceptance','',
      'All 2,314 inherited cross-rate bounds pass with their exact original identities, numerical tolerances and reasons. All 976 M10 held-profile timing checks are rerun, along with inherited shield/combo contact and timing rules, slope observer equivalence and within-rate comparisons. Each large suite is audited and released before the next is loaded.','',
      '| Suite | Cases per rate | Assertions 120 Hz | Assertions 60 Hz |','|---|---:|---:|---:|']
    for suite,pair in suites.items():lines.append(f'| {suite.replace("_"," ")} | {pair["120"]["scenarios"]} | {pair["120"]["assertions"]} | {pair["60"]["assertions"]} |')
    lines+=['','All 707 recorded historical files and ten M1–M10 ZIP snapshots retain their exact bytes. Historical harnesses differ only in one checked output-path replacement. Runtime start/end pins are checked against current files; additional transitive static dependencies are labelled separately.','',
      'The independent auditor found one test-recorder defect: Dictionary.merge initially retained false default candidate-lifetime flags. The final recorder overwrites those flags with current observations. Both M11 rates were rerun with unchanged physics and unchanged assertions; the erroneous recording, logs and exact one-line harness correction are pinned separately. This is an observation correction, not a confirmed production defect.','',
      'The [host guide](components/ATTACK_ENTRY_FACING_HOST.md) separately links a 29-check minimal registration-double smoke and a 5-check production-actor contact smoke. Their preserved final-source replays change only result paths and have clean logs and unchanged source pins. These bounded integration checks are not added to M11’s cases, assertions or contact populations. The original temporary development runs did not pin actor source and are not claimed as final-actor acceptance.','',
      f'{len(r["negative_audit_probes"])} meaningful in-memory corruption probes were rejected. Independent numerical comparisons and corruption probes are reported separately from harness assertion totals.','', '## Limits','']
    lines+=['- '+item for item in LIMITS]
    return '\n'.join(lines)+'\n'

if __name__=='__main__':
    try:main()
    except (VerificationError,KeyError,ValueError,TypeError) as error:
        print(f'ACCEPTANCE BLOCKED: {error}',file=sys.stderr);raise SystemExit(1)
