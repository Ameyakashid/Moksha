from pathlib import Path
import hashlib,json,os,subprocess,sys
root=Path(__file__).resolve().parents[1]/'intake_candidate'
out=Path(__file__).resolve().parent
label=sys.argv[1] if len(sys.argv)>1 else 'final'
def sources():
 return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and not {'.godot','evidence','delivery','__pycache__'}.intersection(p.relative_to(root).parts) and p.suffix in {'.gd','.tscn','.tres','.godot'}}
before=sources();records=[]
for hz in (60,120):
 runtime=out/f'lifecycle_{label}_{hz}'
 env=dict(os.environ)
 for key,name in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
  path=runtime/name;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
 r=subprocess.run(['godot','--headless','--path',str(root),'--fixed-fps',str(hz),'--script',str(out/'intake_lifecycle.gd'),'--',f'--hz={hz}'],env=env,text=True,capture_output=True,timeout=120)
 log=r.stdout+r.stderr;(out/f'lifecycle_{label}_{hz}.log').write_text(log)
 payloads=[line.removeprefix('INTAKE LIFECYCLE ') for line in log.splitlines() if line.startswith('INTAKE LIFECYCLE ')]
 data=json.loads(payloads[-1]) if payloads else None
 ok=r.returncode==0 and data is not None and not data['failures'] and len(data['checks'])==29 and all(row['passed'] for row in data['checks']) and not any(s in log for s in ['SCRIPT ERROR','ERROR:','FAIL '])
 records.append({'hz':hz,'passed':ok,'exit_code':r.returncode,'report':data});print(hz,ok,flush=True)
after=sources();report={'records':records,'source_sha256':before,'sources_unchanged':before==after,'fixture_sha256':hashlib.sha256((out/'intake_lifecycle.gd').read_bytes()).hexdigest()}
(out/f'lifecycle_{label}_summary.json').write_text(json.dumps(report,indent=2)+'\n')
sys.exit(0 if before==after and all(r['passed'] for r in records) else 1)
