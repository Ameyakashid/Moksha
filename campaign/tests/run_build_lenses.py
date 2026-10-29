#!/usr/bin/env python3
"""Additional full retained-sight runs for the two non-neutral title choices."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import os,subprocess,json,time,hashlib,argparse
root=Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--lens',choices=['strength','agility']);args=a.parse_args()
def run(lens):
 name=f'full_route_60_{lens}_retained';log=root/'campaign/tests'/f'{name}.log';output=log.with_suffix('.json')
 if output.exists():
  history=output.parent/'history';history.mkdir(exist_ok=True);output.rename(history/f'{output.stem}_{time.time_ns()}.json')
 env=dict(os.environ,HOME='/tmp/moksha-lenses/home',XDG_DATA_HOME='/tmp/moksha-lenses/data',XDG_CONFIG_HOME='/tmp/moksha-lenses/config',XDG_CACHE_HOME='/tmp/moksha-lenses/cache')
 for k in ('HOME','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'):Path(env[k]).mkdir(parents=True,exist_ok=True)
 script='res://campaign/tests/full_campaign_strength_route.gd' if lens=='strength' else 'res://campaign/tests/full_campaign_route.gd'
 command=[os.environ.get('GODOT_BIN','godot'),'--headless','--fixed-fps','60','--path',str(root),'--script',script,'--','--hz=60',f'--lens={lens}']
 with log.open('w') as out:p=subprocess.run(command,stdout=out,stderr=subprocess.STDOUT,env=env,timeout=3600)
 text=log.read_text();errors=[x for x in text.splitlines() if x.startswith(('SCRIPT ERROR:','ERROR:'))];report=json.loads(output.read_text()) if output.exists() else {}
 result=dict(lens=lens,observer_script=script,passed=p.returncode==0 and not errors and report.get('passed') is True and 'FULL_CAMPAIGN_RESULT ' in text,exit_code=p.returncode,errors=errors,failures=report.get('failures'),active_seconds=report.get('active_seconds'),report=str(output.relative_to(root)),sha256=hashlib.sha256(output.read_bytes()).hexdigest() if output.exists() else None)
 print(lens,result['passed'],result['active_seconds'],result['failures'],flush=True);return result
with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run,[args.lens] if args.lens else ['strength','agility']))
(root/'campaign/tests'/('build_lens_single_result.json' if args.lens else 'build_lens_matrix.json')).write_text(json.dumps({'passed':all(r['passed'] for r in results),'cases':results,'human_duration_validated':False},indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
