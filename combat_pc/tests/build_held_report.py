"""Independent M10 held-input acceptance auditor.

Only this milestone's two reports are written. Historical validators are loaded
without their writers or bytecode side effects. Cases, profile boundaries and
identity/contact rules below are reviewed independently of the result files.
"""
from __future__ import annotations
from collections import Counter
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / 'combat_pc/tests'
RATES = (120, 60)
OLDER_SUITES = ('movement', 'combat', 'traversal', 'climb', 'wall', 'hard_landing', 'soft_slope', 'shield', 'combo')
FILES = {'held': 'held_results', **{f'{s}_compatibility': f'{s}_compat_m10_results' for s in OLDER_SUITES}}
PINNED = {}
SHA256 = re.compile(r'[0-9a-f]{64}\Z')
REVIEWED_CONTROLLER_SHA256 = 'c7c18b726210665df2304ff4aba190edda54816eaeb6fded1b44a63751f1987d'
REVIEWED_CONTRACT_SHA256 = '3d2e7d7f4c40f127e94488cb009e5a667969632a82f1bb5145fa46cb081afd60'
# Set only after review of the final complete harness; an unset pin closes publication.
REVIEWED_HARNESS_SHA256 = 'bb9ae076bf1738af164f78f2a48674d8a1dc17a528b9e69dcb852f6f7539b4f9'
PRESERVATION_MANIFEST_SHA256 = 'beaad6a728da1b74d469b9a28b6be0aa20f8f1b9a35239028ea6313dae289cf6'
M9_ARCHIVE_SHA256 = '605b6e3a802b3fa8e0201cbaddb72e48d5f1986f9976c9a31037394233417c93'

REQUIRED_M10_GROUPS = {
 'repeat': tuple(f'baseline {m} {c} remains fresh only' for m in ('null', 'fresh') for c in ('fallback', 'chain')) +
   tuple(f'held repeat {c} direction{d}' for c in ('fallback', 'chain') for d in (-1, 1)) +
   ('repeat release preserves no synthetic request', 'repeat release preserves explicit fresh request'),
 'charge': tuple(f'starter charge thrust {c} direction{d}' for d in (-1, 1) for c in ('whiff', 'target', 'occluded')),
 'boundaries': tuple(f'charge release {e}' for e in ('before_branch', 'branch_tick', 'after_branch', 'before_ready', 'ready_tick', 'after_ready')),
 'gates': tuple(f'{m} hold retires on {a}' for m in ('repeat', 'charge') for a in ('can_attack', 'disable', 'roll', 'jump', 'shield', 'hurt', 'forced', 'reset')) +
   tuple(f'full charge yields to simultaneous {a}' for a in ('roll', 'jump', 'shield')),
 'pause': ('charge hitpause continued hold', 'charge hitpause release tap'),
 'callbacks': tuple(f'{b} callback replaces {r}' for b in ('charge_started', 'charge_committed') for r in ('reset', 'hurt', 'forced', 'configuration')),
 'motion': tuple(f'air charge preserves fall and budgets {e}' for e in ('rising', 'falling')) + tuple(f'charge reversal and thin wall direction{d}' for d in (-1, 1)),
 'resources': tuple(f'input configuration round trip retires {p}' for p in ('pending', 'loading', 'active')) +
   tuple(f'live repeat snapshot survives rejected edge {p}' for p in ('too_early', 'queue_full')) +
   ('charge resource snapshot same-value assignment', 'charge resource snapshot in-place edit',
    'two actors share input configuration without runtime cross-talk', 'finished held melee configuration change preserves independent shield', 'fresh-only strike has no inherited held origin'),
 'native': ('parsed held input release during pause repeat', 'parsed held input release during pause charge', 'same-callback release repress cannot preserve charge hold'),
 'props': tuple(f'real charged thrust crate and noise direction{d}' for d in (-1, 1)),
 'locks': tuple(f'{m} input versus {o}' for m in ('repeat', 'charge') for o in ('simultaneous', 'nonholdable_shield')) + tuple(f'initial denied {m} press {u}' for m in ('repeat', 'charge') for u in ('before_deadline', 'after_deadline')) +
   ('repeat pending expiry cannot retry after longer reuse lock', 'starter reuse lock closes charge branch without backlog',
    'shield lock rejects held starter without parallel loading', 'charge live movement and turning permissions intersect'),
 'integration': tuple(f'charge and thrust stay supported on slope {g:.1f}' for g in (-1, 1)) +
   ('complete charge remains crouched under real low roof', 'charge landing soft retires or preserves owner', 'charge landing hard retires or preserves owner',
    'paused charging carrier moving', 'paused charging carrier removed') + tuple(f'loading charge yields to physical {a}' for a in ('air_jump', 'dive', 'climb', 'wall')),
 'contacts': tuple(f'charged physical callback reset at {t}' for t in ('strike_confirmed', 'hitpause_started', 'receiver', 'contact_confirmed')) + ('charged strike confirms two actual targets once each',),
 'limits': tuple(f'minimum valid phase retains charge opportunity {s}' for s in ('starter', 'thrust', 'both_with_pause')) +
   tuple(f'invalid held configuration refuses {v}' for v in ('zero_charge', 'nonfinite_charge', 'branch_after_completion', 'missing_strike', 'zero_repeat_restart')) +
   tuple(f'fresh presses during busy charge episode {p}' for p in ('starter', 'loading', 'thrust')) +
   tuple(f'denied readiness replacement preserves charge {a}' for a in ('roll', 'jump', 'shield')) +
   ('charging one-way support yields to targeted drop', 'same actor alternates held modes through reset without stale authority'),
}
REQUIRED_M10_CASES = tuple(n for cases in REQUIRED_M10_GROUPS.values() for n in cases)

class VerificationError(RuntimeError): pass

def require(condition, message):
    if not condition: raise VerificationError(str(message))

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()

def display(path):
    p = Path(path).resolve()
    return str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p)

def pin(path, expected=None):
    path = Path(path).resolve()
    require(path.is_file(), f'Missing evidence: {path}')
    digest = sha(path)
    if expected is not None:
        require(isinstance(expected, str) and SHA256.fullmatch(expected), f'Invalid digest: {path}')
        require(digest == expected, f'Hash mismatch: {path}; expected {expected}, found {digest}')
    require(path not in PINNED or PINNED[path] == digest, f'Evidence changed while reading: {path}')
    PINNED[path] = digest
    return digest

def unique_object(pairs):
    result = {}
    for k, v in pairs:
        require(k not in result, f'Duplicate JSON key: {k}')
        result[k] = v
    return result

def read(path):
    pin(path)
    def invalid(value): raise VerificationError(f'Nonfinite JSON value {value}: {path}')
    overflow=[]
    def finite_float(value):
        result=float(value)
        if math.isfinite(result):return result
        marker={'rejected_nonfinite_json_number':value};overflow.append(marker);return marker
    result=json.loads(Path(path).read_text(), object_pairs_hook=unique_object, parse_constant=invalid, parse_float=finite_float)
    # Godot serializes the deliberately invalid INF configuration as 1e99999.
    # Preserve that token symbolically, and permit it only at this rejected-input
    # leaf. Every actor clock, measurement and admitted profile stays finite.
    allowed=[s.get('input_profile_at_finish',{}).get('charge_seconds') for s in result.get('scenarios',[])
             if s.get('name')=='invalid held configuration refuses nonfinite_charge'] if isinstance(result,dict) else []
    require(all(any(marker is leaf for leaf in allowed) for marker in overflow),f'Nonfinite JSON number outside the explicit rejected configuration: {path}')
    return result

def number(value, context):
    require(type(value) in (int, float) and math.isfinite(value), f'Nonfinite/non-numeric value: {context}: {value}')
    return float(value)

def close(actual, expected, tolerance, context):
    require(abs(number(actual, context) - number(expected, context)) <= tolerance,
            f'{context}: {actual} differs from {expected} by more than {tolerance}')

def project_path(name):
    require(isinstance(name, str), 'Invalid project path')
    p = (ROOT / name).resolve()
    require(p.is_relative_to(ROOT), f'Path escapes project: {name}')
    return p

def resource_path(name):
    require(isinstance(name, str) and name.startswith('res://'), f'Invalid resource path: {name}')
    return project_path(name.removeprefix('res://'))

def read_compact_history(path):
    """Prior trace uses here only compare case specifications; never run writers."""
    result=read(path)
    if 'scenarios' in result:
        for scenario in result['scenarios']:
            for key in ('frames','strike_samples','physical_contact_receipts','physical_target_receipts','effect_reports','effect_requests','incoming','noises'):
                scenario.pop(key,None)
    return result


def discard_audited_frames(run,complete=False):
    for scenario in run['scenarios']:
        scenario['_audited_frame_count']=len(scenario['frames'])
        del scenario['frames']
        if complete:
            for key in ('strike_samples','physical_contact_receipts','physical_target_receipts','effect_reports','effect_requests','incoming','noises','events','measurements'):
                scenario.pop(key,None)


def load_preserved_validators():
    path = TESTS / 'build_combo_report.py'; pin(path)
    spec = importlib.util.spec_from_file_location('preserved_m9_acceptance', path)
    m9 = importlib.util.module_from_spec(spec); spec.loader.exec_module(m9)
    for name in ('require', 'sha', 'pin', 'read', 'number', 'close', 'project_path', 'resource_path'):
        setattr(m9, name, globals()[name])
    m9.PINNED = PINNED; m9.VerificationError = VerificationError
    m9.read = read_compact_history
    m8, m7 = m9.load_preserved_validators()
    return m9, m8, m7

def verify_preservation():
    pin(TESTS / 'held_preserved_evidence.json',PRESERVATION_MANIFEST_SHA256)
    p = read(TESTS / 'held_preserved_evidence.json')
    require(p['milestone'] == 10 and len(p['files']) == 518 and len(p['snapshots']) == 9, 'Wrong historical inventory')
    require(p['current_mismatches_at_capture'] == [], 'Historical capture contains exceptions')
    require(p['baseline_snapshot_sha256'] == M9_ARCHIVE_SHA256, 'M9 archive changed')
    for name, digest in p['files'].items(): pin(project_path(name), digest)
    for name, digest in p['snapshots'].items():
        target = (ROOT / name).resolve()
        require(target.parent == ROOT.parent / 'moksha-backups' and target.suffix == '.zip', 'Invalid snapshot location')
        pin(target, digest)
    return p

