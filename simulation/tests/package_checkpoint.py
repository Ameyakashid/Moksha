#!/usr/bin/env python3
"""Create a new immutable full-project gym checkpoint without touching v28."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import argparse, hashlib, json
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True, type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parents[2]
output=args.output.resolve()
if output.exists(): raise SystemExit('Refusing to overwrite existing checkpoint: '+str(output))
output.parent.mkdir(parents=True,exist_ok=True)
temporary=output.with_suffix('.building.zip')
files={}
with ZipFile(temporary,'w',ZIP_DEFLATED,compresslevel=6) as archive:
    for path in sorted(root.rglob('*')):
        if not path.is_file(): continue
        relative=path.relative_to(root)
        if {'.godot','.git','delivery','__pycache__'}.intersection(relative.parts): continue
        if path.suffix in {'.zip','.import','.pyc'}: continue
        if path.suffix=='.log' and relative.parts[:2]!=('simulation','evidence'): continue
        blob=path.read_bytes()
        files[str(relative)]=hashlib.sha256(blob).hexdigest()
        archive.writestr('MOKSHA/'+str(relative),blob)
with ZipFile(temporary) as archive:
    assert archive.testzip() is None
    for relative, sha in files.items():
        assert hashlib.sha256(archive.read('MOKSHA/'+relative)).hexdigest()==sha
        assert hashlib.sha256((root/relative).read_bytes()).hexdigest()==sha, 'Source changed during packaging: '+relative
temporary.replace(output)
manifest={'file':output.name,'bytes':output.stat().st_size,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'files':files,'crc_verified':True}
output.with_suffix('.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
output.with_suffix('.sha256').write_text(manifest['sha256']+'  '+output.name+'\n')
print(json.dumps({k:v for k,v in manifest.items() if k!='files'}))
