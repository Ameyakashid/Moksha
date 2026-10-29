#!/usr/bin/env python3
"""Read-only comparison of the immutable Exchange archive union against this tree."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[2]
ARCHIVES={
 'MOKSHA-Placeable-Exchange-Station-2026-10-20-Project.zip':'f5fab2909e085de29476ee2a4960d4dc178b47bd72c650fee009e15791b1463c',
 'MOKSHA-Placeable-Exchange-Station-2026-10-20-Verification.zip':'885a15704af0cc12d0ce4855e1547a9401e88a2cabff00ae0bc9196de19215a0'}
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
    # Packaging-only overlap, not one of the 5,058 original source/evidence files.
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
 allowed={'demo/tests/expanded_mission_route_bot.gd','simulation/tests/exchange_station_regression.gd','demo/tests/review_mission_integration.gd','demo/components/mission_room.gd','simulation/MODULE_MAP.md','simulation/README.md'}
 report={'baseline_archives':verified,'union_file_count':len(baseline),'changed':changed,'missing':missing,'allowed_changes':sorted(allowed),'passed':not missing and set(changed)<=allowed}
 (ROOT/'simulation/evidence/relay_marker_preservation.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
 return report['passed']
if __name__=='__main__':raise SystemExit(0 if run() else 1)
