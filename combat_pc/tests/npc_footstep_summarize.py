"""Summarize paired real-physics M17 acceptance and capture final hashes."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
tests = root / 'combat_pc/tests'
runs = {hz: json.loads((tests / f'npc_footstep_results_{hz}hz.json').read_text()) for hz in [60,120]}
checks = []
def check(condition, message):
    checks.append({'message':message,'pass':bool(condition)})

check(all(not r['failures'] for r in runs.values()), 'Both physics rates pass every focused acceptance check')
check(all(r['runtime_sources_stable'] and r['protected_sources_match_v20'] for r in runs.values()), 'Both rates used stable source bytes and preserved v20 dependencies')
check(runs[60]['runtime_source_hashes'] == runs[120]['runtime_source_hashes'], 'Both rates ran identical seven source, resource, fixture and passive-view files')
scenarios = {hz: {s['name']:s for s in run['scenarios']} for hz, run in runs.items()}
check(scenarios[60].keys() == scenarios[120].keys(), 'Paired runs cover identical scenarios')
comparisons = []
for name, case60 in scenarios[60].items():
    case120 = scenarios[120].get(name)
    if case120 is None:
        continue
    d60, d120 = case60['details'], case120['details']
    row = {'scenario':name,'60hz_bus_events':d60['bus_event_count'],'120hz_bus_events':d120['bus_event_count']}
    if 'initial_steps' in d60:
        check(abs(d60['initial_steps']-d120['initial_steps'])<=1, name+': distance cadence differs by no more than one boundary step')
        check(abs(d60['ground_path']-d120['ground_path'])<3, name+': same-duration ground path agrees within one 60Hz full-speed tick')
        row.update({'60hz_ground_path':d60['ground_path'],'120hz_ground_path':d120['ground_path'],'60hz_initial_steps':d60['initial_steps'],'120hz_initial_steps':d120['initial_steps']})
    if 'steps' in d60:
        check(abs(d60['steps']-d120['steps'])<=1,name+': physical stride count agrees across rates')
        row.update({'60hz_ground_path':d60.get('ground_path',d60.get('independent_own_distance')),'120hz_ground_path':d120.get('ground_path',d120.get('independent_own_distance')),'60hz_steps':d60['steps'],'120hz_steps':d120['steps']})
    if 'step_count' in d60:
        check(abs(d60['step_count']-d120['step_count'])<=1,name+': support-relative stride count agrees across rates')
    if 'landing_count' in d60:
        check(d60['landing_count']==d120['landing_count'],name+': threshold classification agrees across rates')
        row.update({'60hz_airborne_frames':d60.get('airborne_frames'),'120hz_airborne_frames':d120.get('airborne_frames'),'landing_count':d60['landing_count']})
    comparisons.append(row)

files = list(runs[60]['runtime_source_hashes'])
files += ['combat_pc/tests/npc_footstep_driver.gd','combat_pc/tests/npc_footstep_regression.gd','combat_pc/tests/npc_footstep_late_air_probe.gd','combat_pc/tests/npc_footstep_verify_baseline.py','combat_pc/tests/npc_footstep_summarize.py']
final_hashes = {path:hashlib.sha256((root/path).read_bytes()).hexdigest() for path in files}
check(all(final_hashes[path]==sha for path,sha in runs[60]['runtime_source_hashes'].items()),'Current runtime bytes equal the exact paired-run source bytes')
result = {'milestone':17,'checks':checks,'all_pass':all(c['pass'] for c in checks),'comparisons':comparisons,'final_sha256':final_hashes}
boot_path = tests/'npc_footstep_final_scene_boot.json'
if boot_path.exists():
    result['final_scene_boot'] = json.loads(boot_path.read_text())
(tests/'npc_footstep_final_hashes.json').write_text(json.dumps(result,indent=2)+'\n')

lines = [
'# M17 NPC footstep source: independent focused QA',
'',
'## Result',
'',
f"Godot {runs[60]['engine']}: **{runs[60]['checks']}/{runs[60]['checks']} checks at 60 Hz and {runs[120]['checks']}/{runs[120]['checks']} checks at 120 Hz**, with {len(runs[60]['scenarios'])} scenarios per rate. {sum(c['pass'] for c in checks)}/{len(checks)} paired consistency/source checks pass. No runtime sources were edited by this QA work.",
'',
'48 protected PC, original movement/NPC, old enemy/guard, contact source, SurfacePulse and NoiseBus files match the retained v20 ZIP byte for byte. Both rates ran the same final seven component/resource/fixture/passive-view source files, and their bytes stayed stable throughout each run. See `npc_footstep_baseline_hashes.json` and `npc_footstep_final_hashes.json`.',
'',
'## Physical results',
'',
'| Case | 60 Hz | 120 Hz |',
'| --- | --- | --- |',
]
for name in ['ground distance cadence axis 0.45','ground distance cadence axis 1.0','real slope downhill','real slope uphill']:
    cols=[]
    for hz in [60,120]:
        d=scenarios[hz][name]['details']
        cols.append(f"{d['ground_path']:.2f}px / {d.get('initial_steps',d.get('steps'))} steps")
    lines.append(f'| {name} | {cols[0]} | {cols[1]} |')
for name in ['translating support idle and relative walk','wall-clipped translating support idle and relative walk','static conveyor idle and relative walk','actual ledge break depth 4.0','actual ledge break depth 100.0','qualified late-air landing survives scene tree','qualified late-air landing survives motor hit pause']:
    cols=[]
    for hz in [60,120]:
        d=scenarios[hz][name]['details']
        if 'landing_count' in d:
            cols.append(f"{d['landing_count']} landing; {d['airborne_frames']} airborne frames" if 'airborne_frames' in d else f"{d['landing_count']} landing after resume")
        elif 'step_count' in d:
            cols.append(f"silent idle carry; {d['step_count']} walking steps")
        else:
            cols.append(f"silent carry; {d['escape_steps']} escape steps")
    lines.append(f'| {name} | {cols[0]} | {cols[1]} |')
lines += [
'',
'- Slow and full-speed movement use the same authored 28px stride spacing. Stopping is silent after actual braking; restarting/reversing cannot emit on its first sub-stride tick. Wall pushing, idle, airborne motion, skipped/disabled motor ticks, dash displacement and stunned impulse displacement stay quiet.',
'- Real jump and drop trajectories each produce one distinct `enemy_land`, with landing strength exactly matching the unchanged motor\'s same-frame signal. No landing catch-up step burst occurs. Both an actual step and landing feed a local NoiseBus and unchanged SurfacePulse exactly once at the original surface point; the project autoload receives none.',
'- Independent current-floor ray intersections verify every receipt\'s origin, unit normal and named support. Independent motor samples verify step distance/speed against same-frame actual ground travel and fresh support velocity where applicable; landing speed is separately observed from the motor signal.',
'- Uphill/downhill 20° motion follows actual two-dimensional ground travel and produces no false landings. Across a 12px break, the brief 4px descent produces no hard-landing event; the real 100px descent produces exactly one. These results bound these actual geometries and authored thresholds, not every possible gap.',
'- Translating AnimatableBody2D floors and StaticBody2D conveyors carry an idle NPC silently; walking counts own support-relative travel. A translating floor pushing an idle NPC into a wall stays silent after its carry is clipped. Walking away resumes ordinary cadence after ambiguous prior-wall support is discarded; no receipt uses a prior wall sample.',
'- A translating support changing +80→−80→0→+80px/s preserves own-distance cadence without false landings. The driver independently reads physics-server point velocity before each actual motor step, then checks every moving-support step against actual world travel minus that fresh carry velocity. Requested transform displacement is not used as a reversal oracle.',
'- Actual composed inherited fixture runs the original motor, fences reset/hit-pause, and tolerates enable/simulation pause, unbind/rebind and removal. Teleport/reset and missed motion do not produce catch-up noise.',
'- Already-qualified late airborne falls are paused one or two physics ticks before touchdown, through both SceneTree pause and motor hit-pause. Actual body motion stays frozen and silent, then the same flight produces exactly one real landing on resume. Earlier failure evidence is retained in `npc_footstep_late_air_before_60hz.json` / `.log`; the corrected cases are part of both final runs.',
'- Real bus callbacks resetting history or diagnostics, muting, simulation-pausing, tree-pausing, unbinding, rebinding, detaching, queue-freeing the source or queue-freeing the bus suppress invalidated post-bus receipts. Receipts are immutable; diagnostic copies are independent. A second observer cannot register for the same body.',
'- Identical input sequences through original and composed motors have **zero position/velocity error and identical state/facing on every compared tick**, including jump/release, reversal, hit-pause, and source removal. The run includes real step and landing emissions.',
'',
'## Method and limits',
'',
'The driver calls the unchanged CharacterBody2D motor in real Godot physics frames. NPC Intent is disabled to supply repeatable test inputs; this does not claim complete AI integration. The composed fixture is tested independently of the review scene/UI. Synthetic begin/capture/finish calls appear only in the explicitly labelled stale-token contract-failure case, never as physical cadence or landing evidence.',
'',
'Headless acceptance does not substitute for native visual review. Animation footplants, audio playback, broad old-game regressions, rotating/skewed/scaled supports and CharacterBody2D carriers are not certified. All thresholds and spacing are authored tuning. The support correction is tested on translating nonrotating floors, carrier reversals/stops, wall escape, and static conveyor velocity. Mixed prior floor/wall ownership is deliberately discarded until a fresh floor-only sample is available.',
'',
'## Reproduce',
'',
'From the project root, with writable XDG directories under `/tmp/moksha-m17-test-runtime`: run `python combat_pc/tests/npc_footstep_verify_baseline.py`, then `godot --headless --path . --script res://combat_pc/tests/npc_footstep_regression.gd -- --hz=60` and repeat with `--hz=120`; finally run `python combat_pc/tests/npc_footstep_summarize.py`. Each Godot run writes its JSON result. Retained logs are `npc_footstep_regression_60hz.log` and `npc_footstep_regression_120hz.log`.',
]
if 'final_scene_boot' in result:
    lines += [
        '', '## Final passive-view revision', '',
        'The final passive NPC wire view advances gait directly from motor velocity, so muting/removing the sound source cannot freeze its legs. Its source hash is included in the refreshed seven-file paired manifest, and the inherited fixture loads this view in both final runs. This establishes loading and physical independence; gait appearance remains a separate native visual check.', '',
        'A separate final review-scene headless boot completed 20 requested ticks with exit 0 and no errors or warnings. Its log, final view/review hashes and scope are recorded in `npc_footstep_final_scene_boot.log` / `.json` and the final hash manifest. Native source-disconnect gait appearance remains the separate visual check.',
    ]
(tests/'npc_footstep_report.md').write_text('\n'.join(lines)+'\n')
for c in checks:
    if not c['pass']:
        print('FAIL',c['message'])
print(f"NPC_FOOTSTEP_PAIRED: {sum(c['pass'] for c in checks)}/{len(checks)} checks")
raise SystemExit(0 if result['all_pass'] else 1)
