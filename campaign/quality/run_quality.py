#!/usr/bin/env python3
"""Portable fail-closed regression gate; historical receipts are never overwritten."""
import argparse, hashlib, json, os, re, subprocess, sys, tempfile, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

def hashes():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(ROOT.rglob('*')) if p.is_file()
            and not {'.git', '.godot', '__pycache__', 'results'}.intersection(p.relative_to(ROOT).parts)
            and (p.suffix in {'.gd', '.tscn', '.tres', '.py', '.gdshader'} or p.name in {'project.godot', 'assets_budgets.json'})}

def run_stage(name, command, env, output, marker=None, timeout=180):
    start = time.monotonic()
    try:
        proc = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=timeout)
        code, log = proc.returncode, proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as exc:
        code, log = 124, str(exc)
    except OSError as exc:
        code, log = 127, str(exc)
    (output / (name + '.log')).write_text(log)
    clean = re.sub(r'\x1b\[[0-9;]*m', '', log)
    errors = [line for line in clean.splitlines() if re.match(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)', line)]
    return {'name': name, 'command': command, 'exit_code': code, 'errors': errors,
            'marker_found': marker is None or marker in clean,
            'passed': code == 0 and not errors and (marker is None or marker in clean),
            'wall_seconds': round(time.monotonic() - start, 3)}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='New evidence directory (must not already exist)')
    args = parser.parse_args()
    output = (args.output or ROOT / 'campaign/quality/results' / time.strftime('%Y%m%d-%H%M%S')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    before = hashes()
    godot = os.environ.get('GODOT_BIN', 'godot')
    rows = []
    with tempfile.TemporaryDirectory(prefix='moksha-quality-') as temp:
        env = dict(os.environ, MOKSHA_QUALITY_ISOLATED='1')
        for key in ('HOME','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'):
            env[key] = str(Path(temp) / key); Path(env[key]).mkdir()
        version = subprocess.run([godot, '--version'], env=env, capture_output=True, text=True).stdout.strip()
        def stage(name, command, marker=None, timeout=180):
            row = run_stage(name, command, env, output, marker, timeout)
            rows.append(row); print(json.dumps(row), flush=True)
        stage('import', [godot, '--headless', '--editor', '--import', '--path', str(ROOT)], timeout=300)
        stage('smoke', [godot, '--headless', '--path', str(ROOT), '--script', 'res://campaign/tests/campaign_smoke.gd'], 'SMOKE_DISTRICTS=32')
        stage('runner_negative_controls', [sys.executable, 'campaign/quality/runner_unit.py'])
        stage('replay_negative_controls', [sys.executable, 'campaign/quality/replay_checks_unit.py'])
        stage('assets_mutations', [sys.executable, 'campaign/quality/assets_audit_test.py'])
        stage('assets', [sys.executable, 'campaign/quality/assets_audit.py', '--output', str(output / 'assets.json')])
        stage('audio_reproduction', [sys.executable, 'campaign/quality/assets_audio_repro.py'])
        stage('state_negative_controls', [sys.executable, 'campaign/quality/state_negative_controls.py'])
        stage('state_explorer', [godot, '--headless', '--path', str(ROOT), '--script', 'res://campaign/quality/state_explorer.gd'], 'STATE_EXPLORER_RESULT ')
        for hz in (60, 120):
            stage(f'state_save_{hz}', [godot, '--headless', '--path', str(ROOT), '--fixed-fps', str(hz), '--script', 'res://campaign/quality/state_save_adversarial.gd', '--', '--isolated-save-tests', f'--hz={hz}'], 'STATE_SAVE_RESULT ')
            for script in ('incoming_health','save_draft','lifecycle_draft','ui_dependencies'):
                stage(f'{script}_{hz}', [godot, '--headless', '--path', str(ROOT), '--fixed-fps', str(hz), '--script', f'res://campaign/qa_audit/{script}.gd', '--', f'--hz={hz}'], '_FAILURES []')
        stage('replay', [sys.executable, 'campaign/quality/replay_checks.py', '--output', str(output / 'replay')], timeout=900)
    after = hashes()
    drift = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    report = {'scope': 'Focused regression fixtures; not full campaign, native FPS, Windows/audio or human-duration acceptance',
              'godot_version': version, 'source_sha256': before, 'source_drift': drift, 'stages': rows,
              'passed': not drift and all(r['passed'] for r in rows)}
    (output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Report: {output / "summary.json"}')
    return 0 if report['passed'] else 1
if __name__ == '__main__':
    sys.exit(main())
