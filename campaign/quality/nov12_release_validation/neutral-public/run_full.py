#!/usr/bin/env python3
"""Frozen-copy continuous campaign validation; outputs never enter sources."""
import argparse, hashlib, json, os, pathlib, subprocess, time
P=pathlib.Path

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source',type=P,required=True);ap.add_argument('--commit',required=True)
    ap.add_argument('--output',type=P,required=True)
    args=ap.parse_args();source=args.source.resolve();output=args.output.resolve()
    if source==output or source in output.parents:ap.error('Output must be outside source')
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip()
    if head!=args.commit:ap.error('Frozen commit mismatch')
    if subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=source,text=True).strip():ap.error('Tracked source dirty')
    output.mkdir(parents=True,exist_ok=False)
    tracked=subprocess.check_output(['git','ls-files','-z'],cwd=source).decode().split('\0')
    def hashes():return {p:hashlib.sha256((source/p).read_bytes()).hexdigest() for p in tracked if p and (source/p).is_file()}
    before=hashes();env=dict(os.environ)
    for k in ['HOME','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
        folder=output/k;folder.mkdir();env[k]=str(folder)
    observer=P(__file__).with_name('full_campaign_observer.gd').resolve()
    observer_hash=hashlib.sha256(observer.read_bytes()).hexdigest()
    stages=[]
    def stage(name,command,timeout):
        start=time.monotonic()
        with (output/(name+'.log')).open('w') as log:
            try:r=subprocess.run(command,cwd=source,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=timeout);code=r.returncode
            except subprocess.TimeoutExpired:code=124
        errors=[line for line in (output/(name+'.log')).read_text().splitlines() if line.lstrip().startswith(('ERROR:','SCRIPT ERROR:','FAIL '))]
        row={'name':name,'exit_code':code,'errors':errors,'passed':code==0 and not errors,'wall_seconds':time.monotonic()-start}
        stages.append(row);print(json.dumps(row),flush=True);return row['passed']
    imported=stage('import',['godot','--headless','--editor','--import','--path',str(source)],300)
    if imported:stage('campaign',['godot','--headless','--path',str(source),'--fixed-fps','60','--script',str(observer),'--','--hz=60','--district-timeout=480','--ending=public_record',f'--report={output/"campaign.json"}'],18000)
    receipt_errors=[]
    try:
        r=json.loads((output/'campaign.json').read_text())
        for key,val in {'passed':True,'completed':True,'hz':60,'deaths':0,'failures':[],'source_drift':[],'ending':'public_record','requested_ending':'public_record','actual_blind':False,'requested_sight_trade':False}.items():
            if type(r.get(key))!=type(val) or r.get(key)!=val:receipt_errors.append(key)
        if [v.get('level') for v in r.get('levels',[])]!=[1,2,3,4,5]:receipt_errors.append('five levels')
        if len(r.get('district_metrics',[]))!=32 or len(r.get('objective_receipts',{}))!=32:receipt_errors.append('32 districts')
        if r.get('clinic_shortcut')!={'closed_seen':True,'roof_crossed':True,'open_seen':True,'street_crossed':True}:receipt_errors.append('clinic shortcut')
    except (OSError,ValueError,AttributeError,TypeError) as error:receipt_errors.append(str(error))
    after=hashes();drift=[p for p in before.keys()|after.keys() if before.get(p)!=after.get(p)]
    if hashlib.sha256(observer.read_bytes()).hexdigest()!=observer_hash:drift.append('external observer')
    report={'passed':imported and len(stages)==2 and all(s['passed'] for s in stages) and not receipt_errors and not drift,'commit':head,'stages':stages,'receipt_errors':receipt_errors,'source_drift':drift,'tracked_sha256':before,'observer_sha256':observer_hash,'scope':'Continuous normal-title neutral retained-sight60Hz automated campaign/public_record ending; no manual pacing or optional branch acceptance.'}
    (output/'summary.json').write_text(json.dumps(report,indent=2)+'\n');print('FROZEN_CAMPAIGN_RESULT',json.dumps({'passed':report['passed'],'output':str(output)}),flush=True)
    return 0 if report['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
