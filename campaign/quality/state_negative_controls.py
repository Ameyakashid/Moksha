"""Inject broken test-only scripts; expect the specific new state guards to fail."""
import os
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[2]
for mutation, message in [('dependency', 'blocked interaction mutated selected objective'),
                          ('physical', 'physical E mutated selected objective')]:
    result = subprocess.run([os.environ.get('GODOT_BIN', 'godot'), '--headless',
                             '--path', str(ROOT), '--script',
                             'res://campaign/quality/state_explorer.gd', '--',
                             '--mutation=' + mutation], capture_output=True, text=True, timeout=30)
    assert result.returncode == 1, (mutation, result.returncode, result.stdout, result.stderr)
    assert message in result.stderr, (mutation, result.stdout, result.stderr)
    assert 'SCRIPT ERROR:' not in result.stderr, result.stderr
    print('PASS injected ' + mutation + ' state mutation rejected')
# The destructive save fixture must reject even its CLI opt-in without isolation.
import tempfile
with tempfile.TemporaryDirectory(prefix='moksha-state-refusal-') as temporary:
    env = dict(os.environ)
    env.pop('MOKSHA_QUALITY_ISOLATED', None)
    for key in ('HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
        env[key] = str(Path(temporary) / key)
        Path(env[key]).mkdir()
    result = subprocess.run([os.environ.get('GODOT_BIN', 'godot'), '--headless',
                             '--path', str(ROOT), '--script',
                             'res://campaign/quality/state_save_adversarial.gd', '--',
                             '--isolated-save-tests'], env=env, capture_output=True,
                            text=True, timeout=30)
    assert result.returncode == 2, (result.returncode, result.stdout, result.stderr)
    assert 'Requires runner isolation marker' in result.stderr, result.stderr
    assert not list(Path(temporary).rglob('moksha_five_levels_v1.json*'))
    print('PASS save fixture refuses missing isolation marker without checkpoint writes')
