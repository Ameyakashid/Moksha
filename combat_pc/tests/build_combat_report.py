"""Build the combat acceptance report from stable, paired real-physics traces."""
from pathlib import Path
import hashlib
import json
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / 'combat_pc/tests'

def read(path):
    return json.loads(path.read_text())

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

runs = {h: read(TESTS / f'combat_results_{h}hz.json') for h in (120, 60)}
compat = {h: read(TESTS / f'movement_compat_results_{h}hz.json') for h in (120, 60)}
baseline = read(ROOT / 'combat_pc/verification.json')
original_hashes = {
    'combat_pc/tests/movement_regression.gd': '290f297c0d06c2783597f72c162e0278ce82578789085c2d88921ede051e5ca4',
    'combat_pc/tests/results_120hz.json': '2000ec3933595abe2f69dc27639cf814e0ca1e4642b2e8239f80651cfa12de3d',
    'combat_pc/tests/results_60hz.json': '42cd2c0b9da37e7e92dc237736daf3428888ea897752a87669a3fdabc602b33e',
    'combat_pc/verification.md': 'a91707302f390b5cd12a9fcb29ac302a2733e220a38fc21af4d346f0e9694ae1',
    'combat_pc/verification.json': '8710915dca87bffd42d64af486ca2d014d2aeaf8cca30e0f70c349a71566bb08',
}
for path, expected in original_hashes.items():
    assert sha(ROOT / path) == expected, f'M1 baseline changed: {path}'
for suite in (runs, compat):
    for h, run in suite.items():
        assert not run['failures'], (h, run['failures'])
        assert run['production_hash_stable_during_run'], h
        for path, digest in run['hashes'].items():
            assert sha(ROOT / path.removeprefix('res://')) == digest, f'Stale report: {path}'
    assert suite[120]['hashes'] == suite[60]['hashes'], 'Rate pair used different code'
assert runs[120]['hashes']['res://combat_pc/player.gd'] == compat[120]['hashes']['res://combat_pc/player.gd']
assert [s['name'] for s in runs[120]['scenarios']] == [s['name'] for s in runs[60]['scenarios']]

comparisons = []
def compare(suite, scenario, key, tolerance, reason, suite_name):
    values = {h: next(s for s in suite[h]['scenarios'] if s['name'] == scenario)['measurements'][key] for h in suite}
    passed = abs(values[120] - values[60]) <= tolerance + 1e-12
    comparisons.append(dict(suite=suite_name, scenario=scenario, metric=key, value_120hz=values[120], value_60hz=values[60],
                            allowed_difference=tolerance, tolerance_reason=reason, passed=passed))
    assert passed, comparisons[-1]
for direction in (-1, 1):
    scenario = f'roll phases and held input {direction}'
    compare(runs, scenario, 'roll_seconds', 1/60, 'One 60 Hz sampled boundary', 'combat')
    compare(runs, scenario, 'roll_distance', runs[120]['combat_profile']['roll_start_speed']/60,
            'One 60 Hz step at authored maximum roll speed; opposite input held during recovery at both rates', 'combat')
compare(runs, 'held melee and late recovery buffer', 'attack_seconds', 1/60, 'One 60 Hz sampled phase completion', 'combat')
compare(runs, 'exclusive iframe end at nominal actor time', 'nominal_elapsed', 1e-12, 'Exact common profile endpoint, independently counted physics ticks', 'combat')
for previous in baseline['cross_rate_comparisons']:
    compare(compat, previous['scenario'], previous['key'], previous['allowed_difference'], previous['tolerance_reason'], 'movement_compatibility')