def verify_redirects():
    rows = read(TESTS / 'held_compatibility_redirects.json')
    require(set(rows) == set(OLDER_SUITES), 'Incomplete historical redirect inventory')
    for suite, row in rows.items():
        p = project_path(row['original_harness']); pin(p, row['original_sha256'])
        content = p.read_text()
        require(content.count(row['old_output']) == 1, f'Ambiguous redirect: {suite}')
        suffix = '%dhz%s.json' if suite == 'movement' else '%dhz.json'
        expected = f'res://combat_pc/tests/{suite}_compat_m10_results_{suffix}'
        require(row['new_output'] == expected, f'Wrong output-only redirect: {suite}')
        require(hashlib.sha256(content.replace(row['old_output'], expected, 1).encode()).hexdigest() == row['redirected_sha256'], f'Redirect changed test logic: {suite}')
        if 'redirected_harness' in row: pin(project_path(row['redirected_harness']), row['redirected_sha256'])
    return rows

def verify_run(run, suite, hz, m7):
    context = f'{suite}/{hz}'
    require(type(run['physics_hz']) is int and run['physics_hz'] == hz, f'Wrong rate: {context}')
    milestones = {'held': 10, 'combo_compatibility': 9, 'shield_compatibility': 8, 'soft_slope_compatibility': 7}
    if suite in milestones:
        require(run['selected_group'] == '' and run['milestone'] == milestones[suite], f'Filtered/wrong-milestone run: {context}')
    require(run['production_hash_stable_during_run'] is True and run['failures'] == [], f'Failed/unstable run: {context}')
    start, end = run['starting_hashes'], run['hashes']
    require(start and end and all(end.get(k) == v for k, v in start.items()), f'Start/end drift: {context}')
    if suite not in ('movement_compatibility', 'combat_compatibility'): require(start == end, f'Incomplete source inventory: {context}')
    for name, digest in end.items(): pin(resource_path(name), digest)
    require(end['res://combat_pc/player.gd'] == REVIEWED_CONTROLLER_SHA256, f'Wrong controller: {context}')
    required = {'res://combat_pc/player.gd', 'res://combat_pc/player.tscn', 'res://combat_pc/resources/movement_profile.gd', 'res://combat_pc/resources/movement_profile.tres'}
    if suite == 'held':
        required |= {'res://project.godot', 'res://scripts/sensory/noise_bus.gd', 'res://prop.gd', 'res://scenes/props/crate.tscn', 'res://resources/tuning/prop_tuning.gd', 'res://resources/tuning/crate_default.tres'}
        required |= {'res://combat_pc/' + n for n in ('tests/held_regression.gd', 'tests/combo_regression.gd', 'tests/shield_regression.gd',
          'tests/soft_slope_regression.gd', 'tests/soft_slope_probe_player.gd', 'resources/melee_input_profile.gd', 'resources/held_repeat.tres',
          'resources/held_charge.tres', 'resources/melee_chain.gd', 'resources/melee_step.gd', 'resources/light_chain.tres',
          'resources/combat_profile.gd', 'resources/combat_profile.tres', 'resources/shield_profile.gd', 'resources/shield_profile.tres',
          'components/contact_adapter.gd', 'components/shield_contact_adapter.gd', 'components/climbable.gd', 'components/climbable.tscn', 'fixtures/slope_course.gd', 'fixtures/slope_course.tscn', 'fixtures/contact_target.gd', 'fixtures/contact_target.tscn')}
        required |= {'res://' + str(p.relative_to(ROOT)) for p in (ROOT / 'combat_pc/visuals').glob('*.gd')}
    require(required <= end.keys(), f'Required source missing: {context}: {required - end.keys()}')
    ss = run['scenarios']; require(ss and len({s['name'] for s in ss}) == len(ss), f'Empty/duplicate cases: {context}')
    total, continuity = 0, {}
    for s in ss:
        require(type(s['checks']) is int and s['checks'] == len(s['assertions']) > 0 and s['failures'] == 0, f'Case count/failure: {context}/{s["name"]}')
        require(all(a['passed'] is True and a['label'] for a in s['assertions']), f'Bad assertion: {context}/{s["name"]}')
        total += s['checks']
        continuity[s['name']] = m7.verify_continuity(s, 'soft_slope' if suite in milestones else suite, hz)
    require(total == run['checks'], f'Run assertion mismatch: {context}')
    log = TESTS / f'm10_{suite.removesuffix("_compatibility")}_{hz}.log'; pin(log)
    txt = log.read_text(); require(not re.search(r'SCRIPT ERROR|ERROR:|FAIL:|WARNING:', txt), f'Engine diagnostic: {log}')
    lines = re.findall(r'MOKSHA [^\n]*?(\d+)Hz: (\d+) scenarios, (\d+) checks, (\d+) failures', txt)
    require(len(lines) == 1 and tuple(map(int, lines[0])) == (hz, len(ss), total, 0), f'Incomplete/repeated log: {log}')
    return continuity, {display(log): PINNED[log.resolve()]}

def event_rows(s, label): return [e for e in s['events'] if e['event'] == label]
def starts(s): return event_rows(s, 'attack_started')
def charged(s): return [e for e in starts(s) if e['data']['charge_role'] == 'charged']
def active_seconds(s, first, last):
    require(type(first) is int and type(last) is int and 0 <= first <= last <= len(s['frames']), 'Invalid actor interval')
    return sum(f['delta'] for f in s['frames'][first:last] if f['before']['hitpause_remaining'] <= 0)
def observed_callback(s, row, context):
    require(type(row['tick']) is int and 1 <= row['tick'] <= len(s['frames']), f'Invalid physical tick: {context}')
    require(row['engine_tick'] == s['frames'][row['tick'] - 1]['engine_tick'], f'Physical receipt not tied to actual callback: {context}')

def definition(s, start, primary):
    d = start['data']; role = d['charge_role']
    if role: return s['input_profile_at_start']['charge_starter' if role == 'starter' else 'charge_strike']
    if d['step_index'] >= 0: return s['melee_chain']['steps'][d['step_index']]
    c = primary['combat_profile']
    return {'windup_seconds': c['attack_windup_seconds'], 'active_seconds': c['attack_active_seconds'], 'recovery_seconds': c['attack_recovery_seconds'],
            'strike_size': c['strike_size'], 'damage': c['strike_damage'], 'impulse': c['strike_impulse'], 'prop_launch_scale': 1.0, 'hitpause_seconds': c['contact_hitpause_seconds'], 'loudness': c['attack_loudness']}

IDENTITY_FIELDS = ('serial', 'chain_serial', 'step_index', 'input_id', 'request_id', 'request_kind', 'hold_id', 'charge_serial', 'charge_role', 'attack_pose_id')
def identity(d): return tuple(d[k] for k in IDENTITY_FIELDS)


