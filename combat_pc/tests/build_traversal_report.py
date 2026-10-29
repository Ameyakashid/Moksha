"""Verify paired traversal and compatibility evidence, then build the M3 report."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / 'combat_pc/tests'
def read(p): return json.loads(p.read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
files = {'traversal':'traversal_results', 'movement_compatibility':'movement_compat_m3_results', 'combat_compatibility':'combat_compat_m3_results'}
suites = {name:{hz:read(TESTS/f'{prefix}_{hz}hz.json') for hz in (120,60)} for name,prefix in files.items()}
preserved = read(TESTS/'traversal_preserved_evidence.json')
for p,digest in preserved.items(): assert sha(ROOT/p)==digest, f'Historical evidence changed: {p}'
for name,pair in suites.items():
    for hz,run in pair.items():
        assert not run['failures'], (name,hz,run['failures'])
        assert run['production_hash_stable_during_run'], (name,hz)
        for p,digest in run['hashes'].items(): assert sha(ROOT/p.removeprefix('res://'))==digest, f'Stale {name} source: {p}'
    assert pair[120]['hashes']==pair[60]['hashes'], f'Different rate sources: {name}'
    assert [s['name'] for s in pair[120]['scenarios']]==[s['name'] for s in pair[60]['scenarios']]
controller = suites['traversal'][120]['hashes']['res://combat_pc/player.gd']
assert all(pair[120]['hashes']['res://combat_pc/player.gd']==controller for pair in suites.values())
checks=[]
def compare(name, scenario, metric, bound, reason):
    values={hz:next(s for s in suites[name][hz]['scenarios'] if s['name']==scenario)['measurements'][metric] for hz in (120,60)}
    passed=abs(values[120]-values[60]) <= bound+1e-12
    checks.append(dict(suite=name,scenario=scenario,metric=metric,value_120hz=values[120],value_60hz=values[60],allowed_difference=bound,tolerance_reason=reason,passed=passed))
    assert passed,checks[-1]
flow='connected dive startup descent impact recovery'
for metric in ['startup_seconds','impact_seconds','recovery_seconds']:
    compare('traversal',flow,metric,1/60,'One 60 Hz phase boundary')
compare('traversal',flow,'total_seconds',4/60,'Three authored phase boundaries plus one real floor-contact boundary')
compare('traversal',flow,'max_fall_speed',.01,'Both runs attain the same authored speed cap')
compare('traversal','dive descent watchdog without floor','timeout_seconds',2/60,'Startup and descent watchdog boundary quantization')
prior=read(ROOT/'combat_pc/combat_verification.json')
for c in prior['cross_rate_comparisons']:
    name='combat_compatibility' if c['suite']=='combat' else 'movement_compatibility'
    compare(name,c['scenario'],c['metric'],c['allowed_difference'],c['tolerance_reason'])

traversal=suites['traversal'][120]
def group(name):
    if name.startswith('dive ') and (' interruption ' in name or ' forced ' in name): return 'Dive phase interruption matrix'
    if name.startswith(('drop exception','blocked drop','overlapping drop','jump waits','drop expiry')): return 'Exception ownership and host geometry changes'
    if ' gate ' in name or name.startswith(('context stays','native parsed','fresh reset','canceled dive')): return 'Context, permissions and consumed input'
    if name.startswith(('drop reaches','coplanar','unsupported','drop interrupted','stack spacing','live drop')): return 'One-way geometry and connected stacks'
    return 'Dive motion, impact and lifecycle'
groups={}
for s in traversal['scenarios']: groups.setdefault(group(s['name']),[]).append(s['name'])
fixes=[
    {'issue':'Removed one-way target left a stale PhysicsServer collision exception',
     'evidence':'Actual 120 Hz removal during drop and blocked cleanup caused body_get_object_instance_id body=null errors; get_collision_exceptions retained the freed body entry.',
     'resolution':'Controller retains target RID independently and uses a disconnectable tree_exiting callback to clear the exception before body destruction. Normal clearance and reset also disconnect it.',
     'regressions':['drop exception lifetime removed','blocked drop cleanup stays explicit and target scoped','drop exception lifetime reset']},
    {'issue':'Fresh jump bypassed cleanup after the drop action ended or became melee',
     'evidence':'Both actual 120 Hz probes accepted an air jump and expanded to standing while the ignored platform still overlapped the actor.',
     'resolution':'Jump eligibility, effective permissions, can_stand and shape expansion now honor outstanding cleanup independently of the current action owner.',
     'regressions':['jump waits for outstanding drop cleanup action_expired','jump waits for outstanding drop cleanup melee','drop expiry into dive retains safe cleanup']},
]
limits=[
    'All new algorithms, ability policy, durations, speeds and thresholds are original MOKSHA tuning. The pinned Dead Cells audit supports feature/interface intent, not recovered drop/dive bodies or exact-game parity.',
    'Only dedicated upright positive-scale rectangular one-way bodies with coplanar top surfaces are accepted. Mixed solid/one-way, stacked heights in one body, rotated/nonrectangle and ambiguous supports deliberately refuse.',
    'Drop action duration is finite. If valid one-way overlap prevents safe cleanup at the deadline, one scoped exception remains and a single blocked-cleanup event is reported until separation/removal/reset. This is explicit retained cleanup, not an unconditional finite collision-ignore promise.',
    'Changing an overlapping ignored body into unsupported solid/mixed/rotated geometry restores collision and freezes the actor in a reported drop_geometry_blocked state until separation/removal/reset. The suite verifies safe refusal and recovery, not escape from impossible geometry.',
    'Dive impact emits semantic/noise hooks only; no area damage, enemy AI, health/death, floor breakthrough or new combat system is claimed.',
    'Headless tests exercise real physics and parsed keyboard input. Native visual and feel review belongs to the lab owner.',
    'Selected adversarial geometry/profile cases are covered, not every arbitrary scene or value. The blocked-cleanup watchdog fixture deliberately sets gravity and current velocity to zero to prevent clearance without replacing collision queries.',
]
archives={name:sha(ROOT.parent/'moksha-backups'/name) for name in ['MOKSHA-Combat-PC-M1-20261004.zip','MOKSHA-Combat-PC-M2-20261004.zip']}
assert archives['MOKSHA-Combat-PC-M1-20261004.zip']=='6d5dc4bce621330273fd7607255b73344aa593256d4922d4e5a4c766f6b43411'
assert archives['MOKSHA-Combat-PC-M2-20261004.zip']=='aceb39477a76dc2d31dc4afd97b8b367206cb54ff76945c1d4c40e0de03355b0'
report={'title':'MOKSHA combat PC targeted drop and dive verification','milestone':3,'status':'passed',
 'generated_utc':datetime.now(timezone.utc).isoformat(),'engine':traversal['engine'],
 'controller_sha256':controller,'production_hashes':traversal['hashes'],
 'reference_pin':'77c3ad263c4187ade6d048ba77bb61f79e6cec44',
 'reference_boundary':'Source declarations and official behavior notes ground feature intent; all numeric and implementation expectations use original MOKSHA profiles and MOTOR_CONTRACT.',
 'contract_sha256':sha(ROOT/'combat_pc/MOTOR_CONTRACT.md'),
 'movement_profile':traversal['movement_profile'],'combat_profile':traversal['combat_profile'],
 'suites':{},'cross_rate_comparisons':checks,'coverage_groups':groups,'scenarios':[],'verified_fixes':fixes,'limits':limits,
 'preserved_evidence':{'all_byte_identical':True,'files':preserved,'archives_sha256':archives},
 'pre_fix_evidence':'combat_pc/tests/traversal_defect_reproductions.json',
 'compatibility_method':'Original M1/M2 harnesses copied to /tmp; only output filenames changed. Original accepted harnesses, results, reports and report-builder source remain byte-identical.',
 'tight_stack_result':'At an upper top of 152 px, thickness of 6 px, and lower top of 192 px, the floor skin leaves no spare standing clearance: actor correctly stays crouched, clears old ignore, and accepts the first fresh second-drop chord. A lower top of 196 px (44 px separation) permits standing. Both ordinary and melee-interrupted variants pass.',
 'cleanup_matrix':'Roll/melee/damage may replace the finite drop action while target cleanup remains. Plain jump remains blocked until cleanup clears. A fresh dive after drop owner expiry is permitted, retains the small collider and existing exception, then completes swept downward separation.'}
for name,pair in suites.items():
    report['suites'][name]={}
    for hz,run in pair.items():
        p=TESTS/f'{files[name]}_{hz}hz.json'
        report['suites'][name][str(hz)]={'scenarios':len(run['scenarios']),'assertions':run['checks'],'failures':len(run['failures']),
            'frames':sum(len(s['frames']) for s in run['scenarios']),'source_stable':True,'path':str(p.relative_to(ROOT)),'sha256':sha(p)}
for i,s in enumerate(traversal['scenarios']):
    report['scenarios'].append({'name':s['name'],'passed_at':[120,60],'assertions':[a['label'] for a in s['assertions']],
        'traces':{str(hz):{'path':f'combat_pc/tests/traversal_results_{hz}hz.json','json_pointer':f'/scenarios/{i}'} for hz in (120,60)}})
(ROOT/'combat_pc/traversal_verification.json').write_text(json.dumps(report,indent=2)+'\n')
lines=['# Targeted one-way drop and dive verification','',
 f'**Passed at 120 Hz and 60 Hz:** {len(traversal["scenarios"])} connected traversal scenarios and {traversal["checks"]} assertions per rate. All 36 M1 movement scenarios and 49 M2 combat scenarios also pass against the same controller. Every run has zero failures and stable source hashes.','',
 f'Controller SHA-256: `{controller}`. [Detailed evidence](traversal_verification.json) contains exact profile, source, fixture and harness hashes plus scenario-to-trace mappings. The native project remains at 120 Hz; the second rate is overridden only within its test process.','',
 '## What passed','',
 '- Targeted upper-to-lower one-way dropping, dedicated coplanar multi-shape support, conservative mixed/stacked/rotated/nonrectangle/ambiguous refusal, independent thin solid walls through roll cancellation, and moving/disabled/removed targets.',
 '- Ability, main-capability and host-permission gates; consumed fresh Down+Jump; frozen ground context that cannot become an airborne dive; native parsed keyboard input; fresh reset support classification.',
 '- Full startup/descent/impact/recovery dive flow, the allowed/denied roll/jump/melee interruption matrix, forced damage and reset in every phase, ceiling collision, slope impact, missing-floor watchdog, support loss and actor hitpause.',
 '- Independent exception cleanup after melee/damage/action expiry, explicit blocked cleanup and changed-geometry recovery, jump expansion guards, and a permitted small-body drop-expiry→dive path.',
 '- One dive start per airborne trip, actual floor refill, semantic impact without fabricated melee damage, and no delayed impact after cancellation.','',
 '## Defects corrected','']
for f in fixes: lines += ['- **'+f['issue']+'.** '+f['evidence']+' '+f['resolution']]
lines += ['','Both defects have retained [pre-fix physical traces](tests/traversal_defect_reproductions.json) and final passing repros. The earlier thin-wall diagnostic was corrected in the test query: Godot returns the query exclusion array by value, so the harness now constructs and assigns the complete list. This excludes only intentional one-way overlaps from the independent solid-overlap check; wall expectations and tolerances were not relaxed.','',
 '## Tight stacks and blocked conditions','',report['tight_stack_result'],'',report['cleanup_matrix'],'',
 'The .08-second drop action and .30-second cleanup deadline have different roles. An unresolved valid one-way overlap reports `drop_cleanup_blocked` once and keeps only that target exception; the actor can still move toward safe separation. Unsupported geometry replacing the overlapping target reports `drop_geometry_blocked` and stops motion until the host removes/separates it or resets the actor. These are explicit scene limits, not silent global collision disabling.','',
 '## Timing at both rates','',
 '| Measurement | 120 Hz | 60 Hz | Allowed difference |','|---|---:|---:|---:|']
for c in checks:
    if c['suite']=='traversal': lines.append(f'| {c["metric"]} | {c["value_120hz"]:.6f} | {c["value_60hz"]:.6f} | {c["allowed_difference"]:.6f} |')
lines += ['',f'All {len(checks)} paired bounds pass, including the unchanged 14 M1/M2 bounds. Phase bounds are one 60 Hz sampled boundary; the complete connected dive allows its three authored boundaries plus actual floor contact. The missing-floor watchdog allows two phase boundaries.','',
 '## Provenance and limits','',
 'The [pinned movement audit](reference/DEAD_CELLS_MOVEMENT_AUDIT.md) supplies drop/dive declaration evidence and official interaction notes. Relevant implementation bodies are missing. This report tests the original MOKSHA [motor contract](MOTOR_CONTRACT.md), not exact Dead Cells behavior.','']
lines += ['- '+item for item in limits]
lines += ['',f'All {len(preserved)} accepted M1/M2 evidence artifacts remain byte-identical. Both milestone ZIP hashes were also checked. The new compatibility traces have separate filenames and do not replace those earlier acceptances.','',
 '## Reproduce','',
 'Run from the project directory with writable XDG data/cache/config directories:','',
 '```sh',
 'mkdir -p /tmp/moksha-combat-test-data /tmp/moksha-combat-test-cache /tmp/moksha-combat-test-config',
 'export XDG_DATA_HOME=/tmp/moksha-combat-test-data',
 'export XDG_CACHE_HOME=/tmp/moksha-combat-test-cache',
 'export XDG_CONFIG_HOME=/tmp/moksha-combat-test-config',
 'godot --headless --fixed-fps 120 --path . --script combat_pc/tests/traversal_regression.gd -- --hz=120',
 'godot --headless --fixed-fps 60 --path . --script combat_pc/tests/traversal_regression.gd -- --hz=60',
 '```','',
 'The traversal script inherits unchanged M2 harness helpers and overrides its run entry and output path. It drives actual engine physics callbacks, the production scene, real collision sweeps and space queries. `--fixed-fps` accelerates wall-clock execution; it does not replace physics with field mocks.','',
 'For compatibility, copy the original movement/combat scripts to `/tmp` and change only their output filenames to `movement_compat_m3_results_%dhz%s.json` and `combat_compat_m3_results_%dhz.json`. Run each at both rates. Rebuild this report with `python3 combat_pc/tests/build_traversal_report.py`; it rejects failures, mismatched or stale source hashes, changed historical evidence, and exceeded paired bounds.','',
 'Traces: [traversal 120](tests/traversal_results_120hz.json), [traversal 60](tests/traversal_results_60hz.json), [movement compatibility 120](tests/movement_compat_m3_results_120hz.json), [movement compatibility 60](tests/movement_compat_m3_results_60hz.json), [combat compatibility 120](tests/combat_compat_m3_results_120hz.json), [combat compatibility 60](tests/combat_compat_m3_results_60hz.json).','']
(ROOT/'combat_pc/traversal_verification.md').write_text('\n'.join(lines))
print(f'PASS: {len(traversal["scenarios"])} traversal scenarios; all three paired suites and {len(checks)} bounds verified; {len(preserved)} historical artifacts preserved')