categories = {
    'Roll phases, collision and clearance': list(range(0, 5)) + [44],
    'Roll air budget, cancellation and cooldown': list(range(5, 10)) + [45, 46],
    'Melee phase permissions and cancellation': list(range(10, 16)),
    'Actual contact routing and identity': list(range(16, 23)) + [43],
    'Buffered input, local freeze and scene pause': list(range(23, 32)) + [41, 47, 48],
    'Receiving hits, i-frame bounds and resets': list(range(32, 41)) + [42],
}
assert sorted(i for group in categories.values() for i in group) == list(range(len(runs[120]['scenarios'])))
fixes = [
    {'issue': 'Close forward contact rejected when hurtbox overlaps strike origin', 'evidence_kind': 'actual pre-fix 120 Hz failure',
     'evidence': 'Actor x100, front target center104/width16 overlapped strike volume but received zero hits.',
     'resolution': 'Contact point uses target and sampled-strike intersection before forward-half-space and wall checks.',
     'acceptance_scenarios': [16, 17, 18, 19, 20]},
    {'issue': 'Exclusive roll i-frame endpoint gained one sampled tick', 'evidence_kind': 'actual pre-fix 120 Hz failure',
     'evidence': '24 advances at 120 Hz nominally reached .20 seconds; accumulated .19999999999999998 kept immunity and rejected damage.',
     'resolution': 'Combat comparisons absorb 1e-9-second arithmetic error; the exact .20 endpoint is outside immunity at both rates.',
     'acceptance_scenarios': [32, 33, 34, 35, 36]},
    {'issue': 'Hurt freeze embedded the actor in a rising carrier', 'evidence_kind': 'actual pre-fix 120 Hz failure',
     'evidence': 'Accepted damage discarded ground support before hitpause, allowing rising support to penetrate the frozen body.',
     'resolution': 'Temporary carrier transport survives hurt pause without granting floor budgets or changing recoil; detaches on resume.',
     'acceptance_scenarios': [42]},
    {'issue': 'Disabled held input and earlier release latch could create incorrect resumed input', 'evidence_kind': 'code review corrected before physical repro',
     'resolution': 'Disabled intent preserves physical held history. A new jump press supersedes the older release latch.',
     'acceptance_scenarios': [25, 26, 28, 29, 30]},
    {'issue': 'Paused carrier travel could leave a damaging swept trail on resume', 'evidence_kind': 'code review corrected before physical repro',
     'resolution': 'Paused transport refreshes prior strike center without damage samples; delayed confirmations while paused are rejected.',
     'acceptance_scenarios': [47]},
    {'issue': 'Effective permission snapshot did not expose all existing arbitration denials', 'evidence_kind': 'motor self-review corrected before final acceptance',
     'resolution': 'Committed active and hurt snapshots expose denied roll/attack requests; final tests assert these host-facing fields.',
     'acceptance_scenarios': [14, 42]},
]
limits = [
    'All roll, melee, damage-response and timing values are original MOKSHA tuning. No recovered Dead Cells motor values or executable parity are claimed.',
    'This is headless physical/input acceptance. Native animation and feel review are reported separately by the lab owner.',
    'No health/death system, enemy AI, combo expansion, parry or additional combat actions are claimed.',
    'Contact geometry is verified against axis-aligned passive rectangles, a real existing crate and solid-wall occlusion; arbitrary rotated or concave hurtbox contact-point fidelity is not established.',
    'The suite covers selected ordinary and adversarial geometry/input flows, not every arbitrary scene or profile value. Continued unavoidable crushing is outside this milestone.',
    'The legacy crate launch uses the real scene and PhysicsServer impulse integration. Its random spin and exact trajectory are not asserted.',
]
report = {
    'title': 'MOKSHA combat PC milestone 2 verification', 'status': 'passed',
    'generated_utc': datetime.now(timezone.utc).isoformat(), 'engine': runs[120]['engine'],
    'reference_boundary': 'Pinned Dead Cells audit supports interface intent. Algorithms, numerical values and cancellation policy are original MOKSHA.',
    'reference_pin': '77c3ad263c4187ade6d048ba77bb61f79e6cec44',
    'production_hashes': runs[120]['hashes'],
    'reference_and_contract_hashes': {p: sha(ROOT/p) for p in ['combat_pc/reference/DEAD_CELLS_COMBAT_AUDIT.md','combat_pc/reference/DEAD_CELLS_MOVEMENT_AUDIT.md','combat_pc/MOTOR_CONTRACT.md']},
    'movement_profile': runs[120]['movement_profile'], 'combat_profile': runs[120]['combat_profile'],
    'rates': {}, 'movement_compatibility': {}, 'cross_rate_comparisons': comparisons,
    'coverage_groups': {name: [runs[120]['scenarios'][i]['name'] for i in indices] for name,indices in categories.items()},
    'scenarios': [], 'verified_fixes': fixes, 'limits': limits,
    'preserved_milestone1': {'files': original_hashes, 'all_byte_identical': True,
        'archive': '../moksha-backups/MOKSHA-Combat-PC-M1-20261004.zip',
        'archive_sha256': sha(ROOT.parent/'moksha-backups/MOKSHA-Combat-PC-M1-20261004.zip')},
    'compatibility_execution': 'Exact original movement harness copied to /tmp with only output filename changed from results_%dhz%s.json to movement_compat_results_%dhz%s.json; original harness and all M1 traces/reports remain byte-identical.',
    'pre_fix_evidence': 'combat_pc/tests/combat_defect_reproductions.json',
}
for h in runs:
    for key, suite, prefix in [('rates',runs,'combat_results'),('movement_compatibility',compat,'movement_compat_results')]:
        run=suite[h]
        report[key][str(h)]={'scenarios':len(run['scenarios']),'assertions':run['checks'],'failures':len(run['failures']),
                            'frames':sum(len(s['frames']) for s in run['scenarios']),'stable_sources':True,
                            'path':f'combat_pc/tests/{prefix}_{h}hz.json','sha256':sha(TESTS/f'{prefix}_{h}hz.json')}
for index,scenario in enumerate(runs[120]['scenarios']):
    report['scenarios'].append({'name':scenario['name'],'passed_at':[120,60], 'assertions':[a['label'] for a in scenario['assertions']],
       'trace_pointers':{str(h):{'path':f'combat_pc/tests/combat_results_{h}hz.json','json_pointer':f'/scenarios/{index}'} for h in runs}})
(ROOT/'combat_pc/combat_verification.json').write_text(json.dumps(report,indent=2)+'\n')