def verify_contacts(s, hz, primary):
    ctx = f'held/{hz}/{s["name"]}'; attacks = starts(s)
    for key in ('serial', 'request_id'):
        values = [e['data'][key] for e in attacks]
        require(all(type(v) is int and v > 0 for v in values) and all(a < b for a,b in zip(values, values[1:])), f'Recycled {key}: {ctx}')
    by_serial = {e['data']['serial']: e for e in attacks}
    physical = [e['data']['input_id'] for e in attacks if e['data']['request_kind'] == 'fresh']
    require(all(a < b for a,b in zip(physical, physical[1:])), f'Fresh edge committed twice: {ctx}')
    for e in attacks:
        d = e['data']; f = s['frames'][e['tick']-1]
        require(d['request_kind'] in ('fresh', 'held_repeat', 'charge_commit') and type(d['hold_id']) is int and d['hold_id'] >= 0 and 0 < d['input_id'] <= f['after']['attack_input_id'], f'Invalid input/request/hold identity: {ctx}')
        if d['step_index'] >= 0 and not d['charge_role']:
            requests=[q for q in event_rows(s,'chain_input_queued') if q['data']['request_id']==d['request_id']]
            require(len(requests)==1 and requests[0]['tick']<=e['tick'] and all(requests[0]['data'][k]==d[k] for k in ('input_id','request_kind','step_index')),f'Chain strike has no unique admitted request linkage: {ctx}')
        if d['request_kind'] != 'fresh':
            require(any(old['tick'] < e['tick'] and old['data']['input_id'] == d['input_id'] and old['data']['hold_id'] == d['hold_id'] and old['data']['request_kind'] == 'fresh' for old in attacks), f'Synthetic request without physical origin: {ctx}')
        if d['charge_role']:
            require(f['before']['shield_lock_remaining'] <= f['delta']+1e-8 and f['before']['melee_reuse_lock_remaining'] <= f['delta']+1e-8, f'Charge stroke bypassed inherited reuse/shield lock: {ctx}')
            expected = definition(s, e, primary)
            require(d['chain_serial'] == 0 and d['charge_serial'] > 0 and d['attack_pose_id'] == expected['pose_id'] and d['step_label'] == expected['step_label'], f'Charge step borrowed chain/profile identity: {ctx}')
            require((d['charge_role'], d['step_index'], d['request_kind']) in (('starter',0,'fresh'), ('charged',1,'charge_commit')), f'Charge role/request mismatch: {ctx}')
    terminals, phases, confirmations = set(), {}, set()
    for e in s['events']:
        if e['event'] not in ('attack_started','attack_phase_changed','attack_finished','attack_cancelled','strike_confirmed'): continue
        d = dict(e['data']); serial = d['serial']; require(serial in by_serial, f'Unadmitted strike event: {ctx}')
        if e['event'] == 'attack_cancelled' and d.get('reason') == 'reset':
            require(d['input_id'] == 0, f'Wrong reset sentinel: {ctx}'); d['input_id'] = by_serial[serial]['data']['input_id']
        require(identity(d) == identity(by_serial[serial]['data']), f'Event changed frozen identity: {ctx}/{e["event"]}')
        if e['event'] == 'attack_started': continue
        require(serial not in terminals, f'Event after retired strike: {ctx}')
        if e['event'] in ('attack_finished','attack_cancelled'): terminals.add(serial)
        if e['event'] == 'attack_phase_changed':
            history = phases.setdefault(serial, []); history.append(d['phase'])
            require(history == ['windup','active','recovery'][:len(history)], f'Skipped/repeated phase: {ctx}')
        if e['event'] == 'strike_confirmed':
            key = (serial,d['target_id']); require(key not in confirmations, f'Duplicate target admission: {ctx}'); confirmations.add(key)
    for sample in s['strike_samples']:
        observed_callback(s, sample, ctx); d = sample['snapshot']; serial = d['serial']
        require(serial in by_serial and d['phase'] == 'active' and d['eligible'] is True, f'Unreviewed ineligible sample: {ctx}')
        require(identity(d) == identity(by_serial[serial]['data']), f'Sample changed identity: {ctx}')
        require(s['frames'][sample['tick']-1]['before']['hitpause_remaining'] <= 0, f'Paused callback emitted sample: {ctx}')
        active = [e for e in event_rows(s,'attack_phase_changed') if e['data']['serial'] == serial and e['data']['phase'] == 'active']
        require(len(active) == 1 and d['facing'] == active[0]['data']['facing'] in (-1,1), f'Contact-facing latch rotated: {ctx}')
        p = definition(s,by_serial[serial],primary)
        require(d['size'] == p['strike_size'], f'Geometry does not match admitted profile: {ctx}')
        for k in ('damage','prop_launch_scale'): close(d[k],p[k],1e-8,f'{ctx}/{k}')
        close(d['impulse'][0],p['impulse'][0]*d['facing'],1e-8,ctx); close(d['impulse'][1],p['impulse'][1],1e-8,ctx)
        for k in ('center','previous_center','origin','size','impulse'):
            require(len(d[k]) == 2, f'Invalid vector: {ctx}/{k}')
            for v in d[k]: number(v,ctx)
    target_keys = set()
    for target in s['physical_target_receipts']:
        observed_callback(s,target,ctx); d = target['payload']; key = (d['serial'],target['target_name'])
        require(key not in target_keys, f'Duplicate actual target effect: {ctx}'); target_keys.add(key)
        require(any(row['tick'] == target['tick'] and all(d[k] == v for k,v in row['snapshot'].items()) for row in s['strike_samples']), f'Target payload lacks frozen physical sample: {ctx}')
        require(any(e['tick'] == target['tick'] and e['data']['serial'] == d['serial'] and e['data']['contact_position'] == d['contact_position'] for e in event_rows(s,'strike_confirmed')), f'Target effect lacks admitted contact: {ctx}')
    receipt_keys = set()
    for receipt in s['physical_contact_receipts']:
        observed_callback(s,receipt,ctx); key = (receipt['serial'],receipt['target']['object_id'])
        require(key not in receipt_keys and key in confirmations, f'Duplicate/unadmitted adapter receipt: {ctx}'); receipt_keys.add(key)
        if receipt['kind'] == 'fixture':
            require(any(t['tick'] == receipt['tick'] and t['target_name'] == receipt['target']['name'] and t['payload']['serial'] == receipt['serial'] for t in s['physical_target_receipts']), f'Acknowledgement lacks applied target effect: {ctx}')
        else: require(receipt['kind'] == 'prop' and s['name'].startswith('real charged thrust crate'), f'Unreviewed physical adapter route: {ctx}')
    unack = sum(not any(r['kind'] == 'fixture' and r['tick'] == t['tick'] and r['serial'] == t['payload']['serial'] and r['target']['name'] == t['target_name'] for r in s['physical_contact_receipts']) for t in s['physical_target_receipts'])
    require(unack == (1 if s['name'] == 'charged physical callback reset at receiver' else 0), f'Unreviewed already-applied effect without acknowledgement: {ctx}')
    for noise in [n for n in s['noises'] if n['kind'] == 'strike']:
        entries = [e for e in event_rows(s,'attack_phase_changed') if e['tick'] == noise['tick'] and e['data']['phase'] == 'active']
        require(len(entries) == 1, f'Strike noise without one active entry: {ctx}')
        close(noise['loudness'], definition(s,by_serial[entries[0]['data']['serial']],primary)['loudness'],1e-8,f'Strike loudness: {ctx}')
    return {'committed_strikes':len(attacks), 'physical_fresh_commits':len(physical), 'held_repeat_commits':sum(e['data']['request_kind']=='held_repeat' for e in attacks),
      'charge_commits':len(event_rows(s,'charge_committed')), 'installed_charged_strikes':len(charged(s)), 'eligible_strike_samples':len(s['strike_samples']),
      'unique_actor_contact_admissions':len(confirmations), 'passive_target_applications':len(s['physical_target_receipts']),
      'passive_target_acknowledgements':sum(r['kind']=='fixture' for r in s['physical_contact_receipts']), 'prop_launch_acknowledgements':sum(r['kind']=='prop' for r in s['physical_contact_receipts']),
      'applied_target_effects_without_later_acknowledgement':unack}

def verify_clocks_and_requests(s, hz, primary):
    ctx = f'held/{hz}/{s["name"]}'; checks = Counter(); attacks = starts(s)
    queued = event_rows(s,'chain_input_queued')
    require(len({q['data']['request_id'] for q in queued}) == len(queued), f'Request offered repeatedly: {ctx}')
    synthetic = [q for q in queued if q['data']['request_kind'] == 'held_repeat']
    synthetic += [a for a in attacks if a['data']['request_kind'] == 'held_repeat' and a['data']['step_index'] < 0]
    require(max(Counter(q['tick'] for q in synthetic).values(),default=0) <= 1, f'Multiple synthetic offers in one callback: {ctx}')
    for q in synthetic:
        f = s['frames'][q['tick']-1]; before = f['before']; d = q['data']
        require(before['hitpause_remaining'] <= 0 and before['attack_hold_armed'] is True and before['attack_hold_released'] is False,
                f'Synthetic request from paused/disarmed/released hold: {ctx}')
        require(d['input_id'] <= before['attack_input_id'], f'Repeat fabricated fresh press: {ctx}')
        if d.get('kind') == 'followup':
            p = s['melee_chain']['steps'][before['attack_step_index']]
            age = before['attack_step_elapsed']
            require(p['followup_open_seconds'] - 1e-8 <= age <= p['followup_close_seconds'] + 1e-8,
                    f'Repeat ignored preclock input window: {ctx}/{age}')
            require(before['pending_attack_request_id'] == 0, f'Repeat overfilled pending slot: {ctx}')
        elif before['weapon_phase'] == 'idle':
            require(before['repeat_restart_remaining'] <= 1e-8, f'Repeat offered before restart clock expired: {ctx}')
        checks['preclock_synthetic_offer'] += 1
    for f in s['frames']:
        b,a = f['before'],f['after']; dt = f['delta']; same = b['weapon_generation'] == a['weapon_generation']; paused=b['hitpause_remaining']>0
        require(a['attack_input_id'] - b['attack_input_id'] in (0,1), f'Physical edge counter jumped: {ctx}')
        require(a['attack_serial'] >= b['attack_serial'] and a['chain_serial'] >= b['chain_serial'] and a['charge_serial'] >= b['charge_serial'], f'Identity recycled: {ctx}')
        for side in (b,a):
            for k in ('charge_elapsed','charge_duration','charge_progress','repeat_restart_remaining','attack_buffer','chain_pending_remaining','chain_retention_remaining','melee_reuse_lock_remaining','shield_lock_remaining','attack_step_elapsed','weapon_elapsed'):
                require(number(side[k],ctx) >= -1e-8, f'Negative clock: {ctx}/{k}')
            require(side['charge_elapsed'] <= side['charge_duration'] + 1e-8 and 0 <= side['charge_progress'] <= 1, f'Charge clock/progress unbounded: {ctx}')
            require(not (side['weapon_phase'] != 'idle' and side['shield_phase'] != 'idle'), f'Parallel shield/weapon owners: {ctx}')
            if side['weapon_phase'] == 'charge':
                require(side['strike_active'] is False and side['charge_role'] == 'starter', f'Loading exposed damage owner: {ctx}')
                close(side['charge_progress'],side['charge_elapsed']/side['charge_duration'],1e-8,f'Charge progress: {ctx}')
        if same and b['weapon_phase'] == a['weapon_phase'] == 'charge':
            close(a['charge_elapsed'], b['charge_elapsed'] if paused else min(b['charge_duration'],b['charge_elapsed']+dt),1e-8,f'Independent charge clock: {ctx}')
            checks['charge_elapsed'] += 1
        if not same: continue
        clearing = any(e['tick']==f['tick'] and e['event'] in ('reset','hurt_started') for e in s['events'])
        if clearing: continue
        for k in ('melee_reuse_lock_remaining','shield_lock_remaining'):
            if b[k] > 0:
                close(a[k],b[k] if paused else max(0,b[k]-dt),1e-8,f'Independent lock: {ctx}/{k}'); checks[k] += 1
        if b['pending_attack_request_id'] and b['pending_attack_request_id'] == a['pending_attack_request_id'] and b['chain_pending_remaining'] > 0:
            freeze = paused or b['main_action']=='hard_land'
            close(a['chain_pending_remaining'], b['chain_pending_remaining'] if freeze else max(0,b['chain_pending_remaining']-dt),1e-8,f'Pending deadline: {ctx}'); checks['pending_deadline'] += 1
        if b['repeat_restart_remaining'] > 0 and b['weapon_phase']==a['weapon_phase']=='idle':
            close(a['repeat_restart_remaining'],b['repeat_restart_remaining'] if paused else max(0,b['repeat_restart_remaining']-dt),1e-8,f'Restart clock: {ctx}'); checks['repeat_restart_remaining'] += 1
        if paused:
            for k in ('charge_elapsed','weapon_elapsed','attack_step_elapsed','repeat_restart_remaining'):
                close(a[k],b[k],1e-8,f'Paused actor clock: {ctx}/{k}'); checks['paused_'+k] += 1
    charges = event_rows(s,'charge_started'); commits = event_rows(s,'charge_committed'); cancellations = event_rows(s,'charge_cancelled')
    require(len({e['data']['charge_serial'] for e in charges})==len(charges) and len({e['data']['charge_serial'] for e in commits})==len(commits), f'Charge started/committed twice: {ctx}')
    for e in charges:
        d=e['data']; starter=[a for a in attacks if a['data']['charge_serial']==d['charge_serial'] and a['data']['charge_role']=='starter']
        require(len(starter)==1, f'Charge has no unique starter: {ctx}')
        for k in ('hold_id','input_id','request_id'): require(d[k]==starter[0]['data'][k], f'Charge lost starter origin: {ctx}/{k}')
        close(d['elapsed'],0,1e-8,f'Charge prefilled before branch: {ctx}')
        close(d['duration'],s['input_profile_at_start']['charge_seconds'],1e-8,f'Charge duration snapshot: {ctx}')
        ended=[x for x in event_rows(s,'attack_finished') if x['data']['serial']==starter[0]['data']['serial']]
        require(len(ended)==1 and ended[0]['tick']==e['tick'], f'Charge did not retire starter at branch: {ctx}')
    for e in commits:
        d=e['data']; original=[x for x in charges if x['data']['charge_serial']==d['charge_serial']]
        require(len(original)==1, f'Commit lacks charge: {ctx}')
        for k in ('hold_id','input_id','duration'): require(d[k]==original[0]['data'][k], f'Charge commit origin changed: {ctx}/{k}')
        require(d['request_kind']=='charge_commit' and d['request_id']>original[0]['data']['request_id'], f'Commit lacks separate request: {ctx}')
        close(d['elapsed'],d['duration'],1e-8,f'Premature/overrun charge commit: {ctx}')
        require(not any(x['data']['charge_serial']==d['charge_serial'] and x['tick']<e['tick'] for x in cancellations), f'Cancelled charge resurrected: {ctx}')
        outcomes=[a for a in charged(s) if a['data']['charge_serial']==d['charge_serial']]
        if outcomes:
            require(len(outcomes)==1 and outcomes[0]['tick']==e['tick'] and outcomes[0]['data']['request_id']==d['request_id'], f'Commit installed multiple/delayed strikes: {ctx}')
        else: require(s['name'].startswith('charge_committed callback replaces '), f'Unreviewed commit without thrust: {ctx}')
    return dict(checks)


