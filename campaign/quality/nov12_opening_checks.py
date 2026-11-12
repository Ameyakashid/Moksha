#!/usr/bin/env python3
"""Original opening-layout checks; ordinary-input route, isolated player data."""
import argparse
import json
import os
from pathlib import Path
import tempfile
import time
from run_quality import ROOT, hashes, run_stage


def validate_receipt(path, rate):
    try:
        receipt = json.loads(path.read_text())
    except (OSError, ValueError) as error:
        return [str(error)]
    if not isinstance(receipt, dict):
        return ['Receipt must be an object']
    errors = []
    expected = {'passed': True, 'hz': rate, 'deaths': 0, 'failures': [], 'source_drift': [],
                'districts': ['rainline', 'city_clinic', 'city_tram_depot'],
                'clinic_closed_seen': True, 'clinic_open_seen': True,
                'clinic_roof_crossed': True, 'clinic_street_crossed': True}
    for key, value in expected.items():
        if type(receipt.get(key)) is not type(value) or receipt.get(key) != value:
            errors.append('Invalid receipt field: ' + key)
    objectives = receipt.get('objective_receipts', {})
    if not isinstance(objectives, dict) or set(objectives) != set(expected['districts']):
        errors.append('Missing objective receipts')
    else:
        for district, row in objectives.items():
            goals = row.get('required_goals', []) if isinstance(row, dict) else []
            expected_ids = {'rainline': [], 'city_clinic': ['cell', 'generator', 'patients'], 'city_tram_depot': ['schematic', 'auxiliary', 'brake']}[district]
            if not isinstance(goals, list) or [goal.get('id') for goal in goals if isinstance(goal, dict)] != expected_ids or any(not isinstance(goal, dict) or goal.get('completed') is not True for goal in goals):
                errors.append('Incomplete goals: ' + district)
            if district == 'rainline' and row.get('relays') != [0]:
                errors.append('Missing Rainline relay')
    if not receipt.get('source_hashes'):
        errors.append('Missing source hashes')
    return errors

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rates', type=int, nargs='*', default=[60, 120])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = (args.output or Path(tempfile.gettempdir()) / time.strftime('nov12-layout-%Y%m%d-%H%M%S')).resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error('Output must be a fresh directory outside the source tree')
    output.mkdir(parents=True, exist_ok=False)
    godot = os.environ.get('GODOT_BIN', 'godot')
    before = hashes()
    rows = []
    cases = [('import', ['--editor', '--import'], None, 300),
             ('layout_contract', ['--script', 'res://campaign/quality/nov12_opening_layout_contract.gd'], 'NOV12_OPENING_LAYOUT_RESULT ', 60),
             ('all_objective_support', ['--script', 'res://campaign/tests/layout_support.gd'], 'LAYOUT_INVENTORY ', 60)]
    for rate in args.rates:
        cases.append((f'opening_route_{rate}', ['--fixed-fps', str(rate), '--script', 'res://campaign/quality/nov12_opening_route.gd', '--', f'--hz={rate}', '--district-timeout=240', f'--report={output / (str(rate) + ".json")}'], 'NOV12_OPENING_ROUTE_RESULT ', 900))
    for name, tail, marker, timeout in cases:
        with tempfile.TemporaryDirectory(prefix='moksha-nov12-layout-') as temporary:
            env = dict(os.environ)
            for key in ('HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
                directory = Path(temporary) / key
                directory.mkdir()
                env[key] = str(directory)
            row = run_stage(name, [godot, '--headless', '--path', str(ROOT), *tail], env, output, marker, timeout=timeout)
            if name.startswith('opening_route_'):
                rate = int(name.rsplit('_', 1)[1])
                row['receipt_errors'] = validate_receipt(output / (str(rate) + '.json'), rate)
                row['passed'] = row['passed'] and not row['receipt_errors']
            rows.append(row)
            print(json.dumps(row), flush=True)
    after = hashes()
    drift = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    unexpected = drift
    report = {'passed': all(r['passed'] for r in rows) and not unexpected,
              'scope': 'Three opening districts, objective-support inventory across 32 districts. Not human timing or full-campaign acceptance.',
              'stages': rows, 'source_sha256': before, 'source_drift': drift, 'unexpected_source_drift': unexpected}
    (output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print('NOV12_OPENING_CHECKS_RESULT', json.dumps({'passed': report['passed'], 'output': str(output)}))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
