import concurrent.futures, hashlib, json, os, pathlib, re, shutil, subprocess, tarfile, time
SOURCE=pathlib.Path('/workspace/scratch/fd16273ade4b/moksha-campaign')
ROOT=pathlib.Path(__file__).resolve().parent
PROJECT=ROOT/'project'
COMMIT='bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5'
OBSERVERS=['nov6_modal_route_input.gd','nov6_freight_route_input.gd','nov6_full_campaign_route.gd','nov6_full_campaign_strength_route.gd','nov6_full_campaign_route_120_sonar.gd']

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):path.write_text(json.dumps(value,indent=2)+'\n')
def isolated_env(name):
 env=dict(os.environ);base=ROOT/'user_data'/name
 for key in ['HOME','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
  p=base/key;p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
 return env

def main():
 if PROJECT.exists():raise SystemExit('Refusing to reuse an existing project/evidence run')
 PROJECT.mkdir()
 archive=ROOT/'runtime-bf3ebd3.tar'
 with archive.open('wb') as out:subprocess.run(['git','archive','--format=tar',COMMIT],cwd=SOURCE,stdout=out,check=True)
 subprocess.run(['tar','-xf',str(archive),'-C',str(PROJECT)],check=True)
 archived_blobs={str(p.relative_to(PROJECT)):sha(p) for p in PROJECT.rglob('*') if p.is_file()}
 runtime_hashes={str(p.relative_to(PROJECT)):sha(p) for p in PROJECT.rglob('*') if p.is_file() and p.suffix in ['.gd','.tscn','.tres','.gdshader']}
 observers={}
 for name in OBSERVERS:
  dst=PROJECT/'campaign/quality'/name
  observers[str(dst.relative_to(PROJECT))]=sha(dst)
 preserved=ROOT/'preserved_archived_reports';preserved.mkdir()
 archived_report_redirects={}
 for path in (PROJECT/'campaign/tests').glob('full_route_*.json'):
  archived_report_redirects[str(path.relative_to(PROJECT))]=str((preserved/path.name).relative_to(ROOT))
  shutil.move(str(path),str(preserved/path.name))
 manifest={'runtime_commit':subprocess.check_output(['git','rev-parse',COMMIT],cwd=SOURCE,text=True).strip(),'runtime_archive_sha256':sha(archive),'archived_blobs_sha256':archived_blobs,'archived_report_redirects':archived_report_redirects,'runtime_source_sha256':runtime_hashes,'observer_source_sha256':observers,'method':'Exact bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5 Git archive including the five committed observer files. No overlays or production source edits. Prior copied receipts preserved separately. Each run has isolated user directories; outputs are new.'}
 write(ROOT/'snapshot.json',manifest)
 imp=subprocess.run(['godot','--headless','--editor','--import','--path',str(PROJECT)],env=isolated_env('import'),capture_output=True,text=True,timeout=300)
 (ROOT/'import.log').write_text(imp.stdout+imp.stderr)
 if imp.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:)',imp.stdout+imp.stderr,re.M):raise SystemExit('Import failed; see import.log')
 cases=[('neutral60_retained','nov6_full_campaign_route.gd',60,'neutral',False),('neutral120_retained','nov6_full_campaign_route.gd',120,'neutral',False),('neutral60_traded','nov6_full_campaign_route.gd',60,'neutral',True),('neutral120_traded','nov6_full_campaign_route_120_sonar.gd',120,'neutral',True),('strength60_retained','nov6_full_campaign_strength_route.gd',60,'strength',False),('agility60_retained','nov6_full_campaign_route.gd',60,'agility',False)]
 results=[]
 def run(case):
  name,script,hz,lens,traded=case
  command=['godot','--headless','--path',str(PROJECT),'--fixed-fps',str(hz),'--script','res://campaign/quality/'+script,'--',f'--hz={hz}',f'--lens={lens}','--district-timeout=480']+(['--sacrifice'] if traded else [])
  print('START '+name,flush=True);start=time.monotonic()
  logfile=ROOT/(name+'.log')
  try:
   with logfile.open('w') as out:p=subprocess.run(command,cwd=PROJECT,env=isolated_env(name),stdout=out,stderr=subprocess.STDOUT,timeout=5400)
   code=p.returncode
  except subprocess.TimeoutExpired:code=124
  log=logfile.read_text();errors=[line for line in log.splitlines() if re.match(r'^\s*(SCRIPT ERROR:|ERROR:)',line)]
  path=PROJECT/'campaign/tests'/f'full_route_{hz}_{lens}_{"traded" if traded else "retained"}.json'
  report=json.loads(path.read_text()) if path.exists() else {}
  short_deliveries=[event for event in report.get('events',[]) if event.get('event')=='observer_short_delivery_followup_strike']
  releases=[event for event in report.get('events',[]) if event.get('event')=='observer_modal_controls_released']
  row={'name':name,'exit_code':code,'passed':code==0 and not errors and report.get('passed',False) and not report.get('source_drift') and 'FULL_CAMPAIGN_RESULT ' in log,'engine_errors':errors,'report':str(path),'completed':report.get('completed',False),'active_seconds':report.get('active_seconds'),'deaths':report.get('deaths'),'failures':report.get('failures',[]),'source_drift':report.get('source_drift',[]),'observer_release_count':len(releases),'observer_short_delivery_strikes':len(short_deliveries),'wall_seconds':round(time.monotonic()-start,3),'command':command}
  print('DONE '+json.dumps(row),flush=True)
  return row
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
  futures=[pool.submit(run,case) for case in cases]
  for future in concurrent.futures.as_completed(futures):
   results.append(future.result());write(ROOT/'progress.json',results)
 runtime_drift=[path for path,value in runtime_hashes.items() if not (PROJECT/path).exists() or sha(PROJECT/path)!=value]
 observer_drift=[path for path,value in observers.items() if sha(PROJECT/path)!=value]
 archived_blob_drift=[]
 for path,value in archived_blobs.items():
  final_path=ROOT/archived_report_redirects[path] if path in archived_report_redirects else PROJECT/path
  if not final_path.exists() or sha(final_path)!=value:archived_blob_drift.append(path)
 write(ROOT/'matrix_summary.json',{'passed':not runtime_drift and not observer_drift and not archived_blob_drift and all(r['passed'] for r in results),'runtime_commit':manifest['runtime_commit'],'runtime_drift':runtime_drift,'observer_drift':observer_drift,'archived_blob_drift':archived_blob_drift,'archived_blob_count':len(archived_blobs),'cases':results,'scope':'Six input-only full campaign routes against the exact committed runtime and observer; all archived original blobs are hash-verified, preserving moved historical reports separately. Automated timings are not human duration or native hardware acceptance.'})
 print('MATRIX_FINISHED '+str(ROOT/'matrix_summary.json'),flush=True)
if __name__=='__main__':main()
