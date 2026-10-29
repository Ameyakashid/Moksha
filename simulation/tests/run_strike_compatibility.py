#!/usr/bin/env python3
"""Recheck stock ContactAdapter callers without replacing historical reports."""
from pathlib import Path
import hashlib, json, os, re, subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'simulation/evidence'
env=dict(os.environ,XDG_DATA_HOME='/tmp/moksha-strike-data',XDG_CONFIG_HOME='/tmp/moksha-strike-config',XDG_CACHE_HOME='/tmp/moksha-strike-cache')
paths=[ROOT/'combat_pc/player.gd',ROOT/'combat_pc/components/contact_adapter.gd']
before={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
results=[]
for hz in (60,120):
    for name in ('combat','combo'):
        report=ROOT/f'combat_pc/tests/{name}_results_{hz}hz.json'
        saved=report.read_bytes() if report.exists() else None
        try:
            run=subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script',f'res://combat_pc/tests/{name}_regression.gd','--',f'--hz={hz}'],env=env,capture_output=True,text=True,timeout=180)
            output=run.stdout+run.stderr
            (OUT/f'strike_stock_{name}_{hz}.log').write_text(output)
            errors=[line for line in output.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL\b)',line)]
            data=json.loads(report.read_text()) if report.exists() else {}
            result={'name':name,'hz':hz,'passed':run.returncode==0 and not errors,'checks':data.get('checks'),'errors':errors}
            results.append(result)
            print(json.dumps(result),flush=True)
        finally:
            if saved is None:report.unlink(missing_ok=True)
            else:report.write_bytes(saved)
after={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
(OUT/'strike_compatibility.json').write_text(json.dumps({'stages':results,'source_hashes':after,'unchanged_during_run':before==after},indent=2)+'\n')
raise SystemExit(0 if before==after and all(r['passed'] for r in results) else 1)
