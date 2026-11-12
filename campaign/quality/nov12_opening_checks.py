#!/usr/bin/env python3
"""Original opening-layout checks; ordinary-input route, isolated player data."""
import argparse
import json
import os
from pathlib import Path
import tempfile
import time
from run_quality import ROOT, hashes, run_stage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rates', type=int, nargs='*', default=[60, 120])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = (args.output or ROOT / 'campaign/quality/results' / time.strftime('nov12-layout-%Y%m%d-%H%M%S')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    godot = os.environ.get('GODOT_BIN', 'godot')
    before = hashes()
    rows = []
    cases = [('import', ['--editor', '--import'], None, 300),
             ('layout_contract', ['--script', 'res://campaign/quality/nov12_opening_layout_contract.gd'], 'NOV12_OPENING_LAYOUT_RESULT ', 60),
             ('all_objective_support', ['--script', 'res://campaign/tests/layout_support.gd'], 'LAYOUT_INVENTORY ', 60)]
    for rate in args.rates:
        cases.append((f'opening_route_{rate}', ['--fixed-fps', str(rate), '--script', 'res://campaign/quality/nov12_opening_route.gd', '--', f'--hz={rate}', '--district-timeout=240'], 'NOV12_OPENING_ROUTE_RESULT ', 900))
    for name, tail, marker, timeout in cases:
        with tempfile.TemporaryDirectory(prefix='moksha-nov12-layout-') as temporary:
            env = dict(os.environ)
            for key in ('HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
                directory = Path(temporary) / key
                directory.mkdir()
                env[key] = str(directory)
            row = run_stage(name, [godot, '--headless', '--path', str(ROOT), *tail], env, output, marker, timeout=timeout)
            rows.append(row)
            print(json.dumps(row), flush=True)
    after = hashes()
    drift = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    # Route receipts are explicitly named outputs; no production/source drift is permitted.
    permitted = {f'campaign/quality/nov12_opening_route_{rate}.json' for rate in args.rates}
    unexpected = [p for p in drift if p not in permitted]
    report = {'passed': all(r['passed'] for r in rows) and not unexpected,
              'scope': 'Three opening districts, objective-support inventory across 32 districts. Not human timing or full-campaign acceptance.',
              'stages': rows, 'source_sha256': before, 'source_drift': drift, 'unexpected_source_drift': unexpected}
    (output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print('NOV12_OPENING_CHECKS_RESULT', json.dumps({'passed': report['passed'], 'output': str(output)}))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
