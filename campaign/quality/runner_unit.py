"""Negative controls: false-success diagnostics must fail the gate."""
import os
from pathlib import Path
import sys
import tempfile
import unittest
from run_quality import run_stage

class RunnerTests(unittest.TestCase):
    def run_case(self, code, marker='DONE', timeout=5):
        with tempfile.TemporaryDirectory() as directory:
            return run_stage('probe', [sys.executable, '-c', code], os.environ, Path(directory), marker, timeout)
    def test_success(self):
        self.assertTrue(self.run_case("print('DONE')")['passed'])
    def test_missing_sentinel(self):
        self.assertFalse(self.run_case("print('nothing')")['passed'])
    def test_errors_with_success_exit(self):
        for diagnostic in ('ERROR: broken','SCRIPT ERROR: bad type','FAIL mismatch','\x1b[31mERROR: colored\x1b[0m'):
            self.assertFalse(self.run_case(f'print({diagnostic!r});print("DONE")')['passed'])
    def test_nonzero(self):
        self.assertFalse(self.run_case("print('DONE');raise SystemExit(1)")['passed'])
    def test_timeout(self):
        row = self.run_case('import time;time.sleep(10)', timeout=0.05)
        self.assertEqual(row['exit_code'], 124)
        self.assertFalse(row['passed'])
    def test_missing_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            row = run_stage('probe', ['/nonexistent/moksha-test'], os.environ, Path(directory))
            self.assertEqual(row['exit_code'], 127)
            self.assertFalse(row['passed'])
if __name__ == '__main__':
    unittest.main()
