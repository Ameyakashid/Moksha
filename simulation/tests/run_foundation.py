#!/usr/bin/env python3
"""Bounded foundation + existing demo checks; immutable delivery verification."""
from pathlib import Path
import subprocess, os, json, hashlib, re, time, sys
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'simulation/evidence'
OUT.mkdir(exist_ok=True)
env = dict(os.environ, XDG_DATA_HOME='/tmp/moksha-sim-data', XDG_CONFIG_HOME='/tmp/moksha-sim-config', XDG_CACHE_HOME='/tmp/moksha-sim-cache')
base = [os.environ.get('GODOT_BIN','godot'), '--headless', '--path', str(ROOT)]
stages = [('import', ['--editor', '--import', '--quit']), ('sandbox_boot', ['res://simulation/footing_sandbox.tscn', '--fixed-fps', '120', '--quit-after', '180'])]
stages.append(('gym_lifecycle', ['--fixed-fps', '120', '--script', 'res://simulation/tests/gym_lifecycle.gd']))
stages.append(('hearing_sandbox_boot', ['res://simulation/hearing_sandbox.tscn', '--fixed-fps', '120', '--quit-after', '180']))
stages.append(('movement_sandbox_boot', ['res://simulation/movement_sandbox.tscn', '--fixed-fps', '120', '--quit-after', '180']))
stages.append(('impact_sandbox_boot', ['res://simulation/impact_sandbox.tscn', '--fixed-fps', '120', '--quit-after', '180']))
stages.append(('strike_sandbox_boot', ['res://simulation/strike_sandbox.tscn', '--fixed-fps', '120', '--quit-after', '180']))
stages.append(('boundary_review_boot', ['res://simulation/boundary_review.tscn', '--fixed-fps', '120', '--quit-after', '180']))
stages.append(('actor_cargo_review_boot', ['res://simulation/actor_cargo_review.tscn', '--fixed-fps', '120', '--quit-after', '180']))
stages.append(('warden_review_boot', ['res://simulation/warden_review.tscn', '--fixed-fps', '120', '--quit-after', '180']))
stages.append(('sentry_review_boot', ['res://simulation/sentry_review.tscn', '--fixed-fps', '120', '--quit-after', '180']))
stages.append(('bracing_sandbox_boot', ['res://simulation/bracing_sandbox.tscn', '--fixed-fps', '120', '--quit-after', '180']))
stages.append(('projectile_sandbox_boot', ['res://simulation/projectile_sandbox.tscn', '--fixed-fps', '120', '--quit-after', '180']))
for hz in (60,120):
    for name, script in [('boundary','simulation/tests/boundary_regression.gd'), ('actor_cargo_request','simulation/tests/actor_cargo_request_regression.gd'), ('actor_cargo','simulation/tests/actor_cargo_regression.gd'), ('actor_cargo_defense','simulation/tests/actor_cargo_defense_regression.gd'), ('warden_attack_plan','simulation/tests/attack_plan_regression.gd'), ('shared_warden','simulation/tests/warden_regression.gd'), ('warden_projectile','simulation/tests/warden_projectile_regression.gd'), ('warden_factory','simulation/tests/warden_factory_regression.gd'), ('hurt_response','simulation/tests/hurt_response_regression.gd'), ('hurt_projectile','simulation/tests/hurt_projectile_regression.gd'), ('sentry','simulation/tests/sentry_regression.gd'), ('projectile','simulation/tests/projectile_regression.gd'), ('mission_cargo','simulation/tests/mission_cargo_regression.gd'), ('freight_component','demo/tests/freight_component_regression.gd'), ('freight_host','demo/tests/freight_host_contracts.gd'), ('listener','simulation/tests/listener_regression.gd'), ('sentinel','simulation/tests/sentinel_regression.gd'), ('mission_contracts','demo/tests/mission_contracts.gd'), ('mission_integration','demo/tests/review_mission_integration.gd'), ('counter','simulation/tests/shield_counter_regression.gd'), ('strike','simulation/tests/incoming_strike_regression.gd'), ('shared_actor','simulation/tests/shared_actor_regression.gd'), ('impact','simulation/tests/physical_impact_regression.gd'), ('footing','simulation/tests/footing_regression.gd'), ('hearing','simulation/tests/hearing_regression.gd'), ('enemy','demo/tests/enemy_regression.gd'), ('ranged','demo/tests/ranged_regression.gd'), ('warden','demo/tests/warden_regression.gd'), ('expanded_integration','demo/tests/expanded_integration_regression.gd')]:
        stages.append((f'{name}_{hz}', ['--fixed-fps',str(hz),'--script','res://'+script,'--','--hz='+str(hz)]))
stages += [('movement_npc', ['--fixed-fps','120','--script','res://movement/tests/npc_regression.gd'])]
def source_hashes():
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ROOT.rglob('*') if p.is_file() and p.suffix in {'.gd','.tscn','.tres'} and not {'.godot','delivery'}.intersection(p.relative_to(ROOT).parts)}
baseline = source_hashes()
results=[]
for name,args in stages:
    start=time.monotonic()
    run=subprocess.run(base+args,env=env,capture_output=True,text=True,timeout=180)
    output=run.stdout+run.stderr
    (OUT/(name+'.log')).write_text(output)
    errors=[l for l in output.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL\b)',l)]
    ok=run.returncode==0 and not errors
    results.append(dict(name=name,passed=ok,exit_code=run.returncode,errors=errors,seconds=round(time.monotonic()-start,3)))
    print(name, 'PASS' if ok else 'FAIL',flush=True)
archive=Path('/workspace/shared/MOKSHA-The-First-Ascent-v28-Expanded.zip')
sha=hashlib.sha256(archive.read_bytes()).hexdigest() if archive.exists() else None
if sha is not None:
    assert sha=='153fd2824303354b1f70dea66c7ba91b27bc204da9c16a05f9b1a27a29955937'
elif '--require-preservation' in sys.argv:
    raise RuntimeError('Preserved v28 archive is unavailable at '+str(archive))
hashes=source_hashes()
changed = sorted(p for p in set(baseline) | set(hashes) if baseline.get(p) != hashes.get(p))
report=dict(sources_changed_during_run=changed,tested_source_sha256=hashes,scope='Headless actual physics and scene boot; native rendered appearance not tested',stages=results,v28_sha256=sha,preservation='verified' if sha else 'not_run_archive_unavailable')
(OUT/'foundation_report.json').write_text(json.dumps(report,indent=2)+'\n')
raise SystemExit(0 if all(x['passed'] for x in results) and not changed else 1)
