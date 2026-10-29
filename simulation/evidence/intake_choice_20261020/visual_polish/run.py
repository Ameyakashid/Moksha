from pathlib import Path
import subprocess,os,json,hashlib,re
root=Path('intake_candidate').resolve();out=Path('intake_polish').resolve();env=dict(os.environ,XDG_DATA_HOME=str(out/'data'),XDG_CONFIG_HOME=str(out/'config'),XDG_CACHE_HOME=str(out/'cache'))
base=['godot','--headless','--path',str(root)]
results=[]
for hz in (60,120):
 for approach in ('upper','lower'):
  name=f'{approach}_{hz}';r=subprocess.run(base+['--fixed-fps',str(hz),'--script','res://demo/tests/intake_route_bot.gd','--',f'--hz={hz}',f'--approach={approach}'],env=env,capture_output=True,text=True,timeout=180);log=r.stdout+r.stderr;(out/(name+'.log')).write_text(log)
  p=root/f'demo/evidence/intake_{approach}_{hz}hz.json';data=json.loads(p.read_text());(out/p.name).write_bytes(p.read_bytes());errors=[s for s in log.splitlines() if re.match(r'^(ERROR:|SCRIPT ERROR:|FAIL\b)',s)]
  results.append({'name':name,'passed':r.returncode==0 and data['passed'] and not errors,'errors':errors,'report_sha256':hashlib.sha256(p.read_bytes()).hexdigest()});print(results[-1],flush=True)
subprocess.run(base+['--script',str(Path('intake_acceptance/check_scope.gd').resolve()),'--',str(Path('intake_acceptance/baseline_sectors.txt').resolve()),str(out/'scope.json')],env=env,check=True,capture_output=True)
p=subprocess.run(['python','intake_acceptance/run_intake_lifecycle.py','polished'],env=env,capture_output=True,text=True,timeout=240);(out/'lifecycle.log').write_text(p.stdout+p.stderr);results.append({'name':'lifecycle_both_rates','passed':p.returncode==0});print(results[-1],flush=True)
report={'stages':results,'passed':all(r['passed'] for r in results),'module_sha256':hashlib.sha256((root/'demo/areas/quarantine_intake.gd').read_bytes()).hexdigest(),'scope':'Sign-only visual polish:4actual-input approach routes and58lifecycle checks fresh; prior full routes/recovery retained with pre-polish source provenance.'};(out/'results.json').write_text(json.dumps(report,indent=2));raise SystemExit(0 if report['passed'] else 1)
