#!/usr/bin/env python3
"""Read-only comparison of the immutable onward archive union against this tree."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[2]
ARCHIVES={
 'MOKSHA-Placeable-Onward-Marker-2026-10-20-Project.zip':'20cfa33a57c943037cf149f97d0fd878abe2f421b30c5ca68e0db3c276ce8504',
 'MOKSHA-Placeable-Onward-Marker-2026-10-20-Verification.zip':'b604e398cb17dfe607968c480323111238b12399a8f6ad49fb0adabd8ab2a96e'}
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def run():
 baseline={};verified={}
 for name,expected in ARCHIVES.items():
  path=Path('/workspace/shared')/name
  actual=digest(path);verified[name]=actual
  if actual!=expected:raise RuntimeError('Archive changed: '+name)
  with zipfile.ZipFile(path) as z:
   for item in z.infolist():
    if item.is_dir():continue
    rel=item.filename.removeprefix('MOKSHA/')
    # Packaging-only overlap, not one of the 4,472 original source/evidence files.
    if rel=='SPLIT_CHECKPOINT_README.txt':continue
    with z.open(item) as stream:
     h=hashlib.sha256()
     for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
    if rel in baseline and baseline[rel]!=h.hexdigest():raise RuntimeError('Archive union collision: '+rel)
    baseline[rel]=h.hexdigest()
 changed=[];missing=[]
 for rel,sha in baseline.items():
  path=ROOT/rel
  if not path.is_file():missing.append(rel)
  elif digest(path)!=sha:changed.append(rel)
 allowed={'simulation/tests/room_backdrop_regression.gd','demo/tests/review_mission_integration.gd','demo/components/mission_room.gd','simulation/MODULE_MAP.md','simulation/README.md'}
 report={'baseline_archives':verified,'union_file_count':len(baseline),'changed':changed,'missing':missing,'allowed_changes':sorted(allowed),'passed':not missing and set(changed)<=allowed}
 (ROOT/'simulation/evidence/exchange_station_preservation.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
 return report['passed']
if __name__=='__main__':raise SystemExit(0 if run() else 1)
