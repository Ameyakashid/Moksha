"""Validate and pin M5 wall evidence without changing any earlier acceptance."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / 'combat_pc/tests'
def read(path): return json.loads(path.read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

prefixes = {'wall':'wall_results', 'movement_compatibility':'movement_compat_m5_results',
            'combat_compatibility':'combat_compat_m5_results', 'traversal_compatibility':'traversal_compat_m5_results',
            'climb_compatibility':'climb_compat_m5_results'}
suites = {name:{hz:read(TESTS/f'{prefix}_{hz}hz.json') for hz in (120,60)} for name,prefix in prefixes.items()}
preserved = read(TESTS/'wall_preserved_evidence.json')
for path,digest in preserved['files'].items():
    update=preserved.get('documentation_updates',{}).get(path)
    if update:
        assert digest==update['original_sha256']
        with zipfile.ZipFile(ROOT.parent/'moksha-backups'/update['original_archive']) as archive:
            assert hashlib.sha256(archive.read(update['original_archive_entry'])).hexdigest()==digest, ('original documentation not preserved',path)
        assert sha(ROOT/path)==update['current_sha256'], ('unrecorded documentation change',path)
    else:
        assert sha(ROOT/path)==digest, f'Historical evidence changed: {path}'
unchanged_files=len(preserved['files'])-len(preserved.get('documentation_updates',{}))
provisional_dir=TESTS/'m5_provisional_e772'
provisional=read(provisional_dir/'manifest.json')
for entry in provisional['files'].values():
    assert sha(provisional_dir/entry['preserved_name'])==entry['sha256'], ('changed provisional evidence',entry['preserved_name'])
assert len(preserved['archives'])==4
for name,digest in preserved['archives'].items():
    assert sha(ROOT.parent/'moksha-backups'/name)==digest, f'Historical archive changed: {name}'
logs = {}
for name,pair in suites.items():
    short_name = name.removesuffix('_compatibility')
    for hz,run in pair.items():
        assert not run['failures'], (name,hz,run['failures'])
        assert run['production_hash_stable_during_run'], (name,hz,'changed during run')
        for path,digest in run['hashes'].items():
            assert sha(ROOT/path.removeprefix('res://'))==digest, (name,hz,'stale source',path)
        log = TESTS/f'm5_{short_name}_{hz}.log'
        content = log.read_text()
        assert 'MOKSHA ' in content and '0 failures' in content, (log,'missing completion')
        assert all(token not in content for token in ('SCRIPT ERROR','ERROR:','FAIL:','WARNING:')), (log,'engine diagnostic')
        logs[str(log.relative_to(ROOT))] = sha(log)
    assert pair[120]['hashes']==pair[60]['hashes'], f'{name} used different rate-pair revisions'
    assert [s['name'] for s in pair[120]['scenarios']]==[s['name'] for s in pair[60]['scenarios']], name
wall = suites['wall'][120]
controller = wall['hashes']['res://combat_pc/player.gd']
old_wall=read(provisional_dir/'wall_verification.json')
assert wall['movement_profile']==old_wall['movement_profile'], 'Regrab fix changed movement tuning'
assert wall['combat_profile']==old_wall['combat_profile'], 'Regrab fix changed combat tuning'
assert all(pair[120]['hashes']['res://combat_pc/player.gd']==controller for pair in suites.values())
for hz,run in suites['wall'].items():
    for scenario in run['scenarios']:
        assert not scenario['measurements'].get('sampling_gaps'), (hz,scenario['name'])
        ticks = [f['tick'] for f in scenario['frames']]
        assert all(b==a+1 for a,b in zip(ticks,ticks[1:])), (hz,scenario['name'],'missing physics samples')

comparisons = []
def scenario(suite,hz,name): return next(s for s in suites[suite][hz]['scenarios'] if s['name']==name)
def compare(suite,name,metric,bound,reason,extract=None):
    values={hz:(extract(scenario(suite,hz,name),hz) if extract else scenario(suite,hz,name)['measurements'][metric]) for hz in (120,60)}
    row={'suite':suite,'scenario':name,'metric':metric,'value_120hz':values[120],'value_60hz':values[60],
         'allowed_difference':bound,'tolerance_reason':reason,'passed':abs(values[120]-values[60])<=bound+1e-12}
    comparisons.append(row); assert row['passed'],row
compare('wall','steady profile wall ascent interval','steady_rise_distance',.01,
        'Identical 0.15-second steady interval; 0.01 px covers accumulated float-position arithmetic')
for hz in (120,60):
    assert abs(scenario('wall',hz,'steady profile wall ascent interval')['measurements']['steady_rise_distance']-
               wall['movement_profile']['wall_run_speed']*.15)<.01
for direction in (-1,1):
    compare('wall',f'finite run slide and exhaustion {direction}','run_seconds',1/60+1e-9,
            'A phase boundary may quantize by one 60 Hz step')
    compare('wall',f'supported outward kick preserves spent budgets {direction}','kick_commit_seconds',1/60+1e-9,
            'Finite commitment ends on the first physics boundary at or after its authored duration')
def top_seconds(s,hz):
    start=next(e['tick'] for e in s['events'] if e['event']=='climb_attached')
    end=next(e['tick'] for e in s['events'] if e['event']=='climb_detached' and e['data'].get('reason')=='top_exit')
    return (end-start)/hz
for old in read(ROOT/'combat_pc/climb_verification.json')['cross_rate_comparisons']:
    suite='climb_compatibility' if old['suite']=='climb' else old['suite']
    compare(suite,old['scenario'],old['metric'],old['allowed_difference'],old['tolerance_reason'],
            top_seconds if old['metric']=='top_exit_seconds' else None)

reproductions=read(TESTS/'wall_defect_reproductions.json')
fixes=[
 ('Freed active/recent wall passed into typed geometry helper',
  'Validate object lifetime before a typed geometry access, including recent-kick support.',
  ['live wall mutation removed','recent wall kick grace removed']),
 ('Coplanar adjacent solid-body seam misidentified as a top ledge',
  'Reject covered top candidates and change the active coplanar carrier while retaining the same episode and consumed allowance.',
  ['coplanar collider seam cannot refresh run']),
 ('Stale committed geometry authorizes a moved-away wall episode before immediate detach',
  'Preflight pending geometry and bounded safe transport before attachment, owner cancellation or episode consumption.',
  ['fresh wall entry ignores stale moved-away body']),
 ('Fresh toward plus Jump at valid wall spent air jump before same-tick resumed slide swallowed the impulse',
  'Resolve eligible fresh supported wall intent before air jump; prevent automatic acquisition from overwriting any accepted jump in that tick.',
  [f'native fresh toward jump after expired wall grace {d}' for d in (-1,1)]+
  [f'native ordinary jump survives denied wall entry {d}' for d in (-1,1)]),
 ('Near regrab expiry, air jump is spent before next-tick wall reattachment swallows ascent',
  'Reserve the existing jump buffer when regrab cooldown is the only blocker; protect a genuinely accepted ordinary air jump against the same contact throughout upward ascent. No grace or profile value changed.',
  [f'native wall regrab boundary {d} {boundary}' for d in (-1,1) for boundary in ('before','at','after')]+
  [f'native ordinary jump survives denied wall entry {d}' for d in (-1,1)]),
 ('Brief host denial erased the release cut of a queued wall-jump tap',
  'Preserve that buffered press’s queued marker and release history through a temporary permission denial, clearing them on a new press, consumption, expiry or buffer clear.',
  ['queued wall intent rechecks jump_lock','native queued wall tap with pause','native queued wall tap without pause'])]
verified=[]
for issue,resolution,names in fixes:
    assert any(d['issue']==issue for d in reproductions['defects'])
    assert all(any(s['name']==name for s in wall['scenarios']) for name in names)
    verified.append({'issue':issue,'resolution':resolution,'retained_tests':names,
                     'before_fix_evidence':'combat_pc/tests/wall_defect_reproductions.json'})
limits=[
 'This is original MOKSHA behavior. Historical developer footage establishes airborne approach, upward wall travel and outward kick toward a higher opposite landing. Slide, exhaustion, rearm, timers, cancellation and every numerical value here are authored, not recovered Dead Cells v35 behavior.',
 'The actor ability defaults locked. Tests explicitly enable it. Supported contacts are dedicated upright positive-scale solid rectangle bodies; coplanar contiguous separate bodies can share an episode. One-way, mixed/multi-shape, rotated, negatively scaled and nonrectangular wall bodies are refused.',
 'Rearm is an explicit configurable policy. Default genuine separation/recontact plus delay and alternate real-ground/reset behavior are tested. No historical attack-reset exploit or universal source-game same-wall exhaustion rule is claimed.',
 'Contact queries and fixtures are bounded. No general tilemap, arbitrary polygon, spike/hazard system, rigid-body crowd or impossible crushing-geometry escape guarantee is established. Explicit wall_traversal_blocked metadata is tested.',
 'Shape observations retain committed PhysicsServer hits and independently test current upright rectangle geometry. A body transported to its pending Node pose can overlap the old committed pose without overlapping its current rectangle; this is reported rather than hidden by whole-body query exclusions. The inherited 0.06 px per-edge query inset is unchanged.',
 'These are headless actual-physics and parsed keyboard checks. Native visual/feel QA and final isolated-project boot are owned and reported separately. NPCs, parry, health/death and additional weapons are outside this pass.'
]
audit=ROOT.parent/'reference_sources/dead-cells-audit/WALL_TRAVERSAL_EVIDENCE.md'
report={'title':'MOKSHA combat PC gated wall traversal verification','milestone':5,'status':'passed',
 'generated_utc':datetime.now(timezone.utc).isoformat(),'controller_sha256':controller,'engine':wall['engine'],
 'production_hashes':wall['hashes'],'contract_sha256':sha(ROOT/'combat_pc/MOTOR_CONTRACT.md'),
 'reference_pin':'77c3ad263c4187ade6d048ba77bb61f79e6cec44','wall_evidence_sha256':sha(audit),
 'movement_profile':wall['movement_profile'],'combat_profile':wall['combat_profile'],
 'suites':{},'cross_rate_comparisons':comparisons,'scenarios':[],'verified_corrections':verified,
 'before_fix_evidence_sha256':sha(TESTS/'wall_defect_reproductions.json'),'limits':limits,
 'superseded_provisional_evidence':{'path':'combat_pc/tests/m5_provisional_e772','manifest_sha256':sha(provisional_dir/'manifest.json'),'all_26_files_byte_identical':True,'controller':provisional['controller']},
 'retained_native_boundary_capture':{'path':'combat_pc/tests/wall_native_regrab_boundary_e772.json','sha256':sha(TESTS/'wall_native_regrab_boundary_e772.json')},
 'wall_boundary_timing':{'at_definition':'First actual physics sample at or beyond the unchanged authored 0.16-second delay; that delay does not land exactly on either simulation grid.','before_index':'first eligible tick minus one','after_index':'first eligible tick plus one','profiles_unchanged_from_e772':True},
 'console_logs_sha256':logs,'preserved_evidence':{'recorded_test_results_and_trace_data_unchanged':True,'unchanged_original_paths':unchanged_files,'original_documentation_content_preserved':True,**preserved},
 'execution':'Actual physics callbacks, independently recorded after each actor tick. Traces include per-shape one-way classification, current and committed moving geometry, native key edges and semantic events. Input is centrally released between scenarios.',
 'compatibility_method':'Original M1–M4 executable harnesses copied to /tmp with only their output filename redirected to M5 names. Executable regression harnesses, recorded test results, per-tick traces and four ZIPs are unchanged; documentation/output-wording updates are classified separately.',
 'harness_clarifications':[
  'Carrier-offset measurements start after the initial probe gap is physically closed; normal contact push legitimately closes that gap.',
  'Blocked-carrier tests continue until actual obstruction, then stop carrier movement. No claim of escaping an indefinitely advancing crusher is made.',
  'Restricted upward passage first verifies that the forced owner with that restriction was accepted. Buffered landing explicitly has no air jump remaining.',
  'Ledge fixtures provide reachable headroom at both rates rather than sitting within hundredths of a pixel of the finite-run reach boundary.',
  'The allowed upward one-way fixture waits for actual foot clearance instead of assuming a fixed sampling duration is enough at both rates.'
 ]}
for name,pair in suites.items():
    report['suites'][name]={str(hz):{'scenarios':len(run['scenarios']),'assertions':run['checks'],'failures':len(run['failures']),
      'frames':sum(len(s['frames']) for s in run['scenarios']),'source_stable':True,
      'path':str((TESTS/f'{prefixes[name]}_{hz}hz.json').relative_to(ROOT)),
      'sha256':sha(TESTS/f'{prefixes[name]}_{hz}hz.json')} for hz,run in pair.items()}
for index,s in enumerate(wall['scenarios']):
    report['scenarios'].append({'name':s['name'],'passed_at':[120,60],
      'assertions':[a['label'] for a in s['assertions']],
      'traces':{str(hz):{'path':f'combat_pc/tests/wall_results_{hz}hz.json','json_pointer':f'/scenarios/{index}'} for hz in (120,60)}})
(ROOT/'combat_pc/wall_verification.json').write_text(json.dumps(report,indent=2)+'\n')
lines=['# Gated wall traversal verification','',
 f'**Passed at 120 Hz and 60 Hz:** {len(wall["scenarios"])} wall scenarios / {wall["checks"]} assertions per rate. All four prior movement, combat, drop/dive and ladder/vine suites also pass on the same controller. Ten runs have zero failures and clean engine logs.','',
 f'Controller SHA-256: `{controller}`. [Detailed evidence](wall_verification.json) pins the tested production files, harnesses, traces, profiles and console logs.','',
 '## Connected behavior','',
 '- Mirrored ground jump → wall approach → finite upward run → supported outward kick → higher opposite landing; separate run-to-slide-to-end and wall-to-ledge handoff with clear/blocked headroom.',
 '- Locked-by-default ability, host/main/input/facing gates, permitted and denied roll/jump/dive/melee transitions, committed kick, damage, reset, grace and regrab timing.',
 '- Same-contact allowance preservation across melee, actual separation/recontact policy, alternate ground-only policy, buffered landing rearm and coplanar collider seams. Actual air jump, dive and roll expenditure remains spent through wall attachment and kick.',
 '- Parsed input on exact recorded physics ticks, full Jump taps through hitpause, adjacent away/Jump, expiry and invalidation, and mirrored toward+Jump immediately before, at and after regrab eligibility.',
 '- Queued tap release across wait, hitpause and temporary host denial; no air spending while reserved; accepted ordinary jumps retain ascent over multiple ticks until separation/apex/replacement. Disabled input, reset, lost support and ability changes recheck or retire the request.',
 '- Thin walls at elevated kick speed, solid ceilings, permitted/restricted one-way passage, targeted drop/roll cleanup, dedicated scaled/static walls and explicit unsupported-shape refusals.',
 '- Moving, blocked, removed, disabled, rotated, replaced and teleported contacts; current/pending geometry, hurt-pause transport, blocked-surface metadata and repeated reset/replacement cycles on the same actor.','',
 '## Corrected defects','', 'The earlier e772 pass was provisional after native QA exposed a press just before regrab expiry; that revision and native capture are retained. The revised checks cover both the boundary and later physics ticks.','']
for issue in verified: lines.append('- **'+issue['issue']+'.** '+issue['resolution'])
lines += ['', 'Each has a retained before-fix trace or engine-error record in [defect reproductions](tests/wall_defect_reproductions.json) and passing final physical cases. No collision tolerance was loosened. Fixture corrections and geometry-observation distinctions are explicitly listed in the JSON.','',
 '## Cross-rate and preservation checks','',
 f'All {len(comparisons)} paired bounds pass: five wall measurements plus the unchanged 23 earlier bounds. Steady ascent independently equals profile speed × 0.15 seconds within 0.01 px. Phase timing allows one 60 Hz boundary step. The project setting remains 120 Hz; 60 Hz is a runtime test override.','',
 f'All {unchanged_files} earlier artifacts and all four M1–M4 ZIPs keep their recorded hashes. Five documentation/output-text updates are recorded separately: standalone wording in two Markdown summaries, one JSON summary and one report template, plus companion-archive instructions in TRACE_ARCHIVE.md. Before/after hashes and exact original content in the historical ZIP are verified; recorded test results, numeric data, trace data and executable test logic are unchanged. The 26 provisional e772 M5 files remain byte-for-byte intact. Compatibility outputs have separate M5 names. Regrab, grace and all movement/combat tuning remain unchanged.','',
 '## Scope','']
lines += ['- '+limit for limit in limits]
lines += ['', '## Reproduce','',
 'Use writable XDG data/cache/config locations, then run:', '', '```sh',
 'XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/wall_regression.gd -- --hz=120',
 'XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/wall_regression.gd -- --hz=60',
 '```', '',
 'Redirect each wall console to `combat_pc/tests/m5_wall_120.log` or `m5_wall_60.log`. For compatibility, copy the four immutable regression scripts to `/tmp`, replacing only their result filename with `movement_compat_m5_results_%dhz%s.json`, `combat_compat_m5_results_%dhz.json`, `traversal_compat_m5_results_%dhz.json`, or `climb_compat_m5_results_%dhz.json`; save matching `m5_<suite>_<rate>.log` files. `python3 combat_pc/tests/build_wall_report.py` rejects failed or stale runs, engine errors, missing physics samples, changed historical evidence, and exceeded rate bounds.','',
 'Traces: [wall 120 Hz](tests/wall_results_120hz.json), [wall 60 Hz](tests/wall_results_60hz.json), and eight `*_compat_m5_results_*hz.json` files indexed in the detailed evidence.','']
(ROOT/'combat_pc/wall_verification.md').write_text('\n'.join(lines))
print(f'PASS: {len(wall["scenarios"])} wall scenarios; five paired suites, {len(comparisons)} bounds, {unchanged_files} unchanged historical files, {len(preserved.get("documentation_updates",{}))} recorded documentation updates and four archives verified')
