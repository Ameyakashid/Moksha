#!/usr/bin/env python3
"""Frozen platform acceptance; preserve all earlier reports and archives."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'simulation/evidence'
GATES=OUT/'static_platform_gates'
GATES.mkdir(exist_ok=True)
ENV=dict(os.environ,XDG_DATA_HOME='/tmp/moksha-platform-final-data',XDG_CONFIG_HOME='/tmp/moksha-platform-final-config',XDG_CACHE_HOME='/tmp/moksha-platform-final-cache')
def ours(p):return any(part.startswith('static_platform') for part in p.relative_to(ROOT).parts)
def sources():
 return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ROOT.rglob('*') if p.is_file() and not {'.godot','delivery'}.intersection(p.relative_to(ROOT).parts) and p.suffix in {'.gd','.tscn','.tres','.py','.godot'}}
def old_reports():
 return [p for p in ROOT.rglob('*') if p.is_file() and not {'.godot','delivery'}.intersection(p.relative_to(ROOT).parts) and p.suffix in {'.json','.log','.md'} and not ours(p)]
keep={p:p.read_bytes() for p in old_reports()}
before=sources();results=[]
(OUT/'static_platform_frozen_sources.json').write_text(json.dumps(before,indent=2)+'\n')
godot=os.environ.get('GODOT_BIN','godot')
jobs=[('foundation',['python3','simulation/tests/run_foundation.py','--require-preservation'])]
for hz in (60,120):jobs.append((f'focused_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/static_platform_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):jobs.append((f'prior_backdrop_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/room_backdrop_regression.gd','--',f'--hz={hz}']))
jobs.append(('showcase_boot',[godot,'--headless','--path',str(ROOT),'res://simulation/static_platform_review.tscn','--fixed-fps','120','--quit-after','180']))
jobs.append(('stock',['python3','simulation/tests/run_counter_compatibility.py']))
for hz in (60,120):jobs.append((f'held_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://combat_pc/tests/held_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):
 for suite in ('health_regression','defeat_regression','defeat_health_compatibility','health_shield_compatibility'):
  jobs.append((f'{suite}_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script',f'res://combat_pc/tests/{suite}.gd','--',f'--hz={hz}']))
jobs.extend([('historical',['bash','tests/run_all.sh','--require-preservation']),('routes',['python3','simulation/tests/run_demo_routes.py'])])
try:
 for name,cmd in jobs:
  run=subprocess.run(cmd,cwd=ROOT,env=ENV,capture_output=True,text=True,timeout=1500)
  log=run.stdout+run.stderr;(OUT/f'static_platform_{name}_runner.log').write_text(log)
  errors=[line for line in log.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL\b)',line)]
  results.append(dict(name=name,exit_code=run.returncode,errors=errors,passed=run.returncode==0 and not errors))
  print(name,'PASS' if results[-1]['passed'] else 'FAIL',flush=True)
  # Preserve fresh results under a checkpoint namespace before restoring originals.
  for p in old_reports():
   blob=p.read_bytes()
   if keep.get(p)!=blob:
    target=GATES/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(blob)
finally:
 for p,blob in keep.items():p.write_bytes(blob)
 for p in old_reports():
  if p not in keep:p.unlink()
after=sources()
native_path=OUT/'static_platform_native_pixels.json'
native=json.loads(native_path.read_text()) if native_path.exists() else {}
native_sources={key.removeprefix('res://'):value for key,value in native.get('tested_source_sha256',{}).items()}
records=native.get('records',[])
labels=[r.get('label','') for r in records]
complete_matrix=len(records)==100 and len(set(labels))==100 and all(sum(label.startswith(f'room{i:02d}_') for label in labels)==(15 if i in (1,2) else 11) for i in range(1,9)) and {'standalone_city_nested_repeat','standalone_interior_nested_repeat','overlap_city','overlap_interior'}.issubset(labels)
reuse=native.get('reuse_checks',[])
native_ok=bool(native) and not native.get('failures',['missing']) and native.get('sources_unchanged') and native_sources==after and complete_matrix and all(r.get('passed') and r.get('different_pixels')==0 for r in records) and len(reuse)==6 and all(r.get('passed') for r in reuse)
report=dict(stages=results,unchanged_during_run=before==after,source_sha256=after,native_pixel_gate_passed=native_ok,native_comparisons=len(native.get('records',[])),historical_reports_restored=all(p.read_bytes()==b for p,b in keep.items()))
(OUT/'static_platform_final_gates.json').write_text(json.dumps(report,indent=2)+'\n')
print('FINAL',json.dumps({key:value for key,value in report.items() if key!='source_sha256'}),flush=True)
raise SystemExit(0 if before==after and all(x['passed'] for x in results) and native_ok and report['historical_reports_restored'] else 1)