def timing_rows(s,hz,primary):
    rows=[]; ctx=f'{hz}/{s["name"]}'
    def record(metric,first,last,expected,allowance,reason):
        measured=active_seconds(s,first,last)
        require(expected-1e-8 <= measured <= expected+allowance+1e-8,f'Timing outside profile boundary: {ctx}/{metric}: {measured} vs {expected}+{allowance}')
        rows.append({'physics_hz':hz,'scenario':s['name'],'metric':metric,'observed_seconds':measured,'profile_seconds':expected,
                     'allowed_error':allowance+1e-8,'tolerance_reason':reason,'passed':True})
    for start in starts(s):
        p=definition(s,start,primary); d=start['data']; short=min(p[k+'_seconds'] for k in ('windup','active','recovery'))<1/hz
        for e in s['events']:
            if e['data'].get('serial')!=d['serial']: continue
            expected=None
            if e['event']=='attack_phase_changed' and e['data']['phase'] in ('active','recovery'):
                phase=e['data']['phase']; expected=p['windup_seconds']+(p['active_seconds'] if phase=='recovery' else 0); metric=f'strike{d["serial"]}_{phase}_entry'
            elif e['event']=='attack_finished' and not e['data'].get('early_chain',False):
                expected=sum(p[k+'_seconds'] for k in ('windup','active','recovery'));metric=f'strike{d["serial"]}_natural_completion'
            elif e['event']=='attack_finished' and e['data'].get('early_chain',False):
                gate=s['input_profile_at_start']['charge_branch_recovery_seconds'] if d['charge_role']=='starter' else p['followup_commit_recovery_seconds']
                expected=p['windup_seconds']+p['active_seconds']+gate;metric=f'strike{d["serial"]}_branch_or_followup'
                measured=active_seconds(s,start['tick'],e['tick'])
                require(measured+1e-8>=expected,f'Early branch/commit: {ctx}')
                if d['charge_role']!='starter' and not s['name'].startswith('held repeat '): continue
            if expected is not None: record(metric,start['tick'],e['tick'],expected,(3 if short else 1)/hz,'Cumulative unpaused actor time; one endpoint callback, or three for valid sub-callback phases preserving an eligible active sample')
    for e in event_rows(s,'charge_committed'):
        origin=next(x for x in event_rows(s,'charge_started') if x['data']['charge_serial']==e['data']['charge_serial'])
        record(f'charge{e["data"]["charge_serial"]}_readiness',origin['tick'],e['tick'],e['data']['duration'],1/hz,'Charge starts at zero after accepted branch; each callback beginning paused is excluded')
    if s['name'].startswith('held repeat '):
        for e in starts(s)[1:]:
            if e['data']['step_index'] not in (-1,0): continue
            prior=[x for x in event_rows(s,'attack_finished') if x['tick']<e['tick']]
            require(prior,f'Missing natural completion before repeat restart: {ctx}'); previous=prior[-1]
            record(f'request{e["data"]["request_id"]}_repeat_restart',previous['tick'],e['tick'],s['input_profile_at_start']['repeat_restart_seconds'],2/hz,'Restart decrements in actor time; repeat offer uses preclock state, allowing one additional callback after expiry')
    return rows


