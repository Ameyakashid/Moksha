#!/usr/bin/env python3
"""Static safety/packaging contract, not Windows CMD execution proof."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PCStartupContract(unittest.TestCase):
    def test_launcher_is_plain_cmd_with_safe_project_path(self):
        raw = (ROOT / 'Play-MOKSHA.cmd').read_bytes()
        self.assertTrue(raw.startswith(b'@echo off\r\n'))
        self.assertNotIn(b'\r\r\n', raw)
        text = raw.decode('ascii')
        self.assertIn('setlocal DisableDelayedExpansion', text)
        self.assertIn('set "ENGINE=%~f1"', text)
        self.assertIn('if not exist "%ENGINE%"', text)
        self.assertIn('if not "%VERSION:~0,6%"=="4.6.3."', text)
        self.assertEqual(text.count('--path "%~dp0."'), 2)
        import_at = text.index('--headless --editor')
        failure_at = text.index('if errorlevel 1', import_at)
        run_at = text.index('"%ENGINE%" --path', failure_at)
        self.assertLess(import_at, failure_at)
        self.assertLess(failure_at, run_at)
        self.assertIn('exit /b 4', text[failure_at:run_at])
        for forbidden in ['ExecutionPolicy', 'Invoke-WebRequest', 'curl ', 'bitsadmin', 'runas ', 'setx ', 'reg add']:
            self.assertNotIn(forbidden.lower(), text.lower())

    def test_docs_distinguish_source_from_delivered_export(self):
        text = (ROOT / 'campaign/docs/PC_QUICKSTART.md').read_text()
        for required in ['git clone https://github.com/Ameyakashid/Moksha.git',
                         'project.godot', 'Godot 4.6.3', 'MOKSHA.pck',
                         'c73159b', 'native Windows execution remains unverified']:
            self.assertIn(required, text)
        self.assertIn('campaign/docs/PC_QUICKSTART.md', (ROOT / 'README.md').read_text())


if __name__ == '__main__':
    unittest.main()
