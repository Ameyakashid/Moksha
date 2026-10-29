"""Independent targeted campaign regression, not full traversal or human pacing."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'campaign/qa_audit'/('final_results' if '--final' in sys.argv else 'current_results')
OUT.mkdir(exist_ok=True)
BIN='/opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64'
ENV=dict(os.environ,XDG_DATA_HOME='/tmp/moksha-independent-qa/data',XDG_CACHE_HOME='/tmp/moksha-independent-qa/cache',XDG_CONFIG_HOME='/tmp/moksha-independent-qa/config')
def hashes():
 return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ROOT.rglob('*') if p.is_file() and (p.suffix in {'.gd','.tscn','.tres','.gdshader'} or p.name=='project.godot') and not {'.git','.godot','qa_audit','evidence'}.intersection(p.relative_to(ROOT).parts)}
before=hashes();reports=[]
for hz in (60,120):
 for name in ('draft_audit','lifecycle_draft','sensory_draft','save_draft','door_physics','ui_dependencies'):
  command=[BIN,'--headless','--path',str(ROOT),'--fixed-fps',str(hz),'--script',f'res://campaign/qa_audit/{name}.gd','--',f'--hz={hz}']
  started=time.monotonic()
  try:
   r=subprocess.run(command,env=ENV,capture_output=True,text=True,timeout=150);code=r.returncode;output=r.stdout+r.stderr
  except subprocess.TimeoutExpired as e:code=124;output=str(e)
  (OUT/f'{name}_{hz}.log').write_text(output)
  errors=[line for line in output.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL\b)',line)]
  sentinel=any(re.search(r'_FAILURES \[\]$',line) for line in output.splitlines())
  report={'name':name,'hz':hz,'exit_code':code,'checks':len(re.findall(r'^PASS ',output,re.M)),'errors':errors,'sentinel':sentinel,'passed':code==0 and not errors and sentinel,'seconds':round(time.monotonic()-started,3)}
  reports.append(report);print(json.dumps(report),flush=True)
after=hashes();drift=[p for p in before.keys()|after.keys() if before.get(p)!=after.get(p)]
result={'scope':'Controlled component/scene fixtures and actual generic door motor collision; NOT campaign traversal, native pixels or human pacing. Original failed draft logs retained separately.','reports':reports,'source_drift':drift,'tested_source_sha256':before,'passed':not drift and all(r['passed'] for r in reports)}
(OUT/'summary.json').write_text(json.dumps(result,indent=2));sys.exit(0 if result['passed'] else 1)
