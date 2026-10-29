#!/usr/bin/env python3
"""Package only after the final full-route/build/foundation receipts pass."""
from pathlib import Path
import hashlib,json,subprocess,zipfile,time,argparse
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT.parent/'moksha-campaign-delivery'
parser=argparse.ArgumentParser();parser.add_argument('--gameplay-commit',required=True);args=parser.parse_args()
GAMEPLAY=subprocess.check_output(['git','rev-parse',args.gameplay_commit],cwd=ROOT,text=True).strip()
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as stream:
  while block:=stream.read(1024*1024):h.update(block)
 return h.hexdigest()
def read(relative):return json.loads((ROOT/relative).read_text())
for relative in ['campaign/tests/full_route_matrix.json','campaign/tests/build_lens_matrix.json']:
 matrix=read(relative)
 assert matrix['passed'],relative
 assert len(matrix['cases'])==(4 if 'full_route_matrix' in relative else 2),relative
 for case in matrix['cases']:
  assert sha(ROOT/case['report'])==case.get('report_sha256',case.get('sha256')),f'Stale matrix receipt: {case}'
  report=read(case['report'])
  assert report['passed'] and report['completed'] and not report['source_drift'] and not report['failures'],case
  for path,digest in report['source_hashes'].items():assert sha(ROOT/path.removeprefix('res://'))==digest,path
foundation=read('simulation/evidence/foundation_report.json')
assert len(foundation['stages'])==72 and all(row['passed'] for row in foundation['stages']) and not foundation['sources_changed_during_run']
for path,digest in foundation['tested_source_sha256'].items():assert sha(ROOT/path)==digest,path
# A documentation/results commit may be newer; gameplay bytes must equal export.
runtime_suffixes={'.gd','.tscn','.tres','.gdshader','.png','.jpg','.jpeg','.webp','.ogg','.wav','.ttf','.otf'}
ignore={'tests','enemy_tests','qa_audit','route_tests','route_tests_45','evidence','docs','.git','.godot','__pycache__'}
production={}
for file in sorted(ROOT.rglob('*')):
 rel=file.relative_to(ROOT)
 if not file.is_file() or ignore.intersection(rel.parts):continue
 if file.suffix not in runtime_suffixes and file.name!='project.godot':continue
 baseline=subprocess.check_output(['git','show',f'{GAMEPLAY}:{rel.as_posix()}'],cwd=ROOT)
 assert hashlib.sha256(baseline).hexdigest()==sha(file),f'Gameplay differs from Windows export: {rel}'
 production[rel.as_posix()]=sha(file)
assert not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip(),'Commit final source/evidence before packaging'
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
OUT.mkdir(exist_ok=True)
bundle=OUT/'MOKSHA-source-history.bundle'
subprocess.run(['git','bundle','create',str(bundle),'--all'],cwd=ROOT,check=True)
subprocess.run(['git','bundle','verify',str(bundle)],cwd=ROOT,check=True,capture_output=True)
archive=OUT/'MOKSHA-Five-Ascents-2026-10-29-Project.zip'
if archive.exists():archive.rename(OUT/f'{archive.stem}_previous_{time.time_ns()}.zip')
files=[]
for file in sorted(ROOT.rglob('*')):
 rel=file.relative_to(ROOT)
 if not file.is_file() or {'.git','.godot','__pycache__','export_templates'}.intersection(rel.parts):continue
 files.append((file,rel.as_posix()))
acceptance={'six_continuous_routes':True,'foundation_stages_passed':72,'human_duration_validated':False,'native_render_review':'Bounded source-scene manual inputs and explicit visual fixtures; not complete native campaign or Windows execution','native_evidence':'campaign/evidence/native_visual/README.md','foundation_report_sha256':sha(ROOT/'simulation/evidence/foundation_report.json'),'neutral_matrix_sha256':sha(ROOT/'campaign/tests/full_route_matrix.json'),'lens_matrix_sha256':sha(ROOT/'campaign/tests/build_lens_matrix.json')}
manifest={'acceptance':acceptance,'date':'2026-10-29','source_commit':commit,'gameplay_and_windows_commit':GAMEPLAY,'gameplay_matches_windows_commit':True,'production_sha256':production,'human_duration_validated':False,'native_windows_run_verified':False,'files':[{'path':name,'bytes':file.stat().st_size,'sha256':sha(file)} for file,name in files],'history_bundle_sha256':sha(bundle)}
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for file,name in files:z.write(file,'MOKSHA/'+name)
 z.write(bundle,'MOKSHA/history/MOKSHA-source-history.bundle')
 z.writestr('MOKSHA/DELIVERY_MANIFEST.json',json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
windows=OUT/f'MOKSHA-Windows-x64-{GAMEPLAY[:7]}.zip'
export=json.loads((OUT/f'windows-candidate-{GAMEPLAY[:7]}-report.json').read_text())
assert export['source_commit']==GAMEPLAY and sha(windows)==export['sha256']
assert all(row['passed'] for row in export['pack_audits'].values())
with zipfile.ZipFile(windows) as z:
 assert z.testzip() is None
 assert hashlib.sha256(z.read('MOKSHA-Windows/MOKSHA.pck')).hexdigest()==export['pck_sha256']
result={'source_zip':str(archive),'source_bytes':archive.stat().st_size,'source_sha256':sha(archive),'source_commit':commit,'gameplay_commit':GAMEPLAY,'history_bundle':str(bundle),'history_sha256':sha(bundle),'windows_zip':str(windows),'windows_bytes':windows.stat().st_size,'windows_sha256':sha(windows),'fresh_extraction_verified':False}
(OUT/'MOKSHA-delivery-manifest.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
