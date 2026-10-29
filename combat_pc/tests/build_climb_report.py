"""Pin the paired climb/compatibility evidence without changing prior milestones."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
ROOT=Path(__file__).resolve().parents[2]
TESTS=ROOT/'combat_pc/tests'
def read(p): return json.loads(p.read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
files={'climb':'climb_results','movement_compatibility':'movement_compat_m4_results','combat_compatibility':'combat_compat_m4_results','traversal_compatibility':'traversal_compat_m4_results'}
suites={name:{hz:read(TESTS/f'{prefix}_{hz}hz.json') for hz in (120,60)} for name,prefix in files.items()}
preserved=read(TESTS/'climb_preserved_evidence.json')
for p,digest in preserved.items(): assert sha(ROOT/p)==digest, f'Prior evidence changed: {p}'
for name,pair in suites.items():
    for hz,run in pair.items():
        assert not run['failures'], (name,hz,run['failures'])
        assert run['production_hash_stable_during_run'], (name,hz)
        for p,digest in run['hashes'].items(): assert sha(ROOT/p.removeprefix('res://'))==digest, f'Stale {name}: {p}'
    assert pair[120]['hashes']==pair[60]['hashes'], f'Rate pair used different sources: {name}'
    assert [s['name'] for s in pair[120]['scenarios']]==[s['name'] for s in pair[60]['scenarios']]
controller=suites['climb'][120]['hashes']['res://combat_pc/player.gd']
assert all(pair[120]['hashes']['res://combat_pc/player.gd']==controller for pair in suites.values())
comparisons=[]
def scenario(suite,hz,label): return next(s for s in suites[suite][hz]['scenarios'] if s['name']==label)
def compare(suite,label,key,bound,reason,extract=None):
    values={hz:(extract(scenario(suite,hz,label),hz) if extract else scenario(suite,hz,label)['measurements'][key]) for hz in (120,60)}
    passed=abs(values[120]-values[60])<=bound+1e-12
    row=dict(suite=suite,scenario=label,metric=key,value_120hz=values[120],value_60hz=values[60],allowed_difference=bound,tolerance_reason=reason,passed=passed)
    comparisons.append(row); assert passed,row
for type_ in ['ladder','vine']:
    name=type_+' deliberate align ascend stop descend'
    compare('climb',name,'steady_rise_distance',.01,'Same 0.20-second steady input interval; 0.01 px accommodates accumulated float-position arithmetic')
    expected=suites['climb'][120]['movement_profile']['climb_up_speed']*.2
    for hz in (120,60): assert abs(scenario('climb',hz,name)['measurements']['steady_rise_distance']-expected)<.01

def top_seconds(s,hz):
    entered=next(e['tick'] for e in s['events'] if e['event']=='climb_attached')
    exited=next(e['tick'] for e in s['events'] if e['event']=='climb_detached' and e['data'].get('reason')=='top_exit')
    return (exited-entered)/hz
compare('climb','ladder upward one-way top exit and held loop','top_exit_seconds',2/60,'At most one alignment/start and one physical exit boundary',top_seconds)
prior=read(ROOT/'combat_pc/traversal_verification.json')
for c in prior['cross_rate_comparisons']:
    suite='traversal_compatibility' if c['suite']=='traversal' else c['suite']
    compare(suite,c['scenario'],c['metric'],c['allowed_difference'],c['tolerance_reason'])
climb=suites['climb'][120]
limits=[
 'All climbing algorithms, sensor dimensions, speeds, timings, selection policy and grace are original MOKSHA choices. No recovered Dead Cells numbers or executable parity are claimed.',
 'Sensors must remain upright, positive-scale and consistent with their actual rectangular SensorShape. Rotation, negative scale, shape/script withdrawal and geometry mutation release attachment.',
 'Deterministic selection filters directionally valid candidates then sorts priority, axis distance and node path. Physics discovery is capped at 64 returned hits; arbitrary scenes beyond that local set are not covered.',
 'Grip jump remains subject to host jump permission, standing clearance and outstanding top-entry drop cleanup. The short grace applies only after horizontal release and only near the same still-valid sensor.',
 'The inherited drop-cleanup and invalid-geometry safety limits remain in force. This pass does not establish escape from physically impossible geometry.',
 'Headless acceptance uses real Godot physics and parsed keyboard events. Native presentation and feel review is recorded separately; this suite does not count animation parity, NPCs, wall-running, parry or extra combat systems.'
]
corrections=[
 {'issue':'Adjacent horizontal release then Jump lost supported grip authority',
  'evidence_kind':'Native QA and direct parsed-event repro; fix independently verified at both rates',
  'resolution':'A profile-authored 0.06-second single-use grace retains only nearby valid grip support after horizontal release. It preserves spent budgets, freezes in hitpause and is cleared by accepted actions, invalidation or reset.',
  'tests':['native adjacent horizontal then jump -1','native adjacent horizontal then jump 1','released grip grace expires in actor time','released grip grace and queued jump survive local pause']},
 {'issue':'A moved sensor could authorize entry from stale broadphase overlap',
  'evidence_kind':'Direct physics repro before fix; independent retained regression afterward',
  'resolution':'Candidate selection also validates overlap with the sensor’s current declared horizontal span before starting alignment.',
  'tests':['fresh moving sensor overlap cannot use stale broadphase']},
 {'issue':'Endpoint selection, mutated sensor shapes and inherited one-way transport restrictions',
  'evidence_kind':'Static review corrected before independent physical probes',
  'resolution':'Directionally ineligible candidates filter before ranking; actual shape/type/transform and script changes invalidate grip; upward carrier motion respects the carried one-way restriction even during pause.',
  'tests':['directionally ineligible overlap does not mask valid sensor','attached sensor change shape_null','attached sensor change shape_resize','attached sensor change shape_transform','attached sensor change shape_other','attached sensor change script_withdrawn','forbidden upward one-way crossing carrier','forbidden upward one-way crossing paused_carrier']},
 {'issue':'Reversing a one-way top entry could leave the target ignored',
  'evidence_kind':'Review correction independently physically verified',
  'resolution':'Top reversal uses an additional swept clearance rise before restoring the platform and settling back onto it.',
  'tests':['top descent reversal returns to same one-way','top descent jump respects outstanding cleanup']}
]
for correction in corrections:
    assert all(any(s['name']==name for s in climb['scenarios']) for name in correction['tests'])
archives={name:sha(ROOT.parent/'moksha-backups'/name) for name in ['MOKSHA-Combat-PC-M1-20261004.zip','MOKSHA-Combat-PC-M2-20261004.zip','MOKSHA-Combat-PC-M3-20261004.zip']}
expected_archives=['6d5dc4bce621330273fd7607255b73344aa593256d4922d4e5a4c766f6b43411','aceb39477a76dc2d31dc4afd97b8b367206cb54ff76945c1d4c40e0de03355b0','e8b440c58ce075928814d29623350ef680935c9459c23d6d8e7efbb3cb5c6c3b']
assert list(archives.values())==expected_archives
report={'title':'MOKSHA combat PC ladder and vine verification','milestone':4,'status':'passed','generated_utc':datetime.now(timezone.utc).isoformat(),
 'engine':climb['engine'],'controller_sha256':controller,'production_hashes':climb['hashes'],
 'contract_sha256':sha(ROOT/'combat_pc/MOTOR_CONTRACT.md'),'reference_pin':'77c3ad263c4187ade6d048ba77bb61f79e6cec44',
 'movement_profile':climb['movement_profile'],'combat_profile':climb['combat_profile'],'suites':{},'cross_rate_comparisons':comparisons,
 'verified_corrections':corrections,'limits':limits,'scenarios':[],
 'preserved_evidence':{'all_byte_identical':True,'files':preserved,'archives_sha256':archives},
 'execution':'Production player and climbable scenes inside actual engine physics callbacks. Sensors animate in pre-actor physics callbacks. Collision queries and sweeps remain live. Native key cases use actor automatic physics and Input.parse_input_event.',
 'compatibility_method':'Original M1/M2/M3 harnesses copied to /tmp with only output filename redirected; original scripts and accepted artifacts unchanged.',
 'resource_evidence':'A connected scenario physically performs ground jump, air jump, dive and roll, removes the original floor, attaches to a real sensor with all air allowances spent, then tests supported jump, no repeat without reattachment, and a second jump after real neutral/delay/reattachment.',
 'harness_clarifications':['The reattachment test lets a previously denied jump buffer expire before asking for a new attached jump; an earlier buffered press legitimately fires after reattachment.','Clearing a top-entry collision exception does not itself imply full standing headroom. The grip-jump test waits for actual standing clearance before expecting launch.']}
for name,pair in suites.items():
    report['suites'][name]={}
    for hz,run in pair.items():
        p=TESTS/f'{files[name]}_{hz}hz.json'
        report['suites'][name][str(hz)]={'scenarios':len(run['scenarios']),'assertions':run['checks'],'failures':len(run['failures']),
          'frames':sum(len(s['frames']) for s in run['scenarios']),'source_stable':True,'path':str(p.relative_to(ROOT)),'sha256':sha(p)}
for i,s in enumerate(climb['scenarios']):
    report['scenarios'].append({'name':s['name'],'passed_at':[120,60],'assertions':[a['label'] for a in s['assertions']],
      'traces':{str(hz):{'path':f'combat_pc/tests/climb_results_{hz}hz.json','json_pointer':f'/scenarios/{i}'} for hz in (120,60)}})
(ROOT/'combat_pc/climb_verification.json').write_text(json.dumps(report,indent=2)+'\n')
lines=['# Ladder and vine verification','',
 f'**Passed at 120 Hz and 60 Hz:** {len(climb["scenarios"])} connected climb scenarios / {climb["checks"]} assertions per rate. The unchanged M1 movement (36), M2 combat (49) and M3 traversal (64) scenarios also pass on this same revision. All eight runs have zero failures and stable sources.','',
 f'Controller SHA-256: `{controller}`. [Detailed evidence](climb_verification.json) records exact profiles, components, harness hashes and every scenario’s trace pointer.','',
 '## Verified behavior','',
 '- Deliberate vertical entry and analog dominance; priority/distance/path selection after endpoint filtering; bounded swept alignment; ladder/vine ascent, braking, idle and descent.',
 '- One-way top entry/exit and reversal, bottom/intermediate floors, thin walls, ceilings, moving sensors, blocked transport during normal time and hitpause, excessive movement, and stale broadphase entry rejection.',
 '- Disabled, removed, rotated, negatively scaled, resized, transformed, replaced or withdrawn sensors; valid positive scaling and world-space rung metadata; ability, host and main-capability gates.',
 '- Jump, roll, melee, dive, damage and horizontal detachment; denied actions preserve grip. One connected run spends air jump, dive and roll through their actual actions before attachment. Grip jumping preserves those spent budgets; a second supported jump requires physical reattachment.',
 '- Regrab requires real neutral and elapsed simulation time. Input masking cannot fake neutral, and hitpause freezes the delay. Reset clears the grip lifecycle.',
 '- Parsed A/D on one physics tick followed by Space on the next uses the authored 0.06-second recent-grip grace. Both sides, no-repeat, expiry, pause, invalidated support, host/cleanup gates and every replacement-action clearing path pass.','',
 '## Corrections verified','']
for c in corrections: lines.append('- **'+c['issue']+'.** '+c['resolution']+' Evidence: '+c['evidence_kind']+'.')
lines += ['','The independent final suite found no remaining production failure. Review-driven corrections are distinguished from direct pre-fix repros in the JSON. Two initial harness assumptions were corrected: a still-live jump buffer can legitimately launch on reattachment, and cleared drop cleanup is separate from enough room to stand. No collision tolerance was loosened.','',
 '## Rate comparison','', '| Measurement | 120 Hz | 60 Hz | Allowed difference |','|---|---:|---:|---:|']
for c in comparisons:
    if c['suite']=='climb': lines.append(f'| {c["scenario"]}: {c["metric"]} | {c["value_120hz"]:.6f} | {c["value_60hz"]:.6f} | {c["allowed_difference"]:.6f} |')
lines += ['',f'All {len(comparisons)} paired bounds pass, including the unchanged 20 earlier-milestone bounds. The steady climb interval is exactly 0.20 seconds and independently matches profile speed × time within 0.01 px. Top-exit duration comes from recorded attachment/exit event ticks and allows two 60 Hz boundary steps.','',
 '## Scope and preservation','']
lines += ['- '+item for item in limits]
lines += ['',f'All {len(preserved)} prior accepted evidence files and all three milestone archives retain their recorded hashes. Compatibility outputs use new M4 filenames; earlier acceptances remain intact. The [motor contract](MOTOR_CONTRACT.md) and [pinned reference audit](reference/DEAD_CELLS_MOVEMENT_AUDIT.md) define the authored behavior and source-evidence boundary.','',
 '## Reproduce','',
 'Run from the project directory with writable XDG locations:','', '```sh',
 'mkdir -p /tmp/moksha-combat-test-data /tmp/moksha-combat-test-cache /tmp/moksha-combat-test-config',
 'export XDG_DATA_HOME=/tmp/moksha-combat-test-data', 'export XDG_CACHE_HOME=/tmp/moksha-combat-test-cache', 'export XDG_CONFIG_HOME=/tmp/moksha-combat-test-config',
 'godot --headless --fixed-fps 120 --path . --script combat_pc/tests/climb_regression.gd -- --hz=120',
 'godot --headless --fixed-fps 60 --path . --script combat_pc/tests/climb_regression.gd -- --hz=60', '```','',
 'The climb script inherits unchanged M3/M2 harness helpers and overrides its run/output entry. `--fixed-fps` speeds wall-clock execution while actual physics callbacks, sweeps and queries remain active.','',
 'For compatibility, copy movement/combat/traversal scripts to `/tmp` and redirect only their result filenames to `movement_compat_m4_results_%dhz%s.json`, `combat_compat_m4_results_%dhz.json`, and `traversal_compat_m4_results_%dhz.json`. Run each at both rates. `python3 combat_pc/tests/build_climb_report.py` rebuilds this report and rejects failed, stale or mismatched runs, changed historical artifacts, and exceeded paired bounds.','',
 'Traces: [climb 120 Hz](tests/climb_results_120hz.json), [climb 60 Hz](tests/climb_results_60hz.json), plus the six `*_compat_m4_results_*hz.json` files indexed in the detailed report.','']
(ROOT/'combat_pc/climb_verification.md').write_text('\n'.join(lines))
print(f'PASS: {len(climb["scenarios"])} climb scenarios; four paired suites, {len(comparisons)} bounds and {len(preserved)} historical artifacts verified')
