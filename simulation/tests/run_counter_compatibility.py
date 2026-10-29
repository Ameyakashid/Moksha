#!/usr/bin/env python3
"""Stock contact, shield/reflection and Health checks, retaining historical files."""
from pathlib import Path
import hashlib,json,os,re,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'simulation/evidence'
env=dict(os.environ,XDG_DATA_HOME='/tmp/moksha-counter-stock-data',XDG_CONFIG_HOME='/tmp/moksha-counter-stock-config',XDG_CACHE_HOME='/tmp/moksha-counter-stock-cache')
def hashes():
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ROOT.rglob('*') if p.is_file() and p.suffix in {'.gd','.tscn','.tres'} and not {'.godot','delivery'}.intersection(p.relative_to(ROOT).parts)}
before=hashes(); results=[]
for hz in (60,120):
    for name in ('combat','combo','shield','health','guard_component_smoke'):
        if name=='guard_component_smoke':
            script=f'combat_pc/components/tests/{name}.gd'; report=ROOT/f'combat_pc/components/tests/{name}_results_{hz}hz.json'; flag=f'--rate={hz}'
        else:
            script=f'combat_pc/tests/{name}_regression.gd'; report=ROOT/f'combat_pc/tests/{name}_results_{hz}hz.json'; flag=f'--hz={hz}'
        original=report.read_bytes() if report.exists() else None
        try:
            run=subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://'+script,'--',flag],env=env,capture_output=True,text=True,timeout=180)
            output=run.stdout+run.stderr
            (OUT/f'counter_stock_{name}_{hz}.log').write_text(output)
            errors=[line for line in output.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL\b)',line)]
            data=json.loads(report.read_text()) if report.exists() else {}
            if report.exists():
                # Full stock reports already exist historically; retain bounded
                # current evidence rather than duplicate multi-megabyte traces.
                summary={key:data[key] for key in ('checks','failures','selected_group','physics_hz','production_hash_stable_during_run','production_hashes_stable','source_hashes','hashes') if key in data}
                if isinstance(summary.get('checks'),list): summary['checks']=len(summary['checks'])
                (OUT/f'counter_stock_{name}_{hz}.json').write_text(json.dumps(summary,indent=2)+'\n')
            checks=data.get('checks'); checks=len(checks) if isinstance(checks,list) else checks
            result=dict(name=name,hz=hz,passed=run.returncode==0 and not errors,exit_code=run.returncode,checks=checks,errors=errors)
            results.append(result);print(json.dumps(result),flush=True)
        finally:
            if original is None:report.unlink(missing_ok=True)
            else:report.write_bytes(original)
after=hashes()
(OUT/'counter_compatibility.json').write_text(json.dumps(dict(stages=results,source_sha256=after,unchanged_during_run=before==after),indent=2)+'\n')
raise SystemExit(0 if before==after and all(r['passed'] for r in results) else 1)
