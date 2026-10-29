"""Run preserved M1–M8 harnesses with only their output destinations changed."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / 'combat_pc/tests/combo_compatibility_redirects.json'
ENV = dict(os.environ, XDG_DATA_HOME='/tmp/moksha-combat-test-data', XDG_CACHE_HOME='/tmp/moksha-combat-test-cache', XDG_CONFIG_HOME='/tmp/moksha-combat-test-config')
failed = []
for suite, row in json.loads(MANIFEST.read_text()).items():
    source = (ROOT / row['original_harness']).read_text()
    assert hashlib.sha256(source.encode()).hexdigest() == row['original_sha256']
    assert source.count(row['old_output']) == 1
    redirected = source.replace(row['old_output'], row['new_output'])
    assert hashlib.sha256(redirected.encode()).hexdigest() == row['redirected_sha256']
    script = Path('/tmp') / ('moksha_m9_' + suite + '.gd')
    script.write_text(redirected)
    for hz in [120, 60]:
        log = ROOT / ('combat_pc/tests/m9_%s_%d.log' % (suite, hz))
        with log.open('w') as output:
            result = subprocess.run(['/usr/local/bin/godot', '--headless', '--fixed-fps', str(hz), '--path', str(ROOT), '--script', str(script), '--', '--hz=' + str(hz)], cwd=ROOT, env=ENV, stdout=output, stderr=subprocess.STDOUT)
        text = log.read_text()
        diagnostics = any(mark in text for mark in ['SCRIPT ERROR:', '\nERROR:', '\nWARNING:', 'FAIL:'])
        print('%s %dHz: exit=%d, diagnostics=%s' % (suite, hz, result.returncode, diagnostics), flush=True)
        if result.returncode or diagnostics:
            failed.append((suite, hz))
            print(text[-3000:], flush=True)
print('M9 compatibility:', 'PASS' if not failed else repr(failed), flush=True)
sys.exit(bool(failed))
