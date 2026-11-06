#!/usr/bin/env python3
"""Snapshot a Godot project, then run bounded state tests without editing its source."""
from __future__ import annotations
import argparse,hashlib,json,os,pathlib,re,shutil,subprocess,sys,tarfile,tempfile,time
HERE=pathlib.Path(__file__).resolve().parent
PREFIX=pathlib.Path('campaign/quality/nov6_transition_stress')
FIXTURES=('transition_stress.gd','cumulative_upgrade_lifecycle.gd','mutations/input.gd','mutations/rollback.gd')
DIAGNOSTICS=re.compile(r'SCRIPT ERROR:|^ERROR:|Parse Error:|Assertion failed|ObjectDB instances leaked',re.M)

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write_json(path,value):path.write_text(json.dumps(value,indent=2)+'\n')
def files(root):
 return {p.relative_to(root).as_posix():sha(p) for p in sorted(root.rglob('*')) if p.is_file() and not any(part in ('.git','.godot','__pycache__') for part in p.relative_to(root).parts)}
def mismatches(root,manifest):
 return [p for p,h in manifest.items() if not (root/p).is_file() or sha(root/p)!=h]
def environment(root,isolated=True):
 env=os.environ.copy()
 for key,part in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
  (root/part).mkdir(parents=True,exist_ok=True);env[key]=str(root/part)
 if isolated:env['MOKSHA_QUALITY_ISOLATED']='1'
 else:env.pop('MOKSHA_QUALITY_ISOLATED',None)
 return env

