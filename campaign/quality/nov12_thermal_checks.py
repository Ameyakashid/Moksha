#!/usr/bin/env python3
"""One clean normal-title Thermal route case, with fresh external evidence."""
import argparse
import json
import os
from pathlib import Path
import subprocess
from run_quality import ROOT, hashes

CASES = {'neutral-exposed': ('neutral', False, 'exposed'),
         'neutral-service': ('neutral', False, 'service'),
         'strength-exposed': ('strength', True, 'exposed'),
         'strength-service': ('strength', True, 'service')}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=CASES, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error('Evidence must be outside source')
    output.mkdir(parents=True, exist_ok=False)
    lens, traded, outbound = CASES[args.case]
    env = dict(os.environ)
    for key in ('HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
        directory = output / key
        directory.mkdir()
        env[key] = str(directory)
    before = hashes()
    command = [os.environ.get('GODOT_BIN', 'godot'), '--headless', '--path', str(ROOT),
               '--fixed-fps', '60', '--script', 'res://campaign/quality/nov12_thermal_route.gd', '--',
               '--hz=60', '--district-timeout=240', '--lens=' + lens,
               '--outbound=' + outbound, '--report=' + str(output / 'receipt.json')]
    if traded:
        command.append('--sacrifice')
    with (output / 'run.log').open('w') as log:
        try:
            code = subprocess.run(command, cwd=ROOT, env=env, stdout=log,
                                  stderr=subprocess.STDOUT, timeout=5400).returncode
        except subprocess.TimeoutExpired:
            code = 124
    errors = [line for line in (output / 'run.log').read_text().splitlines()
              if line.lstrip().startswith(('ERROR:', 'SCRIPT ERROR:'))]
    try:
        receipt = json.loads((output / 'receipt.json').read_text())
        expected = {'passed': True, 'failures': [], 'source_drift': [], 'deaths': 0,
                    'lens': lens, 'blind': traded, 'outbound': outbound,
                    'closed_push_blocked': True, 'outbound_crossed': True,
                    'open_return_crossed': True, 'optional_service_recovered': outbound == 'service'}
        for key, value in expected.items():
            if type(receipt.get(key)) is not type(value) or receipt.get(key) != value:
                errors.append('Receipt mismatch: ' + key)
        goals = receipt['objective_receipts']['l2_thermal_foundry']['required_goals']
        if {goal['id'] for goal in goals} != {'ceramic', 'return', 'feed', 'coolant'}:
            errors.append('Required goal IDs changed')
        if any(goal['completed'] is not True for goal in goals):
            errors.append('Required goals incomplete')
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        errors.append(str(error))
    after = hashes()
    drift = [path for path in before.keys() | after.keys() if before.get(path) != after.get(path)]
    report = {'passed': code == 0 and not errors and not drift, 'case': args.case,
              'exit_code': code, 'errors': errors, 'source_drift': drift, 'source_sha256': before,
              'scope': 'Normal-title automated route through Thermal, not human timing or full campaign.'}
    (output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'passed': report['passed'], 'case': args.case, 'errors': errors, 'source_drift': drift}), flush=True)
    return 0 if report['passed'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
