"""Packaging-only negatives. No engine, export or runtime modifications."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
spec = importlib.util.spec_from_file_location('package', Path(__file__).with_name('package_nov6.py'))
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)

class HearingPackaging(unittest.TestCase):
    def test_bare_receipt(self):
        receipt = {'checks': 3, 'passed': True, 'failures': []}
        self.assertEqual(p.result_receipt('Godot banner\n'+json.dumps(receipt)+'\n', ''), receipt)

    def test_missing_false_ambiguous_and_errors(self):
        valid = json.dumps({'checks': 3, 'passed': True, 'failures': []})
        bad = ['', 'Godot banner', valid+'\n'+valid, '{broken',
               '{"passed":false,"checks":3,"failures":[]}',
               '{"passed":true,"checks":0,"failures":[]}',
               '{"passed":true,"checks":true,"failures":[]}',
               '{"passed":true,"checks":3,"failures":["bad"]}',
               valid+'\nERROR: bad', 'SCRIPT ERROR: bad\n'+valid]
        for log in bad:
            with self.subTest(log=log), self.assertRaises((RuntimeError, ValueError)):
                p.result_receipt(log, '')

    def test_command_rejects_nonzero_and_error_even_with_valid_receipt(self):
        valid = json.dumps({'checks': 3, 'passed': True, 'failures': []})
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for code, stderr in [(1, ''), (0, 'ERROR: fixture failed')]:
                proc = SimpleNamespace(returncode=code, stdout=valid+'\n', stderr=stderr)
                with patch.object(p.subprocess, 'run', return_value=proc), self.assertRaises(RuntimeError):
                    p.command_check('negative', ['unused'], root, {}, root, result_prefix='')

    def test_camera_external_dependency(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); contract=root/'original.gd'; baseline=root/'original-baseline.gd'
            text='extends SceneTree\nconst Rig=preload("res://campaign/presentation/camera_follow.gd")\nconst Baseline=preload("res://campaign/quality/nov12_fall_framing/baseline.gd")\n'
            contract.write_text(text); baseline.write_text('extends RefCounted\n')
            result=p.externalize_camera_contract(contract, baseline, root/'external')
            adapted=Path(result['script']).read_text()
            self.assertEqual(adapted,text.replace('res://campaign/quality/nov12_fall_framing/baseline.gd','baseline.gd'))
            self.assertEqual(contract.read_text(),text)
            self.assertEqual(result['baseline_sha256'],p.sha(baseline))
            self.assertEqual(result['original_sha256'],p.sha(contract))
            self.assertEqual(result['adapted_sha256'],p.sha(Path(result['script'])))
            with self.assertRaises(RuntimeError):p.externalize_camera_contract(contract,baseline,root/'external')
            for bad in [text.replace('baseline.gd','absent.gd'),text+text]:
                contract.write_text(bad)
                with self.assertRaises(RuntimeError):p.externalize_camera_contract(contract,baseline,root/'bad')

    def test_matrix_and_guide(self):
        self.assertEqual(len(p.RECEIPT_FIXTURES),9)
        self.assertEqual(len(p.REACTIVE_RECEIPT_FIXTURES),5)
        self.assertEqual(len(p.HEARING_RECEIPT_FIXTURES),5)
        self.assertEqual(sum(row[2] for row in p.HEARING_RECEIPT_FIXTURES),1)
        text=p.readme('Windows','sha','engine')
        self.assertIn('version-3',text);self.assertIn('v1/v2',text)
        self.assertIn('NOT been executed on Windows',text)
        self.assertNotIn('writes\nversion-2',text)
        self.assertFalse(p.included_runtime(Path('campaign/quality/nov12_fall_framing/baseline.gd')))

if __name__=='__main__':unittest.main()
