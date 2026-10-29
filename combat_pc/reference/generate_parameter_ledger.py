"""Label authored profile defaults and example-chain overrides with provenance.

This records MOKSHA configuration; it does not manufacture recovered Dead Cells tuning.
"""
from pathlib import Path
import hashlib
import json
import re

module = Path(__file__).resolve().parents[1]
profiles = [module / ('resources/' + name + '.gd') for name in (
    'movement_profile', 'combat_profile', 'shield_profile', 'melee_step', 'melee_chain', 'melee_input_profile')]
profiles.append(module / 'components/attack_entry_facing_host.gd')
profiles.append(module / 'components/health_component.gd')
profiles.append(module / 'components/defeat_response.gd')
profiles.append(module / 'components/noise_relay.gd')
profiles.append(module / 'components/surface_pulse.gd')
profiles.append(module / 'components/physics_contact_noise.gd')
profiles.append(module / 'resources/contact_noise_profile.gd')
profiles.append(module / 'components/character_footsteps.gd')
profiles.append(module / 'resources/footstep_profile.gd')
profiles.append(module / 'resources/ground_response_profile.gd')
profiles.append(module / 'resources/ground_presentation_profile.gd')
profiles.append(module / 'resources/air_response_profile.gd')
profiles.append(module / 'resources/knockback_profile.gd')
seed = {'run_speed': 218.0, 'jump_speed': 365.0, 'gravity': 1100.0}


def parse_value(raw):
    raw = raw.strip().removesuffix(':').strip()
    if raw in ('true', 'false'):
        return raw == 'true'
    if raw.startswith('Vector2('):
        return [float(x.strip()) for x in raw[8:-1].split(',')]
    if raw.startswith('PackedStringArray('):
        return json.loads('[' + raw[len('PackedStringArray('):-1] + ']')
    if raw.startswith('&"'):
        return json.loads(raw[1:])
    if raw in ('Mode.FRESH_ONLY', 'Mode.HELD_REPEAT', 'Mode.HELD_CHARGE'):
        return ('Mode.FRESH_ONLY', 'Mode.HELD_REPEAT', 'Mode.HELD_CHARGE').index(raw)
    try:
        return json.loads(raw)
    except (ValueError, TypeError):
        return None


def units_for(name, value):
    if isinstance(value, bool): return 'boolean'
    if name == 'landing_speed_scale': return 'pixels/second per authored loudness unit'
    if name == 'loudness_speed_scale': return 'pixels/second per authored loudness unit'
    if name in ('max_contacts_reported', 'recent_receipt_limit'): return 'count'
    if name == 'mode': return 'enum: 0=fresh only, 1=held repeat, 2=held charge'
    if name in ('next_step', 'start_step'): return 'zero-based step index; -1 ends chain where allowed'
    if name == 'steps': return 'resource references'
    if name.endswith('cancels'): return 'permitted action identifiers'
    if isinstance(value, str): return 'label or identifier'
    if name.endswith('seconds') or 'delay' in name or 'timeout' in name or name in (
        'roll_jump_cancel_after', 'roll_attack_cancel_after', 'roll_invulnerable_from',
        'roll_invulnerable_until', 'parry_window_from', 'parry_window_until',
        'hold_cancel_after', 'recovery_cancel_after'):
        return 'seconds'
    if 'acceleration' in name or name.endswith(('braking', 'drag')) or name == 'gravity':
        return 'pixels/second^2'
    if name == 'wall_rearm_policy': return 'enum: 0=separation and recontact, 1=ground contact only'
    if any(s in name for s in ('multiplier', 'loudness', 'scale')) or name in (
        'wall_toward_threshold', 'climb_entry_vertical_margin', 'contact_height_ratio',
        'minimum_incoming_dot', 'guard_absorption'):
        return 'unitless'
    if 'speed' in name or name == 'jump_release_rise_cap': return 'pixels/second'
    if 'degrees' in name: return 'degrees'
    if 'damage' in name or name == 'maximum_health': return 'authored damage/health units'
    if 'impulse' in name: return 'target impulse adapter units'
    if 'count' in name: return 'count'
    return 'pixels'


rows = []
for profile in profiles:
    if not profile.exists(): continue
    for name, raw in re.findall(r'@export(?:_\w+\([^\n]+\))? var (\w+)\s*(?::[^=\n]+)?\s*:?=\s*([^\n#]+)', profile.read_text()):
        value = parse_value(raw)
        if value is None: continue
        reason = 'Original MOKSHA implementation/tuning choice; no recovered Dead Cells value.'
        if name in seed and value == seed[name]:
            reason = "Seeded from the preserved MOKSHA controller's authored value."
        if name == 'coyote_seconds':
            reason = "Authored candidate informed by the developer's historical approximate2–3-frame example; not an exact v35 constant."
        if name == 'guard_absorption':
            reason = "Authored MOKSHA default informed by the developer's historical approximate75% absorption statement (Update4,2017); not a recovered v35 constant."
        rows.append({'resource': str(profile.relative_to(module)), 'parameter': name,
                     'default': value, 'units': units_for(name, value), 'evidence': 'MOKSHA', 'basis': reason})

