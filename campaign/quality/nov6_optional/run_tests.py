#!/usr/bin/env python3
"""Runner guard tests use synthetic subprocess results, not gameplay evidence."""
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('optional_runner',Path(__file__).with_name('run.py'))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)

class RunnerGuards(unittest.TestCase):
    def execute(self, *, code=0, errors='', report=True, declared=True, drift=False):
        with tempfile.TemporaryDirectory(prefix='moksha-optional-runner-') as temp:
            root = Path(temp)
            production = root/'production'
            production.mkdir()
            source = production/'actor.gd'
            source.write_text('synthetic source, not a game actor\n')
            expected = RUNNER.sha(source)
            output = root/'evidence'
            output.mkdir()
            case = dict(name='synthetic_60',hz=60,script='res://fixture.gd')
            def fake_run(command, *, env, stdout, **kwargs):
                for name in ['HOME','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
                    self.assertTrue(Path(env[name]).is_dir())
                    self.assertTrue(Path(env[name]).is_relative_to(output))
                self.assertEqual(env['MOKSHA_QUALITY_ISOLATED'],'1')
                if report:
                    path=Path(next(arg.removeprefix('--output=') for arg in command if arg.startswith('--output=')))
                    path.write_text(json.dumps(dict(passed=declared,source_drift=[],source_hashes={'res://actor.gd':expected},failures=[])))
                if drift: source.write_text('changed\n')
                stdout.write('OPTIONAL_LIFECYCLE_RESULT passed=true\n'+errors)
                stdout.flush()
                return SimpleNamespace(returncode=code)
            with patch.object(RUNNER,'ROOT',production), patch.object(RUNNER.subprocess,'run',side_effect=fake_run):
                return RUNNER.run_case(case,output,1)
    def test_clean_receipt(self):
        self.assertTrue(self.execute()['passed'])
    def test_engine_error_with_zero_exit(self):
        result=self.execute(errors='SCRIPT ERROR: synthetic failure\n')
        self.assertFalse(result['passed'])
        self.assertTrue(result['engine_errors'])
    def test_nonzero_exit(self):
        self.assertFalse(self.execute(code=1)['passed'])
    def test_missing_report(self):
        self.assertFalse(self.execute(report=False)['passed'])
    def test_failed_report(self):
        self.assertFalse(self.execute(declared=False)['passed'])
    def test_source_drift_after_report(self):
        result=self.execute(drift=True)
        self.assertFalse(result['passed'])
        self.assertEqual(result['source_drift_after_run'],['res://actor.gd'])
if __name__=='__main__':
    unittest.main()