def verify_case_oracle(s,hz,primary):
    name=s['name']; a=starts(s); c=charged(s); cs=event_rows(s,'charge_started'); cc=event_rows(s,'charge_committed'); end=s['frames'][-1]['after']; dt=1/hz; checks=[]
    def check(condition,label): require(condition,f'{hz}/{name}: {label}');checks.append(label)
    if name.startswith('baseline '): check(len(a)==2 and not cs and all(e['data']['request_kind']=='fresh' for e in a),'baseline is fresh-only after release/new press')
    elif name.startswith('held repeat '):
        check(len(a)==4 and [e['data']['request_kind'] for e in a]==['fresh']+['held_repeat']*3,'one fresh edge yields three admitted synthetic successors')
        check(len({e['data']['input_id'] for e in a})==len({e['data']['hold_id'] for e in a})==1,'repeat does not manufacture physical/hold identity')
        check([e['data']['step_index'] for e in a]==([0,1,2,0] if 'chain' in name else [-1]*4),'repeat follows actual chain or fallback graph')
        check(len(s['physical_target_receipts'])==len(s['physical_contact_receipts'])==4 and end['weapon_phase']=='idle','four distinct actual hits and finite release completion')
    elif name.startswith('repeat release preserves '): check(len(a)==(2 if 'explicit fresh' in name else 1) and end['weapon_phase']=='idle','release removes only synthetic pending intent')
    elif name.startswith('starter charge thrust '):
        check(len(a)==3 and len(cs)==len(cc)==len(c)==1,'one held charge followed by one newly rearmed starter')
        check(a[0]['data']['input_id']==a[1]['data']['input_id'] and a[2]['data']['input_id']>a[0]['data']['input_id'],'new release/press has separate physical identity')
        count=2 if ' target ' in name else 0
        check(len(s['physical_target_receipts'])==len(s['physical_contact_receipts'])==count,'target, whiff and wall occlusion have actual expected effects')
    elif name.startswith('charge release '):
        edge=name.removeprefix('charge release '); before=s['params']['pre_release_age']; phase=s['params']['pre_release_phase']
        check(len(c)==int(edge=='after_ready') and end['weapon_phase']=='idle','release-before-clock wins readiness and all paths finish')
        released=next((f for f in s['frames'] if f['before']['attack_input_id']>0 and isinstance(f['input'],dict) and not f['input'].get('attack',False)),None)
        check(released is not None,'boundary has an actual recorded release callback')
        sampled=released['before'];clock='charge_elapsed' if 'ready' in edge else 'weapon_elapsed'
        close(before,sampled[clock],1e-8,f'Release boundary parameter must match raw preclock sample: {hz}/{name}')
        check(phase==sampled['weapon_phase'],'release phase parameter matches raw preclock sample')
        boundary=s['input_profile_at_start']['charge_seconds' if 'ready' in edge else 'charge_branch_recovery_seconds']
        if edge in ('before_ready','before_branch'): check(before+dt<boundary+1e-8,'before-boundary input precedes the first crossing callback')
        elif edge in ('ready_tick','branch_tick'): check(before<boundary+1e-8 and before+dt>=boundary-1e-8,'boundary input is at the clock-crossing callback')
        elif edge=='after_branch': check(phase=='charge' and len(cs)==1,'after-branch release observes an installed loading owner')
        elif edge=='after_ready': check(phase=='windup' and len(cc)==1,'after-readiness release follows a committed thrust')
    elif ' hold retires on ' in name: check(not c and len(a)==2 and a[-1]['data']['request_kind']=='fresh','interruption prevents revival until the separately recorded fresh press')
    elif name.startswith('full charge yields to simultaneous '): check(not c and not cc and end['weapon_phase']!='charge','accepted higher-priority readiness input cancels before charged admission')
    elif name.startswith('charge hitpause ') or name.startswith('parsed held input release during pause charge'):
        check(len(c)==1,'one expected final thrust only')
        if name.endswith('continued hold'): check(len(cs)==len(cc)==1,'continued paused hold retains one episode')
        else: check(len(cs)==2 and c[0]['data']['charge_serial']==cs[-1]['data']['charge_serial']>cs[0]['data']['charge_serial'],'paused release retires the old identity while a separate new press rearms')
    elif name.startswith(('charge_started callback replaces ','charge_committed callback replaces ')):
        check(not c and not any(x['snapshot']['charge_role']=='charged' for x in s['strike_samples']),'callback replacement prevents installed charged strike/contact')
    elif name.startswith('input configuration round trip retires '): check(not cs if name.endswith('pending') else len(cs)==1,'configuration assignment retains no new branch');check(end['weapon_phase']=='idle','configuration invalidation settles idle')
    elif name.startswith('live repeat snapshot survives rejected edge '): check(not cs and not c and any(f['after']['input_mode']=='held_repeat' for f in s['frames']),'rejected edge cannot overwrite live repeat snapshot')
    elif name.startswith('charge resource snapshot '): check(len(c)==1 and s['input_profile_at_start']['charge_seconds']==.45,'accepted charge snapshot survives same-value/in-place mutation')
    elif name=='same-callback release repress cannot preserve charge hold': check(not c and len(event_rows(s,'charge_cancelled'))>=1,'same-callback release beats final sampled held state')
    elif ' input versus ' in name: check(not a and not cs and any(f['after']['shield_phase']!='idle' for f in s['frames']),'initial shield ownership prevents latent optional-mode attack')
    elif name.startswith('initial denied '):
        if name.endswith('after_deadline'): check(len(a)==1 and a[0]['data']['input_id']==2,'expired first press never retries; only second fresh input starts')
        else: check(a and a[0]['data']['input_id']==1,'still-live first press is admitted after unlock')
    elif name=='repeat pending expiry cannot retry after longer reuse lock': check(len(a)==1 and len(event_rows(s,'chain_input_expired'))==1 and not end['attack_hold_armed'],'one finite synthetic request expires and disarms')
    elif name=='starter reuse lock closes charge branch without backlog': check(len(a)==1 and not cs and end['weapon_phase']=='idle','closed finite starter branch cannot resume later')
    elif name=='shield lock rejects held starter without parallel loading': check(len(a)==1 and not cs and a[0]['data']['input_id']==2,'shield lock keeps first hold from becoming latent input')
    elif name.startswith('charged physical callback reset at '):
        count=int(name.endswith(('receiver','contact_confirmed')))
        check(len(s['physical_target_receipts'])==count and len(s['physical_contact_receipts'])==int(name.endswith('contact_confirmed')),'effect application and adapter acknowledgement have separate callback boundaries')
        check(end['weapon_phase']=='idle','contact reset retires strike')
    elif name=='charged strike confirms two actual targets once each':
        check(len(s['physical_target_receipts'])==len(s['physical_contact_receipts'])==2 and len(event_rows(s,'hitpause_started'))==1,'two effects share one admitted sample and pause budget')
        check(len({r['engine_tick'] for r in s['physical_contact_receipts']})==1,'two-target receipts belong to same actual engine callback')
    elif name.startswith('minimum valid phase retains charge opportunity '): check(len(a)==2 and len(cs)==len(cc)==1 and len(s['physical_target_receipts'])==2 and end['weapon_phase']=='idle','minimum valid phases preserve starter and thrust contact opportunities')
    elif name.startswith('invalid held configuration refuses '): check(not a and not cs and end['weapon_phase']=='idle','invalid profile refuses admission without fallback')
    elif name.startswith('fresh presses during busy charge episode '): check(len(a)==2 and len(cc)==1 and len({e['data']['hold_id'] for e in a})==1,'busy fresh edge cannot replace hold or create backlog')
    elif name.startswith('denied readiness replacement preserves charge '): check(len(c)==1 and end['weapon_phase']=='windup','denied replacement preserves valid charged admission')
    elif name.startswith('loading charge yields to physical ') or name=='charging one-way support yields to targeted drop': check(not c and any(e['event']=='charge_cancelled' for e in s['events']),'physical traversal retires charge without later thrust')
    elif name.startswith('charge landing '): check(len(c)==int('soft' in name) and len(event_rows(s,'landed'))==1,'actual soft/hard landing preserves/retires charge as configured')
    elif name=='same actor alternates held modes through reset without stale authority':
        for key in ('cycle_serials','cycle_hold_ids'):
            values=s['measurements'][key];check(len(values)==4 and all(x<y for x,y in zip(values,values[1:])),f'{key} remains monotonic across reset/mode reuse')
    if name.startswith('real charged thrust crate'):
        m=s['measurements'];direction=int(name.rsplit('direction',1)[1]);p=s['input_profile_at_start']['charge_strike']
        check(m['launch_count']==m['hit_count']==1 and m['charge']>0 and len(s['physical_contact_receipts'])==1,'real rigid body receives one actual charged launch')
        close(m['expected_launch_speed'],m['tuning_launch_speed']*p['prop_launch_scale'],1e-8,f'Authored prop scale: {hz}/{name}')
        check(m['body_velocity'][0]*direction>m['expected_launch_speed']*.5 and (m['body_position'][0]-m['launch_position'][0])*direction>0,'actual rigid momentum and displacement move outward')
        check(len(m['prop_launch_events'])==1 and math.dist(m['prop_launch_events'][0]['origin'],m['launch_position'])<.01,'actual prop noise occurs at actual launch position')
    if name.startswith('air charge preserves fall and budgets '):
        falling=[f for f in s['frames'] if f['before']['weapon_phase']=='charge' and f['before']['velocity'][1]>=0]
        check(len(falling)>2,'falling loading has measured physics callbacks')
        p=primary['movement_profile']; error=0
        for f in falling:
            expected=min(f['before']['velocity'][1]+p['gravity']*p['falling_gravity_multiplier']*f['delta'],p['terminal_fall_speed'])
            error=max(error,abs(f['after']['velocity'][1]-expected))
        check(error<.002 and not event_rows(s,'landed') and end['fall_history_active'] and end['fall_distance']>100,'charge retains ordinary measured gravity and fall excursion')
        close(s['measurements']['maximum_gravity_error'],error,1e-8,'Recorded gravity error')
    if any(token in name for token in ('thin wall','low roof','stay supported on slope')):
        check(max(f['after']['solid_rectangle_overlap_depth'] for f in s['frames'])<=.03,'actual swept rectangle penetration stays below .03 px')
    return checks


def verify_additional_cases(s,hz,primary):
    name=s['name']; frames=s['frames']; end=frames[-1]['after']; rows=[]
    def check(value,label): require(value,f'{hz}/{name}: {label}');rows.append(label)
    if name.startswith('charge reversal and thin wall '):
        direction=int(name.rsplit('direction',1)[1]); charge_frames=[f for f in frames if f['after']['weapon_phase']=='charge']
        check(any(f['after']['facing']==direction for f in charge_frames),'manual direction reverses loading facing')
        samples=[x['snapshot'] for x in s['strike_samples'] if x['snapshot']['charge_role']=='charged']
        check(samples and all(x['facing']==direction for x in samples),'all charged samples retain active-entry direction')
    elif name=='charge live movement and turning permissions intersect':
        denied=[f for f in frames if f['before']['weapon_phase']==f['after']['weapon_phase']=='charge' and f['after']['weapon_permissions']['can_move'] is False]
        check(denied and any(f['after']['facing']==-1 for f in denied),'movement denial independently allows permitted turn')
        check(all(math.dist(f['before']['position'],f['after']['position'])<.03 for f in denied),'movement denial leaves loading stationary')
        check(end['facing']==-1 and end['weapon_phase']=='charge' and end['weapon_permissions']['can_turn'] is False,'later turn denial retains prior direction/loading')
    elif name=='two actors share input configuration without runtime cross-talk':
        peer=s['measurements']['second_actor_samples'];check(peer and peer[-1]['after']['attack_serial']==2 and len(charged(s))==1,'both actual actors independently complete one episode')
        check(peer[0]['before']['attack_serial']==0 and s['input_profile_at_start']==s['input_profile_at_finish'],'shared Resource remains unchanged')
        check(all(y['engine_tick']-x['engine_tick']==1 for x,y in zip(peer,peer[1:])),'peer samples belong to consecutive real callbacks')
    elif name=='finished held melee configuration change preserves independent shield':
        check(end['shield_phase']=='hold' and end['weapon_phase']=='idle','configuration replacement preserves independent held shield')
        shield=[f for f in frames if f['after']['shield_phase']=='hold'];check(shield and len({f['after']['shield_serial'] for f in shield})==1,'shield identity is not replaced')
    elif name=='fresh-only strike has no inherited held origin':
        attacks=starts(s);check(len(attacks)==2 and attacks[0]['data']['hold_id']>0 and attacks[1]['data']['hold_id']==0,'fresh-only admission has explicit no-held-origin identity')
        check(all(x['snapshot']['hold_id']==0 for x in s['strike_samples'] if x['snapshot']['serial']==attacks[1]['data']['serial']),'fresh-only active snapshot inherits no old optional hold')
    elif name=='parsed held input release during pause repeat':
        edges=s['parsed_input_edges'];check([e['pressed'] for e in edges]==[True,False,True,False],'actual native press/release sequence is retained')
        check(all(e['key']=='J' for e in edges) and len(starts(s))>=2,'native physical input reaches ordinary repeated admission')
    elif name.startswith('charge and thrust stay supported on slope '):
        first=starts(s)[0]['tick'];active=frames[first:]
        check(active and all(f['after']['grounded'] for f in active),'actual slope retains support throughout charge/execution')
        check(all(f['after']['terrain_clearance_normal'] is None or f['after']['terrain_clearance_normal']>=-.03 for f in active),'body remains outside sampled slope plane')
    elif name=='complete charge remains crouched under real low roof':
        check(end['body_height']==primary['movement_profile']['crouching_height'],'charge/execution retains collision-safe small body')
    elif name.startswith('paused charging carrier '):
        paused=[f for f in frames if f['before']['hitpause_remaining']>0 and f['before']['weapon_phase']=='charge']
        check(paused and all(f['after']['charge_elapsed']==f['before']['charge_elapsed'] for f in paused),'support lifecycle does not advance paused loading')
        if name.endswith('moving'): check(any(f['after']['position'][0]>f['before']['position'][0] and f['after']['position'][1]<f['before']['position'][1] for f in paused) and end['grounded'],'moving support physically transports paused actor')
        else: check(not end['grounded'] and end['velocity'][1]>0,'removed support resumes falling')
    return rows


