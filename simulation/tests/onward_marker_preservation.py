#!/usr/bin/env python3
"""Read-only comparison of the immutable signs archive union against this tree."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[2]
ARCHIVES={
 'MOKSHA-Placeable-World-Signs-2026-10-20-Project.zip':'7813e1f8ef0891066b6f735771316cff820c49c0962b54a1bb2bc9f103526594',
 'MOKSHA-Placeable-World-Signs-2026-10-20-Verification.zip':'146b303edd7135a2b0991edc5eb9373b5cf75001bac135b26e3e84d2ab6c5bd0'}
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
    # Packaging-only overlap, not one of the 4,055 original source/evidence files.
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
 allowed={'demo/tests/review_mission_integration.gd','demo/components/mission_room.gd','simulation/MODULE_MAP.md','simulation/README.md'}
 report={'baseline_archives':verified,'union_file_count':len(baseline),'changed':changed,'missing':missing,'allowed_changes':sorted(allowed),'passed':not missing and set(changed)<=allowed}
 (ROOT/'simulation/evidence/onward_marker_preservation.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
 return report['passed']
if __name__=='__main__':raise SystemExit(0 if run() else 1)
