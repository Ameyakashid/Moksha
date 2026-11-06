#!/usr/bin/env python3
"""Isolated optional-route and real reward-lifecycle checks; immutable output directories."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
ROUTE_SCRIPT = 'res://campaign/quality/nov6_optional/all_optional_observer_v7.gd'
DISTRICTS = '''city_clinic city_records city_evac_spine l2_capacitor_mill l2_stamping_galleries l2_thermal_foundry l2_union_dispatch l3_inundated_market l3_water_clinic l3_refuge_terraces l3_drainage_commons works_receiving works_baffle_hall works_cargo_exchange works_memory_loom works_service_refuge works_dispatch_refusal crown_ascent crown_witness_galleries crown_manual_governor crown_refuge_channel crown_coolant_interlock crown_last_warden crown_choice_threshold'''.split()

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run_case(case: dict, output: Path, seconds: int) -> dict:
    directory = output / case['name']
    directory.mkdir()
    env = dict(os.environ, MOKSHA_QUALITY_ISOLATED='1')
    for key, leaf in [('HOME','home'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
        env[key] = str(directory / leaf)
        Path(env[key]).mkdir()
    report = directory / 'report.json'
    command = [os.environ.get('GODOT_BIN','godot'),'--headless','--fixed-fps',str(case['hz']),'--path',str(ROOT),'--script',case['script'],'--',f"--hz={case['hz']}",f'--output={report}']
    if case.get('district'):
        command += [f"--district={case['district']}",f'--seconds={seconds}']
        if case['sight'] == 'traded': command += ['--sacrifice']
    start = time.monotonic()
    with (directory / 'run.log').open('w') as log:
        try:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=max(900, seconds*5))
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
    log_text = (directory / 'run.log').read_text()
    errors = [line for line in log_text.splitlines() if line.lstrip().startswith(('ERROR:','SCRIPT ERROR:'))]
    try:
        data = json.loads(report.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        data = {}
    drift = []
    for name, digest in data.get('source_hashes',{}).items():
        path = ROOT / name.removeprefix('res://')
        if not path.is_file() or sha(path) != digest: drift.append(name)
    passed = code == 0 and not errors and data.get('passed') is True and not data.get('source_drift') and not drift and 'OPTIONAL_' in log_text
    receipt = dict(case, passed=passed, exit_code=code, engine_errors=errors, source_drift_after_run=drift, failures=data.get('failures',[]), report=str(report.relative_to(output)), report_sha256=sha(report) if report.exists() else None, log_sha256=sha(directory/'run.log'), wall_seconds=round(time.monotonic()-start,3), bot_active_seconds=data.get('bot_active_seconds'), collections=data.get('collections'), optional_goals=sum(bool(g.get('optional')) for g in data.get('goals_observed',{}).values()), rewards=len(data.get('actual_rewards',{})))
    (directory/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(f"{case['name']}: {'PASS' if passed else 'FAIL'}",flush=True)
    return receipt

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path, help='NEW evidence directory, never an existing one')
    parser.add_argument('--kind', choices=['routes','lifecycle','all'], default='all')
    parser.add_argument('--district', choices=DISTRICTS, action='append', help='Subset of route districts; default all 24')
    parser.add_argument('--hz',type=int,choices=[60,120],action='append',help='Route rates; default 60. Lifecycle always covers both.')
    parser.add_argument('--sight',choices=['retained','traded','both'],default='retained')
    parser.add_argument('--seconds',type=int,default=360,help='Per-route simulated-time limit')
    parser.add_argument('--workers',type=int,default=2)
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True,exist_ok=False)
    cases = []
    if args.kind in ['lifecycle','all']:
        for name in ['reward_lifecycle','agility_lifecycle']:
            for hz in [60,120]: cases.append(dict(name=f'{name}_{hz}',script=f'res://campaign/quality/nov6_optional/{name}.gd',hz=hz))
    if args.kind in ['routes','all']:
        for district in args.district or DISTRICTS:
            for hz in args.hz or [60]:
                for sight in ['retained','traded'] if args.sight=='both' else [args.sight]:
                    cases.append(dict(name=f'{district}_{hz}_{sight}',script=ROUTE_SCRIPT,hz=hz,district=district,sight=sight))
    with ThreadPoolExecutor(max_workers=max(1,min(args.workers,4))) as pool:
        receipts = list(pool.map(lambda case:run_case(case,output,args.seconds),cases))
    summary = dict(passed=all(case['passed'] for case in receipts),cases=receipts,runner_sha256=sha(Path(__file__)),human_duration_validated=False,full_campaign_evidence=False,scope='Explicit district/spawn/sight fixtures and ordinary inputs thereafter. No measured-phase actor, health, enemy, collision or goal writes. Routes are isolated districts, not continuous campaign runs. Lifecycle checks use temporary saves.')
    (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(f"OPTIONAL_SUITE passed={summary['passed']} cases={len(cases)} output={output}")
    return 0 if summary['passed'] else 1
if __name__ == '__main__':
    raise SystemExit(main())
