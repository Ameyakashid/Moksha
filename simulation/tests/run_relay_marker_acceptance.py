#!/usr/bin/env python3
"""Frozen Relay marker acceptance; preserve all earlier reports and archives."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'simulation/evidence'
GATES=OUT/'relay_marker_gates'
GATES.mkdir(exist_ok=True)
RUNTIME=ROOT.parent/'relay_marker_acceptance_runtime'
RUNTIME.mkdir(exist_ok=True)
ENV=dict(os.environ,XDG_DATA_HOME=str(RUNTIME/'data'),XDG_CONFIG_HOME=str(RUNTIME/'config'),XDG_CACHE_HOME=str(RUNTIME/'cache'))
def ours(p):return any(part.startswith('relay_marker') for part in p.relative_to(ROOT).parts)
def sources():
 return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ROOT.rglob('*') if p.is_file() and not {'.godot','delivery'}.intersection(p.relative_to(ROOT).parts) and p.suffix in {'.gd','.tscn','.tres','.py','.godot'}}
def old_reports():
 return [p for p in ROOT.rglob('*') if p.is_file() and not {'.godot','delivery'}.intersection(p.relative_to(ROOT).parts) and p.suffix in {'.json','.log','.md'} and not ours(p)]
# Back up cold reports on disk, not tmpfs or a multi-gigabyte Python bytes dict.
BACKUP=RUNTIME/'prior_reports'
BACKUP.mkdir(exist_ok=True)
def digest(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
keep={p:digest(p) for p in old_reports()}
for p in keep:
 target=BACKUP/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
(RUNTIME/'prior_reports_manifest.json').write_text(json.dumps({str(p.relative_to(ROOT)):sha for p,sha in keep.items()},indent=2)+'\n')
before=sources();results=[]
(OUT/'relay_marker_frozen_sources.json').write_text(json.dumps(before,indent=2)+'\n')
godot=os.environ.get('GODOT_BIN','godot')
jobs=[('oracle_preflight',[godot,'--headless','--path',str(ROOT),'--script','res://simulation/tests/relay_marker_oracle_preflight.gd']),('isolated_asset',['python3','simulation/tests/relay_marker_isolation.py']),('foundation',['python3','simulation/tests/run_foundation.py','--require-preservation'])]
for hz in (60,120):jobs.append((f'relay_marker_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/relay_marker_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):jobs.append((f'contact_route_policy_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/relay_marker_route_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):jobs.append((f'prior_exchange_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/exchange_station_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):jobs.append((f'prior_onward_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/onward_marker_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):jobs.append((f'prior_sign_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/world_sign_regression.gd','--',f'--hz={hz}']))
jobs.append(('relay_marker_showcase',[godot,'--headless','--path',str(ROOT),'res://simulation/relay_marker_review.tscn','--fixed-fps','120','--quit-after','180']))
for hz in (60,120):jobs.append((f'focused_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/floor_segment_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):jobs.append((f'route_policy_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/floor_segment_route_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):jobs.append((f'prior_platform_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/static_platform_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):jobs.append((f'prior_backdrop_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://simulation/tests/room_backdrop_regression.gd','--',f'--hz={hz}']))
jobs.append(('showcase_boot',[godot,'--headless','--path',str(ROOT),'res://simulation/floor_segment_review.tscn','--fixed-fps','120','--quit-after','180']))
jobs.append(('prior_platform_showcase',[godot,'--headless','--path',str(ROOT),'res://simulation/static_platform_review.tscn','--fixed-fps','120','--quit-after','180']))
jobs.append(('stock',['python3','simulation/tests/run_counter_compatibility.py']))
for hz in (60,120):jobs.append((f'held_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script','res://combat_pc/tests/held_regression.gd','--',f'--hz={hz}']))
for hz in (60,120):
 for suite in ('health_regression','defeat_regression','defeat_health_compatibility','health_shield_compatibility'):
  jobs.append((f'{suite}_{hz}',[godot,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script',f'res://combat_pc/tests/{suite}.gd','--',f'--hz={hz}']))
jobs.extend([('historical',['bash','tests/run_all.sh','--require-preservation']),('routes',['python3','simulation/tests/run_demo_routes.py'])])
try:
 for name,cmd in jobs:
  run=subprocess.run(cmd,cwd=ROOT,env=ENV,capture_output=True,text=True,timeout=1500)
  log=run.stdout+run.stderr;(OUT/f'relay_marker_{name}_runner.log').write_text(log)
  errors=[line for line in log.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL\b)',line)]
  results.append(dict(name=name,exit_code=run.returncode,errors=errors,passed=run.returncode==0 and not errors))
  print(name,'PASS' if results[-1]['passed'] else 'FAIL',flush=True)
  # Preserve fresh results under a checkpoint namespace before restoring originals.
  for p in old_reports():
   if keep.get(p)!=digest(p):
    target=GATES/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
finally:
 for p in keep:shutil.copy2(BACKUP/p.relative_to(ROOT),p)
 for p in old_reports():
  if p not in keep:p.unlink()
after=sources()
native_path=OUT/'relay_marker_native_pixels.json'
native=json.loads(native_path.read_text()) if native_path.exists() else {}
native_sources={key.removeprefix('res://'):value for key,value in native.get('tested_source_sha256',{}).items()}
records=native.get('records',[])
labels=[r.get('label','') for r in records]
expected_labels=set()
for i,count in ((1,1),(2,1),(3,2),(5,1),(6,3)):
 for relay in range(count): expected_labels.update(f'focused_room{i:02d}_relay{relay:02d}_{state}' for state in ('false','true'))
for i in range(1,9):expected_labels.update(f'room{i:02d}_{suffix}' for suffix in ('hidden','blackout_quiet','blackout_pulse'))
for theme in ('city','interior'):
 expected_labels.update(f'overlap_{theme}_{state}' for state in ('false','true'))
 expected_labels.update(f'overlap_active_{theme}_{state}' for state in ('false','true'))
 expected_labels.update(f'mixed_array_{theme}_{phase:02d}' for phase in range(5))
for i in range(8):expected_labels.update(f'anchor_{kind}_{i:02d}' for kind in ('decomposition','moved','root_transform'))
expected_labels.update(f'style_reference_{i:02d}' for i in range(10))
expected_labels.update(f'host_depth_dynamic_overlap_{i:02d}' for i in range(4))
complete_matrix=len(records)==168 and len(set(labels))==168 and expected_labels.issubset(labels) and all(sum(label.startswith(f'room{i:02d}_') for label in labels)==(15 if i in (1,2) else 11) for i in range(1,9))
reuse=native.get('reuse_checks',[])
native_ok=bool(native) and not native.get('failures',['missing']) and native.get('sources_unchanged') and native_sources==after and complete_matrix and all(r.get('passed') and r.get('different_pixels')==0 for r in records) and len(reuse)==14 and all(r.get('passed') for r in reuse)
from relay_marker_preservation import run as check_preservation
preservation_ok=check_preservation()
report=dict(preservation_gate_passed=preservation_ok,stages=results,unchanged_during_run=before==after,source_sha256=after,native_pixel_gate_passed=native_ok,native_comparisons=len(native.get('records',[])),historical_reports_restored=all(digest(p)==sha for p,sha in keep.items()))
(OUT/'relay_marker_final_gates.json').write_text(json.dumps(report,indent=2)+'\n')
print('FINAL',json.dumps({key:value for key,value in report.items() if key!='source_sha256'}),flush=True)
raise SystemExit(0 if preservation_ok and before==after and all(x['passed'] for x in results) and native_ok and report['historical_reports_restored'] else 1)