def verify_profiles(primary,baseline):
    repeat,charge=primary['repeat_profile'],primary['charge_profile']
    require(repeat['mode']==1 and charge['mode']==2 and repeat['charge_starter'] is None and repeat['charge_strike'] is None,'Ambiguous held modes')
    for p in (repeat,charge): close(p['repeat_restart_seconds'],.08,1e-12,'Authored repeat restart')
    for k,v in {'charge_branch_recovery_seconds':.06,'charge_seconds':.45,'charge_move_scale':.35}.items():close(charge[k],v,1e-12,f'Authored {k}')
    require(charge['charge_allow_turn'] is True,'Authored charge turn flag')
    starter=charge['charge_starter'];thrust=charge['charge_strike']
    for p,label,pose,times in ((starter,'Starter Slash','slash',(.07,.065,.16)),(thrust,'Charged Thrust','charged_thrust',(.06,.10,.24))):
        require(p['step_label']==label and p['pose_id']==pose and p['next_step']==-1,f'Authored step identity: {label}')
        for phase,value in zip(('windup','active','recovery'),times):close(p[phase+'_seconds'],value,1e-12,label+'/'+phase)
    for k,v in {'active_ground_speed':260.,'damage':2.6,'prop_launch_scale':1.25,'hitpause_seconds':.06,'loudness':1.25,'windup_move_scale':.35,'recovery_move_scale':.65,'recovery_cancel_after':.06}.items():close(thrust[k],v,1e-12,'Authored thrust/'+k)
    require(thrust['strike_size']==[44,24] and thrust['strike_center_offset']==[30,-20] and thrust['strike_origin_offset']==[3,-22] and thrust['impulse']==[360,-100],'Authored charged contact geometry/impulse')
    require(thrust['active_cancels']==[] and thrust['allow_turn_active'] is False and thrust['allow_turn_windup'] is True,'Authored thrust commitment')
    for k in ('movement_profile','combat_profile','shield_profile','melee_chain'):require(baseline[k],'Missing inherited profile '+k)


def paired_signature(s):
    params=dict(s['params'])
    if s['name'].startswith('charge release '):
        for key in ('pre_release_age','pre_release_phase'): params.pop(key,None)
    return s['name'],params,s['checks'],[a['label'] for a in s['assertions']],s['input_profile_at_start'],s['input_profile_at_finish'],s['melee_chain'],s['shield_profile']


def verify_m10(suites,baseline):
    pair=suites['held'];contacts={str(hz):{} for hz in RATES};oracles={str(hz):{} for hz in RATES};timing=[]
    for hz,run in pair.items():
        require(tuple(s['name'] for s in run['scenarios'])==REQUIRED_M10_CASES,f'M10 exact independent inventory/order mismatch at {hz}')
        require(run['checks']==333,f'Reviewed final assertion inventory changed at {hz}')
        verify_profiles(run,baseline)
        for s in run['scenarios']:
            result=verify_contacts(s,hz,baseline)
            result['independent_clock_transition_checks']=verify_clocks_and_requests(s,hz,baseline)
            contacts[str(hz)][s['name']]=result
            timing.extend(timing_rows(s,hz,baseline))
            rules=verify_case_oracle(s,hz,baseline)+verify_additional_cases(s,hz,baseline)
            require(rules,f'Case lacks an independent outcome oracle: {s["name"]}')
            oracles[str(hz)][s['name']]=rules
    indexes={hz:{(r['scenario'],r['metric']):r for r in timing if r['physics_hz']==hz} for hz in RATES}
    require(indexes[120].keys()==indexes[60].keys(),'Paired timing inventory differs')
    comparisons=[]
    for key in sorted(indexes[120]):
        a,b=indexes[120][key],indexes[60][key]
        allowance=max(a['allowed_error'],b['allowed_error'])
        close(a['observed_seconds'],b['observed_seconds'],allowance,f'M10 paired actor-time bound: {key}')
        comparisons.append({'suite':'held','scenario':key[0],'metric':key[1],'value_120hz':a['observed_seconds'],'value_60hz':b['observed_seconds'],
          'allowed_difference':allowance,'tolerance_reason':a['tolerance_reason'],'passed':True})
    population=('passive_target_applications','passive_target_acknowledgements','prop_launch_acknowledgements','applied_target_effects_without_later_acknowledgement')
    for name in REQUIRED_M10_CASES:
        for key in population:require(contacts['120'][name][key]==contacts['60'][name][key],f'Paired physical effect counts differ: {name}/{key}')
    return contacts,oracles,timing,comparisons


def verify_compatibility(suites,m9,m8,m7):
    mapped={('combo' if name=='combo_compatibility' else name):value for name,value in suites.items() if name!='held'}
    for suite in OLDER_SUITES:
        for hz in RATES:
            old=read_compact_history(TESTS / f'{"combo_results" if suite=="combo" else suite+"_compat_m9_results"}_{hz}hz.json')
            new=suites[f'{suite}_compatibility'][hz]
            signature=lambda run:[(s['name'],s.get('params',{}),s['checks'],[a['label'] for a in s['assertions']]) for s in run['scenarios']]
            require(signature(old)==signature(new),f'Historical cases/parameters/assertions changed: {suite}/{hz}')
    for hz in RATES:require(tuple(s['name'] for s in mapped['combo'][hz]['scenarios'])==m9.REQUIRED_M9_CASES,f'Inherited M9 inventory missing at {hz}')
    inherited,phases,observers,shield_timing,shield_contacts=m9.verify_compatibility(mapped,m8,m7)
    combo,timing,contacts=m9.verify_combo_semantics(mapped)
    scaling=m9.prop_scale_rows(mapped)
    previous=read(ROOT/'combat_pc/combo_verification.json')
    fields=('suite','scenario','metric','allowed_difference','tolerance_reason')
    require([[r[k] for k in fields] for r in inherited+combo]==[[r[k] for k in fields] for r in previous['cross_rate_comparisons']], 'Inherited M9 numerical acceptance bounds changed/omitted')
    for r in combo:r['suite']='combo_compatibility'
    return {'comparisons':inherited+combo,'within_rate':phases,'observers':observers,'shield_timing':shield_timing,'shield_contacts':shield_contacts,'combo_timing':timing,'combo_contacts':contacts,'prop_scaling':scaling}


def verify_corrections(suites):
    manifest=read(TESTS/'held_correction_evidence.json');require(manifest['milestone']==10,'Wrong correction milestone')
    corrections=manifest['corrections'];require({r['id'] for r in corrections}=={'unused-input-snapshot-cancels-shield','short-valid-starter-skips-charge-branch','queued-followup-overwrites-live-strike-hold-origin'} and len(corrections)==3,'Incorrect correction inventory')
    artifacts={}
    for row in corrections:
        require(row['issue'] and row['evidence_kind'] and row['final_cases'],'Correction lacks provenance or independent final case')
        require('pending' not in row.get('status','').lower(),'Correction still pending')
        for name,digest in row['artifacts_sha256'].items():artifacts[name]=pin(project_path(name),digest)
        if 'final_controller_sha256' in row:require(row['final_controller_sha256']==REVIEWED_CONTROLLER_SHA256,'Correction final source pin stale')
        if 'before_failures' in row:
            require(row['before_failures']>0 and row['after_failures']==0,'Implementation before/after proof lacks failed/fixed distinction')
            for suffix,expected in (('_before.log',row['before_failures']),('_after.log',0)):
                logs=[project_path(n) for n in row['artifacts_sha256'] if n.endswith(suffix)]
                require(len(logs)==1,'Implementation proof log missing or ambiguous')
                match=re.search(r'M10 SMOKE (\d+) checks (\[[^\n]*\])',logs[0].read_text())
                require(match and int(match[1])==2 and len(json.loads(match[2]))==expected,'Implementation before/after log differs from claimed observations')
        require(any(name.endswith('.gd.txt') for name in row['artifacts_sha256']),'Missing actual before source or probe')
        for case in row['final_cases']:
            for hz in RATES:require(case in [s['name'] for s in suites['held'][hz]['scenarios']],f'Correction final replay absent: {row["id"]}/{hz}')
        if row['id']=='queued-followup-overwrites-live-strike-hold-origin':
            require(row['before_controller_sha256']=='ca632f1557967f9078cededa40a5bec54c5e3294b4b97c939e67235d4321cd1a','Wrong independently audited before source')
            for hz in RATES:
                before=read(TESTS/f'held_before_strike_hold_identity_{hz}hz.json')
                require(before['hashes']['res://combat_pc/player.gd']==row['before_controller_sha256'],'Before trace/source mismatch')
                for name in ('repeat release preserves explicit fresh request','parsed held input release during pause repeat'):
                    scenario=next(x for x in before['scenarios'] if x['name']==name);origin={e['data']['serial']:e['data']['hold_id'] for e in starts(scenario)}
                    changed=[e for e in scenario['events'] if e['event'] in ('attack_phase_changed','attack_finished','attack_cancelled','strike_confirmed') and e['data']['hold_id']!=origin[e['data']['serial']]]
                    require(changed,'Independent before evidence no longer demonstrates the held-origin defect')
                del before
    clarifications=manifest['harness_clarifications']
    require(len(clarifications)==1 and clarifications[0]['classification']=='Oracle correction; no production defect','Paused re-press clarification lost or reclassified')
    for row in clarifications:
        for name,digest in row['artifacts_sha256'].items():artifacts[name]=pin(project_path(name),digest)
    return manifest,artifacts


def verify_execution_recovery(suites):
    recovery=read(TESTS/'held_execution_recovery.json')
    require(recovery['milestone']==10 and recovery['suite']=='combo' and recovery['physics_hz']==120,'Wrong execution recovery')
    first=recovery['interrupted_attempt'];last=recovery['recovery']
    require(first['process_exit_code']==-9 and first['engine_diagnostics'] is False and first['completed_result_accepted'] is False,'Interrupted attempt was accepted or misrepresented')
    require(last['process_exit_code']==0 and last['engine_diagnostics'] is False and last['controller_sha256']==REVIEWED_CONTROLLER_SHA256,'Recovered run is not clean/final')
    actual=suites['combo_compatibility'][120]
    require(last['scenarios']==len(actual['scenarios']) and last['checks']==actual['checks'] and last['failures']==0,'Recovered execution counts differ from final trace')
    for name,digest in recovery['artifacts_sha256'].items():pin(project_path(name),digest)
    old=project_path('combat_pc/tests/m10_combo_120_interrupted.log').read_text()
    require(not re.search(r'SCRIPT ERROR|ERROR:|FAIL:|WARNING:',old) and not re.search(r'MOKSHA .*120Hz:',old),'Interrupted log unexpectedly establishes a completed/error run')
    return recovery


