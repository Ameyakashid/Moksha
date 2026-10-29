"""Reproduce M18 focused physical acceptance without altering any old test/report."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import json
import os
import subprocess
import sys
import tempfile
ROOT=Path(__file__).resolve().parents[2]
HERE=ROOT/'combat_pc/tests'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline-zip',type=Path,default=ROOT.parent/'moksha-backups/M18-start-20261005/MOKSHA-Two-Level-Project.zip',help='Required retained v21 archive; verified against its pinned SHA-256')
parser.add_argument('--godot-bin',default=os.environ.get('GODOT_BIN','godot'),help='Godot 4.6.3 executable; defaults to GODOT_BIN, then godot on PATH')
parser.add_argument('--evidence-only',action='store_true',help='Refresh archive proof and cross-rate summary from existing reports without running physical suites')
args=parser.parse_args()
BASELINE=args.baseline_zip.expanduser().resolve()
if not BASELINE.is_file():parser.error('Retained v21 archive is required; supply --baseline-zip /path/to/MOKSHA-Two-Level-Project.zip')
TEMP=Path(tempfile.gettempdir())
ENV=dict(os.environ,XDG_DATA_HOME=str(TEMP/'moksha-m18-data'),XDG_CACHE_HOME=str(TEMP/'moksha-m18-cache'),XDG_CONFIG_HOME=str(TEMP/'moksha-m18-config'))
for name in ('XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME'):Path(ENV[name]).mkdir(exist_ok=True,parents=True)
def run(job):
    suite,hz=job
    stem='ground_response'+('_'+suite if suite else '')
    script=stem+('_compatibility.gd' if suite else '_regression.gd')
    log=HERE/f'{stem}_{hz}hz.log'
    with log.open('w') as stream:
        result=subprocess.run([args.godot_bin,'--headless','--fixed-fps',str(hz),'--path',str(ROOT),'--script',str(HERE/script),'--','--hz='+str(hz)],env=ENV,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
    content=log.read_text()
    diagnostics=any(marker in content for marker in ('SCRIPT ERROR:','\nERROR:','\nWARNING:','FAIL:','FAIL '))
    report_path=HERE/f'{stem}_results_{hz}hz.json'
    report=json.loads(report_path.read_text()) if report_path.exists() else {}
    passed=result.returncode==0 and not diagnostics and report and not report.get('failures') and report.get('production_hash_stable_during_run')
    print(f'{stem} {hz} Hz: {len(report.get("scenarios",[]))} scenarios; {"PASS" if passed else "FAIL"}',flush=True)
    if not passed:print(content[-3000:],flush=True)
    return bool(passed)
if not args.evidence_only:
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes=list(pool.map(run,[(suite,hz) for suite in ('','health','defeat','noise') for hz in (60,120)]))
    if not all(outcomes):sys.exit(1)
for script in ('ground_response_verify_baseline.py','ground_response_compare_rates.py'):
    command=[sys.executable,str(HERE/script)]
    if script=='ground_response_verify_baseline.py':command.extend(['--baseline-zip',str(BASELINE)])
    subprocess.run(command,cwd=ROOT,check=True)