def snapshot(source,revision,root):
 project=root/'project';project.mkdir()
 if revision:
  commit=subprocess.check_output(['git','rev-parse','--verify',revision+'^{commit}'],cwd=source,text=True).strip()
  archive=root/'source.tar'
  subprocess.run(['git','archive','--format=tar','--output='+str(archive),commit],cwd=source,check=True)
  with tarfile.open(archive) as tf:tf.extractall(project,filter='data')
  archive.unlink();identity={'method':'git archive','commit':commit}
 else:
  before=files(source)
  shutil.copytree(source,project,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.git','.godot','__pycache__'))
  if before!=files(source) or before!=files(project):raise RuntimeError('Source changed while copying; this snapshot is rejected.')
  identity={'method':'stable file copy','commit':None}
 if not (project/'project.godot').is_file():raise RuntimeError('Snapshot does not contain project.godot at its root.')
 baseline=files(project)
 identity.update({'files':baseline,'manifest_sha256':hashlib.sha256(json.dumps(baseline,sort_keys=True,separators=(',',':')).encode()).hexdigest()})
 write_json(root/'evidence/source_manifest.json',identity)
 fixture_hashes={}
 for name in FIXTURES:
  origin=HERE/name;dest=project/PREFIX/name;dest.parent.mkdir(parents=True,exist_ok=True)
  if dest.exists() and sha(dest)!=sha(origin):raise RuntimeError('Snapshot contains a different fixture at '+str(PREFIX/name)+'. Use the harness supplied with that revision.')
  shutil.copyfile(origin,dest);fixture_hashes[(PREFIX/name).as_posix()]=sha(dest)
 write_json(root/'evidence/fixture_manifest.json',fixture_hashes)
 return project,baseline,fixture_hashes,identity

def invoke(command,env,timeout,log):
 start=time.monotonic();timed_out=False
 try:
  p=subprocess.run(command,env=env,capture_output=True,text=True,timeout=timeout);code=p.returncode;raw=p.stdout+p.stderr
 except subprocess.TimeoutExpired as e:
  code=124;timed_out=True
  raw=(e.stdout or b'')+(e.stderr or b'') if isinstance(e.stdout,bytes) else (e.stdout or '')+(e.stderr or '')
  if isinstance(raw,bytes):raw=raw.decode(errors='replace')
  raw+='\nRUNNER TIMEOUT\n'
 log.write_text(raw)
 return code,raw,round(time.monotonic()-start,3),timed_out

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--source',type=pathlib.Path,required=True,help='Project root; never modified.')
 p.add_argument('--revision',help='Exact Git revision to archive. Omit for a verified stable file-copy snapshot.')
 p.add_argument('--output',type=pathlib.Path,help='New/empty folder outside the source. Defaults to a new temporary folder.')
 p.add_argument('--godot',default='godot');p.add_argument('--seeds',type=int,default=128);p.add_argument('--steps',type=int,default=128)
 p.add_argument('--timeout',type=int,default=900);p.add_argument('--skip-replay',action='store_true');p.add_argument('--skip-cumulative',action='store_true')
 args=p.parse_args();source=args.source.resolve()
 if not (source/'project.godot').is_file():p.error('--source must contain project.godot')
 if args.seeds<1 or args.steps<1:p.error('Use at least one seed and step for positive runs.')
 root=args.output.resolve() if args.output else pathlib.Path(tempfile.mkdtemp(prefix='moksha-transition-stress-'))
 if root==source or source in root.parents:p.error('--output must be outside the source project')
 if root.exists() and any(root.iterdir()):p.error('--output must be new or empty; existing evidence is never overwritten')
 root.mkdir(parents=True,exist_ok=True);(root/'evidence').mkdir();print('Output: '+str(root),flush=True)
 project,baseline,fixture_hashes,identity=snapshot(source,args.revision,root)
 setup_env=environment(root/'runtime/import')
 binary=shutil.which(args.godot)
 if not binary:raise RuntimeError('Godot executable not found: '+args.godot)
 version=subprocess.check_output([binary,'--version'],env=setup_env,text=True).strip()
 if not version.startswith('4.6.3.'):raise RuntimeError('These receipts require Godot 4.6.3; found '+version)
 write_json(root/'evidence/engine.json',{'version':version,'binary':binary,'binary_sha256':sha(pathlib.Path(binary)),'python':sys.version})
 import_cmd=[binary,'--headless','--path',str(project),'--editor','--import','--quit']
 code,raw,seconds,timed_out=invoke(import_cmd,setup_env,args.timeout,root/'evidence/import.log')
 import_ok=code==0 and not DIAGNOSTICS.search(raw) and not mismatches(project,baseline) and not mismatches(project,fixture_hashes)
 rows=[]
 if import_ok:
  plans=[('final_60',60,'all',None,True),('final_120',120,'all',None,True)]
  if not args.skip_replay:plans.append(('repeat_60',60,'all',None,True))
  plans += [('negative_rollback',60,'upgrade','rollback',True),('negative_input',60,'held','input',True),('isolation_refusal',60,'all',None,False)]
  if not args.skip_cumulative:plans += [('cumulative_60',60,'cumulative',None,True),('cumulative_120',120,'cumulative',None,True)]
  for name,hz,mode,mutation,isolated in plans:
   report=root/'evidence'/(name+'.json');log=root/'evidence'/(name+'.log');env=environment(root/'runtime'/name,isolated)
   script='cumulative_upgrade_lifecycle.gd' if mode=='cumulative' else 'transition_stress.gd'
   command=[binary,'--headless','--path',str(project),'--script','res://'+(PREFIX/script).as_posix(),'--fixed-fps','600','--',f'--hz={hz}',f'--seeds={args.seeds}',f'--steps={args.steps}','--out='+str(report)]
   if mode!='cumulative':command.append('--mode='+mode)
   if mutation:command.append('--mutation='+mutation)
   before=mismatches(project,baseline)+mismatches(project,fixture_hashes)
   code,raw,seconds,timed_out=invoke(command,env,args.timeout,log)
   result=json.loads(report.read_text()) if report.exists() else None
   after=mismatches(project,baseline)+mismatches(project,fixture_hashes);errors=DIAGNOSTICS.findall(raw)
   expected={'rollback':'old room retry/Continue rolls back','input':'held direction does not cross modal'}.get(mutation)
   if not isolated:verdict=code==2 and 'REFUSED: isolated XDG save directory required' in raw and result is None and not list((root/'runtime'/name/'data').rglob('moksha_five_levels_v1.json'))
   elif mutation:verdict=code==1 and result is not None and not result['passed'] and any(expected in x['label'] for x in result['failures'])
   else:verdict=code==0 and result is not None and result['passed'] and not result['failures']
   verdict=verdict and not before and not after and not errors and not timed_out
   row={'name':name,'passed':bool(verdict),'returncode':code,'wall_seconds':seconds,'command':command,'expected_failure':expected,'report':str(report.relative_to(root)) if result else None,'log':str(log.relative_to(root)),'checks':result.get('checks',0) if result else 0,'events':result.get('events',0) if result else 0,'scenarios':result.get('scenarios',0) if result else 0,'command_digest':result.get('command_digest') if result else None,'engine_errors':errors,'source_drift_before':before,'source_drift_after':after}
   rows.append(row);print(json.dumps(row),flush=True)
   if not verdict:break
 digests=[r['command_digest'] for r in rows if r['name'] in ('final_60','final_120','repeat_60')]
 identical=len(digests)==(2 if args.skip_replay else 3) and len(set(digests))==1
 expected_count=8-int(args.skip_replay)-2*int(args.skip_cumulative)
 summary={'passed':import_ok and len(rows)==expected_count and all(r['passed'] for r in rows) and identical,'source':{k:v for k,v in identity.items() if k!='files'},'engine':version,'import_passed':import_ok,'command_sequence_replay_identical':identical,'seeds':args.seeds,'steps':args.steps,'fixture_hashes':fixture_hashes,'runs':rows,'production_drift_final':mismatches(project,baseline),'scope':'Headless real event dispatch with explicit modal-entry/completed-exit fixtures and deterministic host/actor physics ticks. Cumulative build cases use real title/sight/upgrade choices. Not full traversal, native-device/rendered QA, human timing or filesystem power-loss testing.'}
 write_json(root/'evidence/summary.json',summary);print('SUMMARY '+json.dumps(summary),flush=True)
 return 0 if summary['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
