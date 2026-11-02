#!/usr/bin/env python3
"""Record seeded raw-input schedules, replay in fresh Godot processes, compare traces.

No golden files are silently regenerated: this gate tests same-build repeatability,
not gameplay correctness. Keep the input and first-divergence report for debugging.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(ROOT.rglob('*'))
            if p.is_file() and '.godot' not in p.parts and
            (p.suffix in ('.gd', '.tscn', '.tres', '.py') or p.name in ('project.godot', 'assets_budgets.json'))}


def engine_errors(log):
    """Normalize terminal color and indentation before treating diagnostics as failures."""
    clean = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", log)
    return [line.strip() for line in clean.splitlines()
            if line.lstrip().startswith(("ERROR:", "SCRIPT ERROR:"))]


def schedule(seed, hz, seconds):
    rng = random.Random(seed)
    frames = []
    direction = 'right'
    for tick in range(hz * seconds):
        if tick % (hz // 2) == 0:
            direction = rng.choice(['right', 'right', 'left', 'idle'])
        command = {} if direction == 'idle' else {direction: 1.0}
        # Fresh presses, holds, releases and simultaneous movement/combat.
        if tick % (hz // 2) < rng.randrange(1, 5):
            command['jump'] = True
        if tick % (hz // 3) == 0:
            command['attack'] = True
        if (tick // (hz // 2)) % 5 == 4:
            command['shield'] = True
        frames.append(command)
    return {'seed': seed, 'hz': hz, 'frames': frames}


def first_difference(left, right):
    for tick, (a, b) in enumerate(zip(left, right)):
        if a != b:
            return {'tick': tick, 'record': a, 'replay': b}
    if len(left) != len(right):
        return {'tick': min(len(left), len(right)), 'record_length': len(left), 'replay_length': len(right)}
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--seeds', type=int, nargs='+', default=[7, 83, 2026])
    parser.add_argument('--hz', type=int, nargs='+', choices=[60, 120], default=[60, 120])
    parser.add_argument('--seconds', type=int, default=12)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 120:
        parser.error('--seconds must be 1..120')
    output = (args.output or Path(tempfile.mkdtemp(prefix='moksha-replay-'))).resolve()
    output.mkdir(parents=True, exist_ok=True)
    before = sources()
    cases = []
    for hz in args.hz:
        for seed in args.seeds:
            case_dir = output / f'{hz}hz-seed{seed}'
            case_dir.mkdir(exist_ok=True)
            input_file = case_dir / 'input.json'
            input_file.write_text(json.dumps(schedule(seed, hz, args.seconds), separators=(',', ':')))
            runs = []
            traces = []
            for label in ('record', 'replay'):
                with tempfile.TemporaryDirectory(prefix='moksha-replay-env-') as home:
                    env = dict(os.environ)
                    for name in ('HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
                        env[name] = str(Path(home) / name)
                        Path(env[name]).mkdir()
                    report_path = case_dir / f'{label}.json'
                    report_path.unlink(missing_ok=True)
                    cmd = [env.get('GODOT_BIN', 'godot'), '--headless', '--fixed-fps', str(hz), '--path', str(ROOT), '--script', 'res://campaign/quality/replay_probe.gd', '--', f'--input={input_file}', f'--output={report_path}']
                    start = time.monotonic()
                    try:
                        run = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=180)
                        code, log = run.returncode, run.stdout + run.stderr
                    except subprocess.TimeoutExpired:
                        code, log = 124, 'Replay process timed out'
                    (case_dir / f'{label}.log').write_text(log)
                    errors = engine_errors(log)
                    try:
                        report = json.loads(report_path.read_text())
                    except (OSError, ValueError):
                        report = {}
                    trace = report.get('trace', [])
                    coverage = {'x_span': round(max((t['position'][0] for t in trace), default=0) - min((t['position'][0] for t in trace), default=0), 4), 'actions': sorted(set(t['action'] for t in trace)), 'weapon_phases': sorted(set(t.get('weapon', '') for t in trace)), 'shield_phases': sorted(set(t.get('shield', '') for t in trace)), 'min_health': min((t['health'] for t in trace), default=None)}
                    passed = code == 0 and not errors and bool(trace) and 'REPLAY_RESULT ' in log and report.get('input_sha256') == digest(input_file) and (len(trace) == hz * args.seconds or trace[-1]['state'] == 'dead') and coverage['x_span'] > 1
                    runs.append({'run': label, 'passed': passed, 'exit_code': code, 'engine_errors': errors, 'engine': report.get('engine'), 'ticks': len(trace), 'coverage': coverage, 'wall_seconds_not_fps': round(time.monotonic()-start, 3), 'trace_sha256': hashlib.sha256(json.dumps(trace, sort_keys=True).encode()).hexdigest()})
                    traces.append(trace)
            divergence = first_difference(*traces)
            case = {'hz': hz, 'seed': seed, 'input_sha256': digest(input_file), 'passed': all(r['passed'] for r in runs) and divergence is None, 'runs': runs, 'first_divergence': divergence}
            cases.append(case)
            print(f"Replay {hz} Hz seed {seed}: {'PASS' if case['passed'] else 'FAIL'}", flush=True)
    after = sources()
    drift = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
    summary = {'passed': all(c['passed'] for c in cases) and not drift, 'cases': cases, 'source_hashes': before, 'source_drift': drift, 'scope': 'Same source/build/environment, independent process pair per seed/rate. Opening-district bounded real-physics traces; not full-campaign balance, human timing, rendered FPS or cross-platform determinism.'}
    (output / 'replay_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(output / 'replay_summary.json')
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
