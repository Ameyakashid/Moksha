#!/usr/bin/env python3
"""Production shared sentry acceptance, retaining historical reports; native review is separate."""
from pathlib import Path
import subprocess,os,json,hashlib,re
root=Path(__file__).resolve().parents[2];out=root/'simulation/evidence'
env=dict(os.environ,XDG_DATA_HOME='/tmp/moksha-sentry-final-data',XDG_CONFIG_HOME='/tmp/moksha-sentry-final-config',XDG_CACHE_HOME='/tmp/moksha-sentry-final-cache')
keep={p:p.read_bytes() for p in root.rglob('*') if p.is_file() and not {'.godot','simulation','delivery'}.intersection(p.relative_to(root).parts) and p.suffix in {'.json','.log','.md'}}
def sources():
 return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and not {'.godot','delivery'}.intersection(p.relative_to(root).parts) and p.suffix in {'.gd','.tscn','.tres','.py','.godot'}}
before=sources();result=[]
try:
 for name,cmd in [('foundation',['python3','simulation/tests/run_foundation.py','--require-preservation']),('stock',['python3','simulation/tests/run_counter_compatibility.py']),('historical',['bash','tests/run_all.sh','--require-preservation']),('routes',['python3','simulation/tests/run_demo_routes.py'])]:
  run=subprocess.run(cmd,cwd=root,env=env,capture_output=True,text=True,timeout=1200)
  log=run.stdout+run.stderr;(out/f'sentry_{name}_runner.log').write_text(log)
  print(name,run.returncode,log,flush=True)
  result.append(dict(name=name,exit_code=run.returncode,passed=run.returncode==0))
  if name=='historical':
   (out/'sentry_historical_report.json').write_bytes((root/'tests/flow_all_report.json').read_bytes())
finally:
 for p,blob in keep.items():p.write_bytes(blob)
 for p in list(root.rglob('*')):
  if p.is_file() and not {'.godot','simulation','delivery'}.intersection(p.relative_to(root).parts) and p.suffix in {'.json','.log','.md'} and p not in keep:p.unlink()
after=sources();report=dict(stages=result,unchanged_during_run=before==after,source_sha256=after)
(out/'sentry_final_gates.json').write_text(json.dumps(report,indent=2)+'\n')
print('FINAL',json.dumps({k:v for k,v in report.items() if k!='source_sha256'}),flush=True)
raise SystemExit(0 if before==after and all(x['passed'] for x in result) else 1)