r=report['rates']['120']; m=report['movement_compatibility']['120']
lines=[
'# MOKSHA combat PC milestone 2 verification','',
f'**Passed at 120 Hz and 60 Hz:** {r["scenarios"]} connected combat scenarios / {r["assertions"]} assertions per rate, plus all {m["scenarios"]} original movement scenarios / {m["assertions"]} assertions per rate. Every run has zero failures and stable source hashes.','',
'Both suites used actual Godot 4.6.3 physics callbacks, the production player scene, collision sweeps and space queries. The native-input case uses parsed keyboard events and the actor’s own `_physics_process`. The original project setting remains 120 Hz; 60 Hz is a process-local override.','',
f'Controller SHA-256: `{report["production_hashes"]["res://combat_pc/player.gd"]}`. Exact profile, adapter, fixture, harness and legacy-prop hashes are in [combat_verification.json](combat_verification.json).','',
'## Coverage','',
]
for name,indices in categories.items():
    lines.append(f'- **{name}:** '+ '; '.join(runs[120]['scenarios'][i]['name'] for i in indices)+'.')
lines += ['', 'The compatibility rerun covers the prior connected run/reversal/jump/crouch/one-way/slope/ledge/reset flows. It uses the unchanged movement assertions and writes separate M2 traces; it is not counted as new combat coverage.','',
'## Defects corrected and retested','']
for fix in fixes:
    lines.append(f'- **{fix["issue"]}.** {fix.get("evidence", "")} {fix["resolution"]} Evidence: {fix["evidence_kind"]}.'.replace('  ',' '))
lines += ['','Pre-fix physical failures and controller hashes are retained in [combat_defect_reproductions.json](tests/combat_defect_reproductions.json). Collision tolerances were retained. The crate test waits for two actual solver steps after the impulse before checking substantial forward speed and displacement.','',
'## Rate comparison','',
'| Measurement | 120 Hz | 60 Hz | Bound |','|---|---:|---:|---:|']
for c in comparisons:
    if c['suite']=='combat':
        lines.append(f'| {c["scenario"]}: {c["metric"]} | {c["value_120hz"]:.6f} | {c["value_60hz"]:.6f} | {c["allowed_difference"]:.6f} |')
lines += ['','Roll-distance tolerance is one 60 Hz step at the authored maximum roll speed. Duration tolerance is one 60 Hz sampled boundary. The .20-second exclusive immunity endpoint is checked using independently counted physics ticks. All eight prior movement cross-rate bounds also pass unchanged.','',
'## Provenance and limits','',
'The [combat audit](reference/DEAD_CELLS_COMBAT_AUDIT.md) uses Dead Cells repository pin `77c3ad263c4187ade6d048ba77bb61f79e6cec44`. It supports capability and weapon-phase architecture; the relevant motor and weapon-phase implementation bodies and tuning are absent. Tests use the authored [motor contract](MOTOR_CONTRACT.md) and MOKSHA profile resources.','']
lines += ['- '+limit for limit in limits]
lines += ['','All five original M1 harness/report/trace artifacts retain their recorded SHA-256 values. The preserved M1 ZIP SHA-256 is `'+report['preserved_milestone1']['archive_sha256']+'`.','',
'## Reproduce','',
'Run from the project directory with writable XDG locations:','',
'```sh',
'mkdir -p /tmp/moksha-combat-test-data /tmp/moksha-combat-test-cache /tmp/moksha-combat-test-config',
'export XDG_DATA_HOME=/tmp/moksha-combat-test-data',
'export XDG_CACHE_HOME=/tmp/moksha-combat-test-cache',
'export XDG_CONFIG_HOME=/tmp/moksha-combat-test-config',
'godot --headless --fixed-fps 120 --path . --script combat_pc/tests/combat_regression.gd -- --hz=120',
'godot --headless --fixed-fps 60 --path . --script combat_pc/tests/combat_regression.gd -- --hz=60',
'```','',
'For compatibility runs, copy `combat_pc/tests/movement_regression.gd` to `/tmp/moksha_m2_movement_compat.gd` and change only its output filename `results_%dhz%s.json` to `movement_compat_results_%dhz%s.json`. Run the same two commands with that temporary script. `--fixed-fps` accelerates wall-clock execution while real physics frames and solver calls remain active.','',
'Rebuild the paired report with `python3 combat_pc/tests/build_combat_report.py`; it refuses failures, stale or differing source hashes, changed M1 artifacts, or exceeded cross-rate bounds.','',
'Full traces: [combat 120 Hz](tests/combat_results_120hz.json), [combat 60 Hz](tests/combat_results_60hz.json), [movement compatibility 120 Hz](tests/movement_compat_results_120hz.json), [movement compatibility 60 Hz](tests/movement_compat_results_60hz.json).','',
]
(ROOT/'combat_pc/combat_verification.md').write_text('\n'.join(lines))
print(f'PASS: {len(runs[120]["scenarios"])} combat scenarios; paired combat and movement provenance verified; {len(comparisons)} cross-rate bounds passed')
