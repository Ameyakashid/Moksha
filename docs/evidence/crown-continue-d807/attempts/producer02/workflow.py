#!/usr/bin/env python3
"""Prepare isolated producer/native Continue launchers; never launches Godot itself."""
import argparse,hashlib,json,os,pathlib,shlex,subprocess
P=pathlib.Path
def sha(p):return hashlib.sha256(P(p).read_bytes()).hexdigest()
def tracked(root):
 names=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
 return {n:sha(root/n) for n in names if n}
def load(p):return json.loads(P(p).read_text())
def prepare(a):
 source=a.source.absolute();out=a.output.absolute()
 if source.resolve()!=source or out.resolve()!=out:raise ValueError('Use normalized non-symlink paths')
 if source==out or source in out.parents:raise ValueError('Outputs must be external')
 if subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip()!=a.commit:raise ValueError('Wrong frozen commit')
 if subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=source,text=True).strip():raise ValueError('Dirty tracked source')
 out.mkdir(parents=True,exist_ok=False)
 env={k:str(out/k) for k in ['HOME','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']}
 for folder in env.values():P(folder).mkdir()
 observer=out/'crown_observer.gd';observer.write_bytes(P(__file__).with_name('crown_observer.gd').read_bytes())
 args=['--hz=60','--district-timeout=480','--lens='+a.lens,'--ending='+a.ending,'--report='+str(out/'receipt.json')]
 if a.sight=='traded':args.append('--sacrifice')
 checkpoint=None
 if a.mode=='producer':args+=['--checkpoint='+str(out/'crown-entry.json'),'--provenance='+str(out/'checkpoint-provenance.json')]
 else:
  if not a.producer:raise ValueError('Verified producer output required')
  accepted=load(a.producer/'verification.json');origin=load(a.producer/'manifest.json');prov=load(a.producer/'checkpoint-provenance.json')
  if accepted.get('passed') is not True or origin['commit']!=a.commit:raise ValueError('Producer not accepted at same commit')
  if any(origin[k]!=getattr(a,k) for k in ['lens','sight','ending']):raise ValueError('Recording labels differ from proven producer')
  checkpoint=a.producer/'crown-entry.json'
  if checkpoint.is_symlink() or sha(checkpoint)!=prov['sha256']:raise ValueError('Checkpoint bytes changed')
  args+=['--checkpoint-input='+str(checkpoint.absolute()),'--continue-sha='+prov['sha256']]
 base=['godot','--path',str(source),'--fixed-fps','60']
 if a.mode=='producer':base+=['--headless']
 else:base+=['--rendering-method','gl_compatibility','--resolution','640x360','--disable-vsync','--audio-driver','Dummy','--write-movie',str(out/'raw-crown-continue.avi')]
 command=base+['--script',str(observer),'--']+args
 manifest={'mode':a.mode,'source':str(source),'commit':a.commit,'tracked_sha256':tracked(source),'observer_sha256':sha(observer),'lens':a.lens,'sight':a.sight,'ending':a.ending,'producer':str(a.producer.absolute()) if a.producer else None,'checkpoint_sha256':sha(checkpoint) if checkpoint else None,'command':command,'env':env}
 if a.mode=='continue':
  override=source/'override.cfg'
  if override.exists():raise ValueError('Dedicated source copy must not have existing override.cfg')
  override.write_text('[display]\nwindow/size/window_width_override=640\nwindow/size/window_height_override=360\n')
  manifest['window_override_sha256']=sha(override)
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 quote=shlex.quote
 script='#!/bin/sh\nset -eu\n'+''.join('export '+k+'='+quote(v)+'\n' for k,v in env.items())
 script+='cd '+quote(str(source))+'\n'
 script+='godot --headless --editor --import --quit --path '+quote(str(source))+' > '+quote(str(out/'import.log'))+' 2>&1\n'
 script+='set +e\n'+shlex.join(command)+' > '+quote(str(out/'run.log'))+' 2>&1\ncode=$?\nprintf "%s\\n" "$code" > '+quote(str(out/'exit.txt'))+'\nexit "$code"\n'
 (out/'launch.sh').write_text(script)
 print(out/'launch.sh')
