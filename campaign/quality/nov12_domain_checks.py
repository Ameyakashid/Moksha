#!/usr/bin/env python3
"""Focused acceptance for the campaign's pure build and checkpoint policies."""
import argparse
import json
import os
from pathlib import Path
import tempfile
import time
from run_quality import ROOT, hashes, run_stage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = (args.output or ROOT / 'campaign/quality/results' / time.strftime('nov12-domain-%Y%m%d-%H%M%S')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    before = hashes()
    rows = []
    godot = os.environ.get('GODOT_BIN', 'godot')
    with tempfile.TemporaryDirectory(prefix='moksha-domain-') as temporary:
        env = dict(os.environ, MOKSHA_QUALITY_ISOLATED='1')
        for key in ('HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
            path = Path(temporary) / key
            path.mkdir()
            env[key] = str(path)
        stages = [
            ('import', [godot, '--headless', '--editor', '--import', '--path', str(ROOT)], None),
            ('content_contract', [godot, '--headless', '--path', str(ROOT), '--script', 'res://campaign/quality/nov12_content_contracts.gd'], 'NOV12_CONTENT_RESULT '),
            ('pure_domain', [godot, '--headless', '--path', str(ROOT), '--script', 'res://campaign/quality/nov12_domain_contracts.gd'], 'NOV12_DOMAIN_CONTRACT_RESULT '),
            ('district_smoke', [godot, '--headless', '--path', str(ROOT), '--script', 'res://campaign/tests/campaign_smoke.gd'], 'SMOKE_DISTRICTS=32'),
        ]
        for rate in (60, 120):
            for label, script, marker, save in (
                ('health_assembly', 'nov12_health_assembly.gd', 'NOV12_ASSEMBLY_RESULT ', True),
                ('incoming_health', '../qa_audit/incoming_health.gd', 'INCOMING_HEALTH_FAILURES []', True),
                ('live_build', 'nov6_gameplay_build.gd', 'NOV6_GAMEPLAY_BUILD_RESULT ', False),
                ('save_feedback', 'nov6_gameplay_save_feedback.gd', 'NOV6_GAMEPLAY_SAVE_FEEDBACK_RESULT ', True),
                ('adversarial_save', 'state_save_adversarial.gd', 'STATE_SAVE_RESULT ', True),
            ):
                command = [godot, '--headless', '--path', str(ROOT), '--fixed-fps', str(rate), '--script', 'res://campaign/quality/' + script, '--', '--hz=' + str(rate)]
                if save:
                    command.append('--isolated-save-tests')
                stages.append((f'{label}_{rate}', command, marker))
        for name, command, marker in stages:
            row = run_stage(name, command, env, output, marker, timeout=300)
            rows.append(row)
            print(json.dumps(row), flush=True)
            if name == 'import' and not row['passed']:
                break
    after = hashes()
    drift = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    report = {'scope': 'Pure domain contracts plus inherited live-build/save fixtures and district smoke; not a full playthrough or platform acceptance.', 'source_sha256': before, 'source_drift': drift, 'stages': rows, 'passed': len(rows) == 14 and not drift and all(r['passed'] for r in rows)}
    (output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Report:', output / 'summary.json')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