chain = module / 'resources/light_chain.tres'
example = {}
if chain.exists():
    section = None
    overrides = {}
    for line in chain.read_text().splitlines():
        match = re.match(r'\[sub_resource .* id="([^"]+)"\]', line)
        if match:
            section = match.group(1)
            overrides[section] = {}
        elif line.startswith('[resource]'):
            section = 'chain'
            overrides[section] = {}
        elif section and ' = ' in line:
            name, raw = line.split(' = ', 1)
            value = parse_value(raw)
            if value is not None: overrides[section][name] = value
    example = {'resource': str(chain.relative_to(module)),
               'sha256': hashlib.sha256(chain.read_bytes()).hexdigest(),
               'ordered_steps': re.findall(r'SubResource\("([^"]+)"\)', chain.read_text()),
               'overrides': overrides,
               'basis': 'Original MOKSHA example. Unspecified step fields inherit melee_step.gd defaults; unspecified chain fields inherit melee_chain.gd. No reference stage count or timing is claimed.'}

input_examples = []
for name in ('held_repeat', 'held_charge'):
    path = module / ('resources/' + name + '.tres')
    if not path.exists(): continue
    section = None
    overrides = {}
    references = {}
    for line in path.read_text().splitlines():
        match = re.match(r'\[sub_resource .* id="([^"]+)"\]', line)
        if match:
            section = match.group(1)
            overrides[section] = {}
        elif line.startswith('[resource]'):
            section = 'input_profile'
            overrides[section] = {}
        elif section and ' = ' in line:
            field, raw = line.split(' = ', 1)
            reference = re.fullmatch(r'SubResource\("([^"]+)"\)', raw)
            if reference:
                references[field] = reference.group(1)
            else:
                value = parse_value(raw)
                if value is not None: overrides[section][field] = value
    input_examples.append({'resource': str(path.relative_to(module)),
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'step_references': references, 'overrides': overrides,
        'basis': 'Original MOKSHA input policy and tuning. Unspecified fields inherit melee_input_profile.gd or melee_step.gd. The Dead Cells evidence establishes a held-input family, not these timings or execution/release semantics.'})

out = {'purpose': 'Explicit provenance for authored movement, combat and shield configuration',
       'profiles': {str(p.relative_to(module)): hashlib.sha256(p.read_bytes()).hexdigest() for p in profiles if p.exists()},
       'reference_commit': '77c3ad263c4187ade6d048ba77bb61f79e6cec44',
       'all_values_are_authored': True, 'exact_dead_cells_parity_claimed': False,
       'parameters': rows, 'example_melee_chain': example, 'example_melee_inputs': input_examples,
       'actor_ability_gates': {name: value == 'true' for name, value in re.findall(r'@export var (allow_drop_through|allow_dive|allow_climb|allow_wall_run|enable_hard_landing|allow_shield|enable_attack_entry_assist) := (true|false)', (module/'player.gd').read_text())}}
sonar = module.parent/'resources/sensory/sonar_tuning.gd'
responsive_chain = module/'resources/responsive_chain.tres'
if responsive_chain.exists():
    text = responsive_chain.read_text()
    out['responsive_melee_chain'] = {
        'resource': str(responsive_chain.relative_to(module)),
        'sha256': hashlib.sha256(responsive_chain.read_bytes()).hexdigest(),
        'base_resource': 'resources/light_chain.tres',
        'early_followup_seconds_in_step_order': [float(v) for v in re.findall(r'^followup_open_seconds = ([0-9.]+)$', text, re.M)],
        'fresh_restart_window_seconds': float(re.search(r'^fresh_restart_window_seconds = ([0-9.]+)$', text, re.M).group(1)),
        'restart_deadline_resource': 'combat_profile.gd:attack_buffer_seconds',
        'basis': 'Original MOKSHA admission tuning. Existing phase timing, poses, hitpause, power and movement are preserved. No recovered Dead Cells windows or scheduler claimed.'}
surface = module/'resources/surface_pulse_default.tres'
out['surface_pulse'] = {'engine_tuning_resource': 'resources/sensory/sonar_tuning.gd', 'engine_tuning_sha256': hashlib.sha256(sonar.read_bytes()).hexdigest(), 'adapter_resource': 'combat_pc/resources/surface_pulse_default.tres', 'adapter_resource_sha256': hashlib.sha256(surface.read_bytes()).hexdigest(), 'basis': 'Preserved MOKSHA sensory engine defaults; adapter selects full-opacity surfaces and disables unrelated presentation. No timing, range, propagation or contour constants changed in M15; no recovered Dead Cells acoustics claimed.'}
(module/'reference/MOKSHA_PARAMETER_LEDGER.json').write_text(json.dumps(out, indent=2)+'\n')
print(f'Recorded {len(rows)} authored profile defaults and {len(example.get("ordered_steps", []))} example chain steps')