def dependency_inventory():
    """Pin transitive static inputs separately from start/end runtime evidence."""
    paths={ROOT/'project.godot',ROOT/'scripts/sensory/noise_bus.gd',ROOT/'prop.gd',ROOT/'scenes/props/crate.tscn'}
    for folder in ('resources','components','fixtures','visuals'):
        paths.update(p for p in (ROOT/'combat_pc'/folder).rglob('*') if p.suffix in ('.gd','.tres','.tscn','.gdshader','.png','.svg'))
    paths.update((ROOT/'combat_pc/player.gd',ROOT/'combat_pc/player.tscn'))
    result={};pending=list(paths)
    while pending:
        path=pending.pop().resolve()
        if path in result:continue
        result[path]=pin(path)
        if path.suffix not in ('.gd','.tres','.tscn','.godot','.gdshader'):continue
        for relative in re.findall(r'res://([^"\s]+)',path.read_text()):
            dependency=(ROOT/relative).resolve()
            if dependency.is_relative_to(ROOT) and dependency.is_file() and dependency not in result:pending.append(dependency)
    return {display(p):h for p,h in sorted(result.items())}


def negative_probes(primary,baseline):
    """Mutate copies only. A report writer must reject altered raw M10 evidence."""
    import copy
    index={s['name']:s for s in primary['scenarios']};proof=[]
    def probe(label,name,mutation,validator):
        candidate=copy.deepcopy(index[name]);mutation(candidate)
        try:validator(candidate,120,baseline)
        except VerificationError as error:proof.append({'probe':label,'expected':'rejected','observed':'rejected','reason':str(error),'retained_files_modified':False})
        else:raise VerificationError('Negative audit probe was incorrectly accepted: '+label)
    charge='starter charge thrust target direction1'
    def wrong_hold(s):next(x for x in s['strike_samples'] if x['snapshot']['charge_role']=='charged')['snapshot']['hold_id']+=100
    def wrong_request(s):next(x for x in s['events'] if x['event']=='charge_committed')['data']['request_id']+=100
    def duplicate(s):s['events'].append(copy.deepcopy(next(x for x in s['events'] if x['event']=='charge_committed')))
    def paused_clock(s):
        f=next(x for x in s['frames'] if x['before']['hitpause_remaining']>0 and x['before']['weapon_phase']==x['after']['weapon_phase']=='charge')
        f['after']['charge_elapsed']+=f['delta'];f['after']['charge_progress']=f['after']['charge_elapsed']/f['after']['charge_duration']
    probe('changed admitted hold identity',charge,wrong_hold,verify_contacts)
    probe('changed charge request linkage',charge,wrong_request,verify_clocks_and_requests)
    probe('duplicate charged commit',charge,duplicate,verify_clocks_and_requests)
    probe('charge advances during local pause','charge hitpause continued hold',paused_clock,verify_clocks_and_requests)
    probe('missing actual prop noise','real charged thrust crate and noise direction1',lambda s:s['measurements'].update(prop_launch_events=[]),verify_case_oracle)
    probe('missing actual rigid impulse','real charged thrust crate and noise direction1',lambda s:s['measurements'].update(body_velocity=[0,0]),verify_case_oracle)
    probe('acknowledgement without target application',charge,lambda s:s['physical_target_receipts'].clear(),verify_contacts)
    return proof


LIMITS=[
 'Every duration, movement rule, impulse, damage value, repetition policy and cancellation rule is authored MOKSHA configuration. The reference source does not recover its charge scheduler or establish Dead Cells runtime parity.',
 'Physical input_id, admitted hold_id, request_id/request_kind and strike serial are separate identities. An observed charge_committed callback is an admission request; synchronous replacement may prevent installation of any thrust.',
 'Actor contact admissions, already applied passive-target effects, later adapter acknowledgements and actual rigid-body launches/noise are distinct populations. Direct API authority probes do not count as physical contacts.',
 'Reset cancellation exposes input_id zero after clearing consumed-input telemetry; its admitted origin is established by the matching attack_started event. Other strike identity fields must remain unchanged.',
 'A paused callback captures input and release but advances no actor clock. Ordinary phase endpoints allow one callback of quantization; minimum valid phases may retain up to three endpoint callbacks to guarantee an active contact opportunity. Repeat restart uses the preclock offer boundary and allows two.',
 'New held, M9, M8 and M7 formats record actual consecutive engine callbacks and deltas. Earlier compatibility formats establish consecutive actor ticks only; old movement/combat suites start-pin smaller inventories than they end-pin.',
 'Historical test logic is unchanged. Only output destinations are redirected, and their generated source bytes are checked against exact single replacements. Historical numerical bounds, files and nine snapshot archives remain unchanged.',
 'The intentionally invalid nonfinite-charge fixture uses the Godot overflow token 1e99999 only in its rejected input configuration. The auditor admits that exact leaf symbolically; all actor state, clocks, measurements and admitted profiles must be finite.',
 'Acceptance covers the named passive fixtures, the selected representative resources and recorded synchronous replacements. Native presentation, packaged boot and arbitrary custom content remain separate validation work.'
]


