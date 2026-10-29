#!/usr/bin/env python3
"""Shared warden capability frozen-source acceptance; retain prior checkpoint evidence."""
from pathlib import Path
import subprocess,os,json,hashlib,re,shutil
root=Path(__file__).resolve().parents[2];out=root/'simulation/evidence'
env=dict(os.environ,XDG_DATA_HOME='/tmp/moksha-warden-final-data',XDG_CONFIG_HOME='/tmp/moksha-warden-final-config',XDG_CACHE_HOME='/tmp/moksha-warden-final-cache')
# Save original historical output files, including preceding simulation reports.
keep={p:p.read_bytes() for p in root.rglob('*') if p.is_file() and not {'.godot','delivery'}.intersection(p.relative_to(root).parts) and p.suffix in {'.json','.log','.md'} and not (p.parent==out and p.name.startswith(('warden_', 'shared_warden_'))) and 'warden_initial_gate' not in p.parts}
def sources():
 return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and not {'.godot','delivery'}.intersection(p.relative_to(root).parts) and p.suffix in {'.gd','.tscn','.tres','.py','.godot'}}
def copy_report(source,name):
 if source.exists(): shutil.copyfile(source,out/name)
before=sources();result=[]
try:
 jobs=[('foundation',['python3','simulation/tests/run_foundation.py','--require-preservation']),('stock',['python3','simulation/tests/run_counter_compatibility.py'])]
 for hz in (60,120): jobs.append((f'held_{hz}',[os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(root),'--fixed-fps',str(hz),'--script','res://combat_pc/tests/held_regression.gd','--',f'--hz={hz}']))
 jobs += [('historical',['bash','tests/run_all.sh','--require-preservation']),('routes',['python3','simulation/tests/run_demo_routes.py'])]
 for name,cmd in jobs:
  run=subprocess.run(cmd,cwd=root,env=env,capture_output=True,text=True,timeout=1500)
  log=run.stdout+run.stderr;(out/f'warden_{name}_runner.log').write_text(log)
  errors=[line for line in log.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL\b)',line)]
  print(name,run.returncode,log,flush=True)
  result.append(dict(name=name,exit_code=run.returncode,errors=errors,passed=run.returncode==0 and not errors))
  if name=='foundation':
   copy_report(out/'foundation_report.json','warden_foundation_report.json')
   foundation=json.loads((out/'foundation_report.json').read_text())
   for stage in foundation['stages']: copy_report(out/(stage['name']+'.log'),'warden_gate_'+stage['name']+'.log')
   for hz in (60,120):
    for suite in ('sentry','cargo'): copy_report(out/f'{suite}_{hz}.json',f'warden_production_{suite}_{hz}.json')
   copy_report(root/'demo/evidence/mission_contracts.json','warden_mission_contracts.json')
  elif name=='stock':
   copy_report(out/'counter_compatibility.json','warden_compatibility.json')
   for p in out.glob('counter_stock_*'): copy_report(p,'warden_'+p.name.removeprefix('counter_'))
  elif name.startswith('held_'):
   hz=name.removeprefix('held_');p=root/f'combat_pc/tests/held_results_{hz}hz.json'
   if p.exists():
    data=json.loads(p.read_text()); data['checks']=len(data['checks']) if isinstance(data.get('checks'),list) else data.get('checks')
    for field in ['scenarios']: data.pop(field,None)
    (out/f'warden_held_{hz}.json').write_text(json.dumps(data,indent=2)+'\n')
  elif name=='historical': copy_report(root/'tests/flow_all_report.json','warden_historical_report.json')
  elif name=='routes':
   copy_report(out/'route_summary.json','warden_route_summary.json')
   for p in out.glob('expanded_mission_route_*'): copy_report(p,'warden_'+p.name)
finally:
 for p,blob in keep.items():p.write_bytes(blob)
 # Newly generated historical output outside the new evidence is not retained.
 for p in list(root.rglob('*')):
  if p.is_file() and not {'.godot','simulation','delivery'}.intersection(p.relative_to(root).parts) and p.suffix in {'.json','.log','.md'} and p not in keep:p.unlink()
after=sources();report=dict(stages=result,unchanged_during_run=before==after,source_sha256=after)
(out/'warden_final_gates.json').write_text(json.dumps(report,indent=2)+'\n')
print('FINAL',json.dumps({k:v for k,v in report.items() if k!='source_sha256'}),flush=True)
raise SystemExit(0 if before==after and all(x['passed'] for x in result) else 1)
