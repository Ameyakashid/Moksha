#!/usr/bin/env python3
"""Fresh extracted delivery verification; does not claim native render or full replay."""
from pathlib import Path
import json,zipfile,hashlib,subprocess,os,tempfile
root=Path(__file__).resolve().parents[1];out=root.parent/'moksha-campaign-delivery'
meta=json.loads((out/'MOKSHA-delivery-manifest.json').read_text())
archive=Path(meta['source_zip']);assert hashlib.sha256(archive.read_bytes()).hexdigest()==meta['source_sha256']
stage=Path(tempfile.mkdtemp(prefix='moksha-final-extraction-'))
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for item in z.infolist():
  p=Path(item.filename);assert not p.is_absolute() and '..' not in p.parts
 z.extractall(stage)
project=stage/'MOKSHA';manifest=json.loads((project/'DELIVERY_MANIFEST.json').read_text())
for entry in manifest['files']:
 file=project/entry['path'];assert file.stat().st_size==entry['bytes'];assert hashlib.sha256(file.read_bytes()).hexdigest()==entry['sha256'],entry['path']
env=dict(os.environ)
for k,s in [('HOME','home'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
 env[k]=str(stage/s);Path(env[k]).mkdir()
godot=os.environ.get('GODOT_BIN','godot')
checks=[]
for name,args,marker in [('fresh_import',['--editor','--quit'],None),('default_boot',['--quit-after','8'],None),('all_district_smoke',['--script','res://campaign/tests/campaign_smoke.gd'],'SMOKE_DISTRICTS=32')]:
 command=[godot,'--headless','--path',str(project)]+args
 run=subprocess.run(command,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
 log=out/f'extraction_{name}.log';log.write_text(run.stdout)
 errors=[line for line in run.stdout.splitlines() if line.startswith(('ERROR:','SCRIPT ERROR:'))]
 assert run.returncode==0 and not errors and (marker is None or marker in run.stdout),(name,run.returncode,errors)
 checks.append(dict(name=name,passed=True,log=str(log)))
meta.update(fresh_extraction_verified=True,extracted_path=str(project),extraction_checks=checks,extraction_scope='CRC, every manifest file hash, fresh editor import, default campaign boot, controlled loading of all32districts. Not native visuals or a repeated full input route.')
(out/'MOKSHA-delivery-manifest.json').write_text(json.dumps(meta,indent=2)+'\n');print(json.dumps(meta,indent=2))
