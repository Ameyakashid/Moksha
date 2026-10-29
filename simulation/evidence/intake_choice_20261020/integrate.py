from pathlib import Path
import json,hashlib,shutil
src=Path('intake_candidate');dst=Path('moksha');out=dst/'simulation/evidence/intake_choice_20261020'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
r=json.loads(Path('intake_acceptance/combined/results.json').read_text());assert r['passed'] and r['sources_unchanged']
base=json.loads(Path('intake_acceptance/delivered_baseline_sources.json').read_text())
for rel,h in base.items():assert sha(dst/rel)==h,'Canonical drift '+rel
for rel,h in r['source_sha256'].items():assert sha(src/rel)==h,'Candidate drift '+rel
changes=[]
for p in sorted(src.rglob('*')):
 if not p.is_file():continue
 rel=p.relative_to(src)
 if {'.godot','evidence','delivery','__pycache__'}.intersection(rel.parts) or p.suffix in {'.import','.pyc'} or p.name=='SPLIT_CHECKPOINT_README.txt':continue
 q=dst/rel;b=sha(q) if q.exists() else None;a=sha(p)
 if a!=b:changes.append({'path':str(rel),'before_sha256':b,'after_sha256':a})
existing_runtime=[c['path'] for c in changes if c['before_sha256'] and Path(c['path']).suffix in {'.gd','.tscn','.tres','.godot'}]
assert existing_runtime==['demo/mission_data.gd'],existing_runtime
assert not out.exists();out.mkdir(parents=True)
(out/'source_changes.json').write_text(json.dumps(changes,indent=2))
for c in changes:
 q=dst/c['path'];q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src/c['path'],q)
index=[]
for p in src.rglob('*'):
 if not p.is_file():continue
 rel=p.relative_to(src)
 if 'evidence' not in rel.parts or '.godot' in rel.parts or p.suffix=='.import':continue
 q=dst/rel
 if q.exists() and sha(q)==sha(p):continue
 t=out/'fresh_evidence'/rel;t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,t)
 index.append({'path':str(rel),'sha256':sha(p),'prior_preserved':q.exists()})
 if not q.exists():q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
(out/'evidence_index.json').write_text(json.dumps(index,indent=2))
for p in Path('intake_acceptance').iterdir():
 if p.is_file():shutil.copy2(p,out/p.name)
shutil.copytree('intake_acceptance/combined',out/'combined',ignore=shutil.ignore_patterns('data','cache','config'))
for p in Path('intake_implementation_handoff').iterdir():
 if p.suffix!='.zip':shutil.copy2(p,out/p.name)
# Capture handoff files copied separately after native acceptance; runtime source never changed by capture.
for rel,h in r['source_sha256'].items():assert sha(dst/rel)==h,'Integrated runtime differs '+rel
(out/'README.md').write_text('''# Intake route-choice checkpoint\n\nCurrent combined affected-regression/full-route result: `combined/results.json`. Separate `independent_layout_review.json` and `lifecycle_suspended_extended_summary.json` record29checks/rate. `isolated_results.json` indexes8approach/fall-recovery reports in fresh_evidence/demo/evidence. Earlier fixture attempts retained, not counted as passes. Canonical historical reports remain untouched; use this namespace for current changed reports.\n\nLevel-design change, not physics repair. Opening, ending, other7sectors and shared stat/core files remain unchanged. See demo/docs/INTAKE_CHOICE_REVISION.md. Reproduce independent lifecycle directly with Godot --path your/MOKSHA --script path/to/intake_lifecycle.gd -- --hz=60 (or120), isolated XDG user data; archived Python runners retain original workspace layout assumptions.\n''')
print('Integrated',len(changes),'source/doc changes and preserved',len(index),'fresh reports')
