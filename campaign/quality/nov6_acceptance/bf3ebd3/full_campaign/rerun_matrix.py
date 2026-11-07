#!/usr/bin/env python3
"""Repeat this exact committed six-case matrix in a NEW isolated directory.

Needs a Git repository containing the recorded commit, Godot 4.6.3, Python 3 and
GNU/BSD tar. No source overlay or live-checkout edits. Generated user directories
and the source archive remain solely under --output. Old evidence is untouched.
Launch randomness is normal game randomness; timings are not deterministic or
human playtime. This wrapper only makes the recorded runner's paths portable.
"""
from pathlib import Path
import argparse,importlib.util,json,subprocess,sys
sys.dont_write_bytecode=True # Do not add caches to recorded evidence.
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[5])
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
repo=args.repo.resolve();output=args.output.resolve()
version=subprocess.check_output(['godot','--version'],text=True).strip()
if not version.startswith('4.6.3.'):
    raise SystemExit('Use the tested Godot 4.6.3 engine; found '+version)
recorded=Path(__file__).with_name('run_matrix_recorded.py')
spec=importlib.util.spec_from_file_location('recorded_matrix',recorded)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
actual=subprocess.check_output(['git','rev-parse',module.COMMIT],cwd=repo,text=True).strip()
if actual!=module.COMMIT:raise SystemExit('Recorded full commit did not resolve exactly')
output.mkdir(parents=True,exist_ok=False)
module.SOURCE=repo;module.ROOT=output;module.PROJECT=output/'project'
module.main()
summary=json.loads((output/'matrix_summary.json').read_text())
raise SystemExit(0 if summary['passed'] else 1)
