#!/usr/bin/env python3
"""Run preserved demo paths while retaining original historical evidence files."""
from pathlib import Path
import subprocess,os,json,hashlib
root=Path(__file__).resolve().parents[2]
def source_hashes():
 return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and p.suffix in {'.gd','.tscn','.tres'} and not {'.godot','delivery'}.intersection(p.relative_to(root).parts)}
baseline=source_hashes()
(root/'simulation/evidence').mkdir(exist_ok=True)
env=dict(os.environ,XDG_DATA_HOME='/tmp/moksha-sim-routes-data',XDG_CONFIG_HOME='/tmp/moksha-sim-config',XDG_CACHE_HOME='/tmp/moksha-sim-cache')
results=[]
for hz in (60,120):
 for sacrifice in (False,True):
  name=f'expanded_mission_route_{hz}hz_'+('sacrificed' if sacrifice else 'retained')
  output=root/'demo/evidence'/f'{name}.json'
  original=output.read_bytes() if output.exists() else None
  command=[os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(root),'--fixed-fps',str(hz),'--script','res://demo/tests/expanded_mission_route_bot.gd','--',f'--hz={hz}']+(['--sacrifice'] if sacrifice else [])
  try:
   run=subprocess.run(command,env=env,capture_output=True,text=True,timeout=180)
   (root/'simulation/evidence'/f'{name}.log').write_text(run.stdout+run.stderr)
   if output.exists() and 'EXPANDED MISSION ROUTE RESULT' in run.stdout:
    data=json.loads(output.read_text());(root/'simulation/evidence'/f'{name}.json').write_bytes(output.read_bytes())
    results.append({k:data[k] for k in ['hz','sacrificed_sight','completed','simulated_active_seconds','deaths','retry_count','failures']})
   results[-1]['exit_code']=run.returncode
   print(name,run.returncode,results[-1] if results else '',flush=True)
  finally:
   if original is not None:output.write_bytes(original)
final_hashes=source_hashes()
changed=sorted(p for p in set(baseline)|set(final_hashes) if baseline.get(p)!=final_hashes.get(p))
report={'routes':results,'sources_changed_during_run':changed,'source_sha256':baseline}
(root/'simulation/evidence/route_summary.json').write_text(json.dumps(report,indent=2)+'\n')
raise SystemExit(0 if len(results)==4 and not changed and all(r['completed'] and r['exit_code']==0 and not r['failures'] for r in results) else 1)
