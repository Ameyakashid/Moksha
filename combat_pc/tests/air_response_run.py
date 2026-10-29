"""Run focused M19 actual-physics acceptance using Godot 4.6.3 and retained v22 ZIP."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
ROOT=Path(__file__).resolve().parents[2]
HERE=ROOT/'combat_pc/tests'
PIN='ad1450d6451afb9943943d37af3a77dc6f543869635dcd5564867c5c2835a28c'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline-zip',type=Path,required=True,help='Retained M19-start approved v22 ZIP; hash checked before any run')
parser.add_argument('--godot-bin',default=os.environ.get('GODOT_BIN','godot'))
parser.add_argument('--suites',nargs='+',default=['air','owners','ground','archive','health','defeat','noise'],choices=['air','owners','ground','archive','health','defeat','noise'])
parser.add_argument('--hz',nargs='+',type=int,default=[60,120],choices=[60,120])
parser.add_argument('--skip-comparison',action='store_true',help='Use for targeted development reruns; final acceptance requires default suite set and comparison')
args=parser.parse_args()
archive=args.baseline_zip.expanduser().resolve()
if not archive.is_file() or hashlib.sha256(archive.read_bytes()).hexdigest()!=PIN:parser.error('Retained baseline ZIP must exist and match pinned v22 SHA-256')
subprocess.run([sys.executable,str(HERE/'air_response_verify_baseline.py'),'--baseline-zip',str(archive)],cwd=ROOT,check=True)
base=Path(tempfile.gettempdir())
env=dict(os.environ)
for key,part in [('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('XDG_CONFIG_HOME','config')]:
    target=base/f'moksha-m19-{part}'
    target.mkdir(exist_ok=True,parents=True)
    env[key]=str(target)
def run(job):
    suite,hz=job
    stem='air_response'+('' if suite=='air' else '_'+suite)
    script='air_response_regression.gd' if suite=='air' else ('air_response_owners.gd' if suite=='owners' else stem+'_compatibility.gd')
    report_path=HERE/f'{stem}_results_{hz}hz.json'
    # Remove a stale new M19 report, so a parse failure cannot look successful.
    report_path.unlink(missing_ok=True)
    log=HERE/f'{stem}_{hz}hz.log'
    command=[args.godot_bin,'--headless','--fixed-fps',str(hz),'--path',str(ROOT),'--script',str(HERE/script),'--',f'--hz={hz}',f'--baseline-zip={archive}']
    with log.open('w') as stream:
        result=subprocess.run(command,env=env,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
    content=log.read_text()
    diagnostics=any(marker in content for marker in ('SCRIPT ERROR:','\nERROR:','\nWARNING:','FAIL:','FAIL '))
    report=json.loads(report_path.read_text()) if report_path.is_file() else {}
    passed=result.returncode==0 and not diagnostics and bool(report) and not report.get('failures') and report.get('production_hash_stable_during_run')
    print(f'{stem} {hz} Hz: {len(report.get("scenarios",[]))} scenarios; {"PASS" if passed else "FAIL"}',flush=True)
    if not passed:print(content[-5000:],flush=True)
    return bool(passed)
with ThreadPoolExecutor(max_workers=2) as pool:
    outcomes=list(pool.map(run,[(suite,hz) for suite in args.suites for hz in args.hz]))
if not all(outcomes):sys.exit(1)
if not args.skip_comparison:
    subprocess.run([sys.executable,str(HERE/'air_response_compare_rates.py')],cwd=ROOT,check=True)
