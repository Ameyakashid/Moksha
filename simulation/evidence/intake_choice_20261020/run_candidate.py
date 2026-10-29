from pathlib import Path
import os,subprocess,json,hashlib,re,time
root=Path('intake_candidate').resolve();out=Path('intake_acceptance/combined').resolve();out.mkdir(exist_ok=False)
env=dict(os.environ,XDG_DATA_HOME=str(out/'data'),XDG_CONFIG_HOME=str(out/'config'),XDG_CACHE_HOME=str(out/'cache'))
base=['godot','--headless','--path',str(root)]
def hashes():return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and p.suffix in {'.gd','.tscn','.tres','.godot','.py'} and not {'.godot','evidence','delivery'}.intersection(p.relative_to(root).parts)}
before=hashes();(out/'frozen_sources.json').write_text(json.dumps(before,indent=2))
jobs=[('import',base+['--editor','--import','--quit'],180),('scope',base+['--script',str(Path('intake_acceptance/check_scope.gd').resolve()),'--',str(Path('intake_acceptance/baseline_sectors.txt').resolve()),str(out/'scope.json')],60)]
for hz in (60,120):
 for test in ['mission_contracts','review_mission_integration','opening_regression','lift_regression','relay_shutter_regression','expanded_integration_regression']:
  jobs.append((test+'_'+str(hz),base+['--fixed-fps',str(hz),'--script','res://demo/tests/'+test+'.gd','--','--hz='+str(hz)],240))
jobs += [('hud_input',base+['--script','res://simulation/tests/hud_input_flow.gd'],120),('routes',['python3','simulation/tests/run_demo_routes.py'],900)]
results=[]
for name,cmd,limit in jobs:
 start=time.monotonic()
 try:
  p=subprocess.run(cmd,cwd=root,env=env,capture_output=True,text=True,timeout=limit);log=p.stdout+p.stderr;code=p.returncode
 except subprocess.TimeoutExpired as e:log='TIMEOUT\n'+str(e.stdout)+str(e.stderr);code=124
 (out/(name+'.log')).write_text(log)
 errors=[s for s in log.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL\b|TIMEOUT)',s)]
 results.append({'name':name,'passed':code==0 and not errors,'exit_code':code,'errors':errors,'seconds':round(time.monotonic()-start,2)})
 print(name,results[-1]['passed'],flush=True);(out/'progress.json').write_text(json.dumps(results,indent=2))
after=hashes();report={'stages':results,'sources_unchanged':before==after,'source_sha256':after,'passed':before==after and all(x['passed'] for x in results),'scope':'Affected campaign regressions and full routes. Isolated Intake route/lifecycle/native proofs reported separately. Not human-duration validation.'}
(out/'results.json').write_text(json.dumps(report,indent=2));raise SystemExit(0 if report['passed'] else 1)
