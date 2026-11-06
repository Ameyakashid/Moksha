#!/usr/bin/env python3
"""Small filesystem/verdict guard tests; does not run Godot or edit a project."""
import importlib.util,pathlib,subprocess,sys,tempfile,unittest
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('transition_runner',HERE/'run.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
class RunnerGuards(unittest.TestCase):
 def test_source_hashes_detect_modified_and_missing_files(self):
  with tempfile.TemporaryDirectory() as td:
   root=pathlib.Path(td);(root/'project.godot').write_text('config_version=5\n');(root/'logic.gd').write_text('extends Node\n')
   baseline=runner.files(root);self.assertEqual(runner.mismatches(root,baseline),[])
   (root/'logic.gd').write_text('extends Node2D\n');self.assertEqual(runner.mismatches(root,baseline),['logic.gd'])
   (root/'project.godot').unlink();self.assertEqual(set(runner.mismatches(root,baseline)),{'logic.gd','project.godot'})
 def test_only_generated_metadata_is_excluded(self):
  with tempfile.TemporaryDirectory() as td:
   root=pathlib.Path(td)
   for name in ('.git/config','.godot/cache','__pycache__/cache','campaign/evidence/proof.json','audio/source.wav'):
    p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture')
   self.assertEqual(set(runner.files(root)),{'campaign/evidence/proof.json','audio/source.wav'})
 def test_stable_copy_isolated_and_hashed(self):
  with tempfile.TemporaryDirectory() as td:
   root=pathlib.Path(td);source=root/'source';source.mkdir();(source/'project.godot').write_text('config_version=5\n');(source/'logic.gd').write_text('extends Node\n')
   output=root/'output';output.mkdir();(output/'evidence').mkdir();before=runner.files(source)
   project,baseline,fixtures,identity=runner.snapshot(source,None,output)
   self.assertEqual(runner.files(source),before);self.assertEqual(baseline,before);self.assertEqual(runner.mismatches(project,baseline),[])
   self.assertEqual(runner.mismatches(project,fixtures),[]);self.assertEqual(identity['method'],'stable file copy');self.assertIsNone(identity['commit'])
   self.assertTrue((output/'evidence/source_manifest.json').is_file())
 def test_rejects_overwriting_existing_evidence(self):
  with tempfile.TemporaryDirectory() as td:
   root=pathlib.Path(td);source=root/'source';source.mkdir();(source/'project.godot').write_text('config_version=5\n')
   output=root/'output';output.mkdir();(output/'keep.txt').write_text('preserve')
   p=subprocess.run([sys.executable,str(HERE/'run.py'),'--source',str(source),'--output',str(output)],capture_output=True,text=True)
   self.assertEqual(p.returncode,2);self.assertIn('existing evidence is never overwritten',p.stderr);self.assertEqual((output/'keep.txt').read_text(),'preserve')
 def test_rejects_output_inside_source(self):
  with tempfile.TemporaryDirectory() as td:
   source=pathlib.Path(td);(source/'project.godot').write_text('config_version=5\n');before=runner.files(source)
   p=subprocess.run([sys.executable,str(HERE/'run.py'),'--source',str(source),'--output',str(source/'run')],capture_output=True,text=True)
   self.assertEqual(p.returncode,2);self.assertIn('outside the source',p.stderr);self.assertEqual(runner.files(source),before)
 def test_diagnostics_reject_errors_and_leaks(self):
  for diagnostic in ('SCRIPT ERROR: broken','ERROR: failed','Parse Error: bad','Assertion failed','WARNING: ObjectDB instances leaked at exit'):
   self.assertIsNotNone(runner.DIAGNOSTICS.search(diagnostic))
  self.assertIsNone(runner.DIAGNOSTICS.search('Godot Engine v4.6.3\nTRANSITION_STRESS_RESULT {"passed":true}'))
if __name__=='__main__':unittest.main(verbosity=2)
