#!/usr/bin/env python3
"""Run actual complete campaigns. Engine errors fail even with exit status zero."""
from pathlib import Path
import os,subprocess,json,time,hashlib,argparse
from concurrent.futures import ThreadPoolExecutor
root=Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--single',action='store_true');a.add_argument('--hz',type=int,default=60);a.add_argument('--sacrifice',action='store_true');args=a.parse_args()
cases=[(args.hz,args.sacrifice)] if args.single else [(h,b) for h in (60,120) for b in (False,True)]
def run_case(case):
 hz,blind=case
 name=f'full_route_{hz}_neutral_'+('traded' if blind else 'retained')
 env=dict(os.environ,HOME='/tmp/moksha-full/home',XDG_DATA_HOME='/tmp/moksha-full/data',XDG_CONFIG_HOME='/tmp/moksha-full/config',XDG_CACHE_HOME='/tmp/moksha-full/cache')
 for key in ('HOME','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'):Path(env[key]).mkdir(parents=True,exist_ok=True)
 cmd=[os.environ.get('GODOT_BIN','godot'),'--headless','--fixed-fps',str(hz),'--path',str(root),'--script','res://campaign/tests/full_campaign_route.gd','--',f'--hz={hz}']+(['--sacrifice'] if blind else [])
 log=root/'campaign/tests'/f'{name}.log'
 output=log.with_suffix('.json')
 if output.exists():
  history=output.parent/'history';history.mkdir(exist_ok=True)
  output.rename(history/f'{output.stem}_{time.time_ns()}.json')
 start=time.monotonic()
 try:
  with log.open('w') as out:run=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT,env=env,timeout=3600)
  returncode=run.returncode
 except subprocess.TimeoutExpired:
  returncode=124
 text=log.read_text();errors=[line for line in text.splitlines() if line.startswith(('ERROR:','SCRIPT ERROR:'))]
 report=json.loads(output.read_text()) if output.exists() else {}
 passed=returncode==0 and not errors and report.get('passed') is True and 'FULL_CAMPAIGN_RESULT ' in text
 result=dict(name=name,passed=passed,exit_code=returncode,engine_errors=errors,report=str(output.relative_to(root)),report_sha256=hashlib.sha256(output.read_bytes()).hexdigest() if output.exists() else None,wall_seconds=round(time.monotonic()-start,2),active_seconds=report.get('active_seconds'),failures=report.get('failures'))
 print(name,passed,report.get('active_seconds'),report.get('failures'),flush=True)
 return result
with ThreadPoolExecutor(max_workers=min(4,len(cases))) as pool:
 results=list(pool.map(run_case,cases))
(root/'campaign/tests/full_route_matrix.json').write_text(json.dumps({'passed':all(r['passed'] for r in results),'cases':results,'human_duration_validated':False},indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