def verify(a):
 out=a.output; m=load(out/'manifest.json');r=load(out/'receipt.json');source=P(m['source']);errors=[]
 for name in ['import.log','run.log']:
  for line in (out/name).read_text().splitlines():
   if any(s in line for s in ['SCRIPT ERROR:','ERROR:','ObjectDB instances leaked']):errors.append(name+': '+line)
 if (out/'exit.txt').read_text().strip()!='0':errors.append('engine exit')
 for k,v in {'passed':True,'completed':True,'deaths':0,'failures':[],'source_drift':[],'ending':m['ending'],'lens':m['lens'],'actual_blind':m['sight']=='traded','continue_mode':m['mode']=='continue'}.items():
  if r.get(k)!=v or type(r.get(k))!=type(v):errors.append(k)
 if tracked(source)!=m['tracked_sha256']:errors.append('tracked source drift')
 if sha(out/'crown_observer.gd')!=m['observer_sha256']:errors.append('observer drift')
 if [x['level'] for x in r['levels']]!=[1,2,3,4,5] or len(r['district_metrics'])!=32:errors.append('completion history')
 crown=['crown_ascent','crown_witness_galleries','crown_manual_governor','crown_refuge_channel','crown_coolant_interlock','crown_last_warden','crown_choice_threshold']
 if m['mode']=='continue':
  if set(r['objective_receipts'])!=set(crown) or [x['district'] for x in r['movie_frames'] if 'district' in x]!=crown:errors.append('exact seven Crown receipts/order')
  if r['prior_metrics_count']!=25 or r['prior_level_receipts_count']!=4:errors.append('checkpoint prefix history')
  if r['checkpoint_sha256']!=m['checkpoint_sha256']:errors.append('loaded checkpoint digest')
  if sha(source/'override.cfg')!=m['window_override_sha256']:errors.append('window override changed')
  if not (out/'raw-crown-continue.avi').is_file():errors.append('missing raw native movie')
 else:
  prov=load(out/'checkpoint-provenance.json');saved=load(out/'crown-entry.json')
  if sha(out/'crown-entry.json')!=prov['sha256'] or r['checkpoint_sha256']!=prov['sha256']:errors.append('captured checkpoint digest')
  if saved['progress']['sector_id']!='crown_ascent' or len(saved['progress']['metrics'])!=25 or len(saved['level_receipts'])!=4 or len(saved['upgrades'])!=4:errors.append('natural Crown checkpoint schema')
  if len(r['objective_receipts'])!=32:errors.append('32 producer objective receipts')
  if not all(r['clinic_shortcut'].values()):errors.append('Clinic proof')
 for district,entry in r['objective_receipts'].items():
  if not all(g['completed'] for g in entry['required_goals']):errors.append('incomplete objectives '+district)
 result={'passed':not errors,'errors':errors,'commit':m['commit'],'mode':m['mode'],'observer_sha256':m['observer_sha256'],'checkpoint_sha256':r['checkpoint_sha256'],'new_objective_receipt_count':len(r['objective_receipts'])}
 (out/'verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));return 0 if not errors else 1
ap=argparse.ArgumentParser();sub=ap.add_subparsers(dest='action',required=True)
p=sub.add_parser('prepare');p.add_argument('--mode',choices=['producer','continue'],required=True);p.add_argument('--source',type=P,required=True);p.add_argument('--commit',required=True);p.add_argument('--output',type=P,required=True);p.add_argument('--producer',type=P);p.add_argument('--lens',choices=['neutral','strength','agility'],default='neutral');p.add_argument('--sight',choices=['retained','traded'],default='retained');p.add_argument('--ending',choices=['public_record','local_custody'],default='public_record')
p=sub.add_parser('verify');p.add_argument('--output',type=P,required=True)
a=ap.parse_args()
if a.action=='prepare':prepare(a)
else:raise SystemExit(verify(a))