def main():
    require(REVIEWED_HARNESS_SHA256 is not None,'Final reviewed harness is not pinned; publication closed')
    require(len(REQUIRED_M10_CASES)==len(set(REQUIRED_M10_CASES))==114,'Independent M10 inventory is incomplete')
    pin(ROOT/'combat_pc/MOTOR_CONTRACT.md',REVIEWED_CONTRACT_SHA256)
    pin(ROOT/'combat_pc/player.gd',REVIEWED_CONTROLLER_SHA256);pin(TESTS/'held_regression.gd',REVIEWED_HARNESS_SHA256)
    preserved=verify_preservation();m9,m8,m7=load_preserved_validators();redirects=verify_redirects()
    suites={};continuity={};logs={};shared={}
    profile_source=read(TESTS/'combo_results_120hz.json')
    baseline={k:profile_source[k] for k in ('movement_profile','combat_profile','shield_profile','melee_chain')}
    del profile_source
    contacts=oracles=timing=comparisons=probes=None
    for suite,prefix in FILES.items():
        suites[suite]={};continuity[suite]={}
        for hz in RATES:
            run=read(TESTS/f'{prefix}_{hz}hz.json');suites[suite][hz]=run
            continuity[suite][str(hz)],newlogs=verify_run(run,suite,hz,m7);logs.update(newlogs)
            for name,digest in run['hashes'].items():
                require(name not in shared or shared[name]==digest,f'Cross-suite source drift: {name}');shared[name]=digest
        pair=suites[suite];require(pair[120]['hashes']==pair[60]['hashes'],f'Rate-pair source mismatch: {suite}')
        signature=paired_signature if suite=='held' else lambda s:m9.paired_signature(s,'combo' if suite=='combo_compatibility' else suite,m8)
        require([signature(s) for s in pair[120]['scenarios']]==[signature(s) for s in pair[60]['scenarios']],f'Paired case/parameter/profile/assertion mismatch: {suite}')
        if suite=='held':
            contacts,oracles,timing,comparisons=verify_m10(suites,baseline)
            probes=negative_probes(pair[120],baseline)
            for run in pair.values():discard_audited_frames(run,complete=True)
        elif suite.removesuffix('_compatibility') in OLDER_SUITES[:6]:
            for run in pair.values():discard_audited_frames(run)
        print(f'Validated {suite}: complete source-stable 120/60 Hz pair',flush=True)
    primary=suites['held'][120]
    for pair in suites.values():
        for run in pair.values():
            require(run['engine']==primary['engine'],'Different Godot builds across final runs')
            for k in ('movement_profile','combat_profile','shield_profile','melee_chain'):
                if k in run:require(run[k]==baseline[k],f'Inherited authored profile differs across suites: {k}')
    require(suites['held'][60]['repeat_profile']==primary['repeat_profile'] and suites['held'][60]['charge_profile']==primary['charge_profile'],'Held profile differs by rate')
    inherited=verify_compatibility(suites,m9,m8,m7)
    for suite in ('soft_slope_compatibility','shield_compatibility','combo_compatibility'):
        for run in suites[suite].values():discard_audited_frames(run,complete=True)
    print('Validated every inherited numerical bound without changes',flush=True)
    correction,correction_artifacts=verify_corrections(suites)
    recovery=verify_execution_recovery(suites)
    dependencies=dependency_inventory()
    report={'title':'MOKSHA combat PC held-input verification','milestone':10,'status':'passed','generated_utc':datetime.now(timezone.utc).isoformat(),
      'controller_sha256':REVIEWED_CONTROLLER_SHA256,'harness_sha256':REVIEWED_HARNESS_SHA256,'report_builder_sha256':pin(Path(__file__)),
      'contract_sha256':pin(ROOT/'combat_pc/MOTOR_CONTRACT.md'),'source_audit_sha256':pin(ROOT/'combat_pc/reference/M10_CHARGE_INPUT_ADDENDUM.md'),
      'source_facts_sha256':pin(ROOT/'combat_pc/reference/M10_CHARGE_INPUT_SOURCE_FACTS.json'),'engine':primary['engine'],'execution':primary['execution'],
      'production_hashes':shared,'additional_static_dependency_hashes':dependencies,'repeat_profile':primary['repeat_profile'],'charge_profile':primary['charge_profile'],
      'required_m10_cases':list(REQUIRED_M10_CASES),'required_m10_group_counts':{k:len(v) for k,v in REQUIRED_M10_GROUPS.items()},
      'suites':{},'sample_continuity':continuity,'strike_and_contact_evidence':contacts,'independent_case_oracles':oracles,'profile_timing_audit':timing,
      'cross_rate_comparisons':inherited['comparisons']+comparisons,'inherited_comparison_count':len(inherited['comparisons']),
      'inherited_within_rate_contact_phase_comparisons':inherited['within_rate'],'inherited_observer_equivalence':inherited['observers'],
      'inherited_shield_profile_timing_audit':inherited['shield_timing'],'inherited_shield_contact_evidence':inherited['shield_contacts'],
      'inherited_combo_profile_timing_audit':inherited['combo_timing'],'inherited_combo_contact_evidence':inherited['combo_contacts'],'inherited_prop_scale_comparisons':inherited['prop_scaling'],
      'negative_audit_probes':probes,'execution_recovery':recovery,'execution_recovery_sha256':PINNED[(TESTS/'held_execution_recovery.json').resolve()],'correction_evidence':correction,'correction_artifacts_sha256':correction_artifacts,
      'correction_evidence_sha256':PINNED[(TESTS/'held_correction_evidence.json').resolve()],'console_logs_sha256':logs,
      'compatibility_redirects':redirects,'compatibility_redirects_sha256':PINNED[(TESTS/'held_compatibility_redirects.json').resolve()],
      'preserved_evidence':{'manifest_sha256':PINNED[(TESTS/'held_preserved_evidence.json').resolve()],'file_count':len(preserved['files']),'snapshot_count':len(preserved['snapshots']),'all_recorded_bytes_unchanged':True,**preserved},
      'scenarios':[],'limits':LIMITS}
    for suite,pair in suites.items():
        report['suites'][suite]={str(hz):{'scenarios':len(run['scenarios']),'assertions':run['checks'],'failures':0,'frames':sum(s.get('_audited_frame_count',len(s.get('frames',[]))) for s in run['scenarios']),
          'source_stable':True,'path':f'combat_pc/tests/{FILES[suite]}_{hz}hz.json','sha256':PINNED[(TESTS/f'{FILES[suite]}_{hz}hz.json').resolve()]} for hz,run in pair.items()}
    for i,s in enumerate(primary['scenarios']):
        report['scenarios'].append({'name':s['name'],'passed_at':list(RATES),'assertions_by_rate':{str(hz):[a['label'] for a in suites['held'][hz]['scenarios'][i]['assertions']] for hz in RATES},
          'parameters_by_rate':{str(hz):suites['held'][hz]['scenarios'][i]['params'] for hz in RATES},
          'traces':{str(hz):{'path':f'combat_pc/tests/held_results_{hz}hz.json','json_pointer':f'/scenarios/{i}'} for hz in RATES}})
    markdown=render_markdown(report)
    for path,digest in PINNED.items():require(sha(path)==digest,f'Evidence changed during report generation: {path}')
    if '--check-only' in sys.argv:
        print(f'PASS (read-only): 114 M10 cases, 20 runs, {len(report["cross_rate_comparisons"])} cross-rate bounds, {len(timing)} M10 timing checks, {len(probes)} negative probes')
        return
    (ROOT/'combat_pc/held_verification.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    (ROOT/'combat_pc/held_verification.md').write_text(markdown)
    print(f'PASS: 114 M10 cases; ten paired suites; {len(report["cross_rate_comparisons"])} cross-rate bounds; 518 historical files and nine snapshots unchanged')


def render_markdown(report):
    held=report['suites']['held']; totals={};clocks={}
    for hz in ('120','60'):
        totals[hz]=Counter();clocks[hz]=Counter()
        for case in report['strike_and_contact_evidence'][hz].values():
            totals[hz].update({k:v for k,v in case.items() if type(v) is int});clocks[hz].update(case['independent_clock_transition_checks'])
    lines=['# Held-input verification','',
      f'**Passed at 120 Hz and 60 Hz:** 114 independent M10 scenarios and {held["120"]["assertions"]} assertions at each rate. All nine earlier suites also pass against the same final controller. All twenty complete runs have zero failed assertions, stable source hashes and clean engine logs.','',
      f'Controller SHA-256: `{report["controller_sha256"]}`. The [detailed report](held_verification.json) pins the final harness, run traces, logs, production inputs, authored resources, research, correction proofs, 518 historical files and nine immutable snapshots.','',
      '## Selected authored MOKSHA policy','',
      'Null and fresh-only input profiles preserve ordinary fresh-press attacks. Optional repeat follows the existing three-step chain, or the null-chain single swing, with one synthetic offer per admitted callback. It uses the ordinary finite queue and reuse locks. A natural cycle must finish recovery and the 0.08-second actor-time restart before another begins. Release discards synthetic pending intent; a separately captured fresh tap keeps its documented finite buffer.','',
      'Charge uses a Starter Slash, opens its branch after 0.06 seconds of recovery, then begins its own clock at zero. An uninterrupted 0.45-second load automatically requests one Charged Thrust. Physical release is sampled before clocks and wins on the readiness callback. Continued holding cannot repeat or rearm the completed charge; a distinct release and admitted press is required. These values and choices are original MOKSHA policy, not recovered Dead Cells behavior.','',
      '| Step | Windup / active / recovery | Damage | Impulse | Prop scale |', '|---|---|---:|---|---:|']
    for key in ('charge_starter','charge_strike'):
        p=report['charge_profile'][key];lines.append(f'| {p["step_label"]} | {p["windup_seconds"]:.3f} / {p["active_seconds"]:.3f} / {p["recovery_seconds"]:.3f} s | {p["damage"]} | {p["impulse"]} | {p["prop_launch_scale"]} |')
    lines += ['', 'The thrust uses a 44×24 px contact volume, ordinary swept grounded speed of 260 px/s, 0.06-second contact pause and 1.25 strike loudness. Loading uses a 0.35 movement scale. Manual turning intersects host permissions; active entry freezes the strike-facing direction. No target seeking, extra gravity rule, hover, jump refund or airborne dash is introduced.','',
      '## Independent audit and real contact evidence','',
      'The auditor uses an independently transcribed case inventory and reconstructs profile boundaries from raw events and consecutive physics callbacks. It checks physical input edges, admitted hold identity, request identity/kind, charge identity and strike serial separately. Repeat requests retain their original physical edge, while each admitted strike receives its own serial. Release, expiry, configuration replacement, disable, hurt, reset and accepted traversal replacement cannot revive an old hold.','',
      '| Observed population | 120 Hz | 60 Hz |','|---|---:|---:|']
    for label,key in [('Committed strikes','committed_strikes'),('Charge transition requests','charge_commits'),('Installed charged strikes','installed_charged_strikes'),('Actor contact admissions','unique_actor_contact_admissions'),('Passive target effects applied','passive_target_applications'),('Passive target effects acknowledged afterward','passive_target_acknowledgements'),('Already-applied effects without later acknowledgement','applied_target_effects_without_later_acknowledgement'),('Actual rigid-body launches acknowledged','prop_launch_acknowledgements')]:
        lines.append(f'| {label} | {totals["120"][key]} | {totals["60"][key]} |')
    lines += ['', 'These are different populations. A charge transition callback can be superseded before a thrust is installed. A strike admission can be superseded before a receiver applies damage. The receiver-reset case applies one effect and then resets the source, so its later adapter acknowledgement is correctly absent. The contact-acknowledgement reset case retains its already-issued receipt. The real crate cases independently record rigid velocity, outward displacement, launch count, charge and a NoiseBus event at the actual launch position.','',
      'Mirrored target, whiff and occlusion cases, two targets in one sample, and synchronous callbacks verify per-strike deduplication and frozen payloads. Loading never emits a damage sample. Direct stale-authority API checks remain separate from these real adapter contacts.','',
      '## Timing, movement and compatibility','',
      f'The new auditor passes {len(report["profile_timing_audit"]):,} M10 profile timing checks. Across the ten paired suites, {len(report["cross_rate_comparisons"]):,} numerical comparisons pass, including all {report["inherited_comparison_count"]:,} inherited bounds without widening or omission. Existing shield and combo timing/contact validators and prop-scaling checks run read-only on the new compatibility traces.','',
      'Charge, pending input, restart, reuse and shield clocks are checked independently. Callbacks beginning in local hitpause contribute no actor time; input capture still occurs. Ordinary phase endpoints allow one callback of quantization, and valid minimum phases allow up to three to preserve a real contact opportunity. Repeat restart permits two endpoint callbacks because request offers occur before clock advancement. No arbitrary delta or frame-rate equivalence is claimed.','',
      'Grounded, rising, falling, real slope support, a thin wall, a low roof, soft/hard landing, moving/removed support, one-way drop and climb/wall/dive transitions exercise the shared collision and resource budgets. Initial simultaneous shield input, already active nonholdable shield and shield reuse locks prevent parallel charge ownership. A denied readiness replacement leaves a valid charge intact; an accepted replacement wins.','',
      '| Suite | Scenarios per rate | Assertions at 120 Hz | Assertions at 60 Hz |','|---|---:|---:|---:|']
    for suite,pair in report['suites'].items():lines.append(f'| {suite.replace("_"," ")} | {pair["120"]["scenarios"]} | {pair["120"]["assertions"]} | {pair["60"]["assertions"]} |')
    lines += ['', '## Corrections, evidence preservation and audit self-checks','']
    for row in report['correction_evidence']['corrections']:lines.append(f'- **{row["issue"]}** Evidence origin: {row["evidence_kind"]}. The final named cases are independently checked at both rates.')
    lines += ['', 'The initial paused-release draft incorrectly rejected a legitimate separate fresh press. That is retained as a harness clarification, not a production defect: the old charge identity must remain cancelled while a new physical press may create a new finite episode. Implementation-sourced before/after reproductions and independently discovered trace defects keep their distinct provenance in the [correction record](tests/held_correction_evidence.json).','',
      f'{len(report["negative_audit_probes"])} in-memory corruption probes are rejected: changed hold provenance, changed charge-request linkage, duplicate commit, a charge clock advancing during pause, missing prop noise, missing rigid momentum and an acknowledgement without a target application. No retained evidence is modified by these probes.','',
      'All 518 recorded historical files and all nine M1–M9 snapshot archives retain their exact SHA-256 bytes. The nine earlier harnesses run with output paths redirected only; their logic, case order, parameters, assertions and numerical tolerances are preserved. Runtime/hash inventories are checked at both run endpoints and again before writing this report. Additional static transitive input hashes are labelled separately from run-time start/end evidence.','',
      'One initial combo120 compatibility process ended with external exit code -9 before completion and without an engine diagnostic. Its cause is unconfirmed. That attempt is retained separately and does not count toward acceptance. The same output-only harness was rerun alone; its complete 295-case/1,360-check result passed on the final controller. The [execution recovery record](tests/held_execution_recovery.json) pins both attempts.', '',
      '## Limits','']
    lines += ['- '+limit for limit in LIMITS]
    return '\n'.join(lines)+'\n'

if __name__=='__main__':
    try:main()
    except (VerificationError,KeyError,ValueError,TypeError) as error:
        print(f'ACCEPTANCE BLOCKED: {error}',file=sys.stderr);raise SystemExit(1)
