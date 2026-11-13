#!/usr/bin/env python3
"""Mutation tests prove the gates reject their intended regressions."""
import json
import hashlib
from pathlib import Path
import struct
import tempfile
import unittest
import wave
from assets_audit import audit, inventory

class AssetGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/'project.godot').write_text('[application]\nrun/main_scene="res://main.tscn"\n')
        (self.root/'main.tscn').write_text('[gd_scene format=3]\n')
        self.budgets = {'limits': {k: 10**9 for k in inventory(self.root)['metrics']}}
    def result(self):
        return audit(self.root, self.budgets)
    def test_valid_source_and_hash(self):
        result = self.result()
        self.assertTrue(result['passed'])
        self.assertEqual(len(result['files'][0]['sha256']), 64)
        self.assertEqual(result['literal_references_checked'], 1)
    def test_missing_main_scene(self):
        (self.root/'main.tscn').unlink()
        self.assertFalse(self.result()['passed'])
    def test_missing_serialized_reference(self):
        (self.root/'main.tscn').write_text('[ext_resource type="Texture2D" path="res://missing.png" id="1"]')
        self.assertFalse(self.result()['passed'])
    def test_missing_load_and_preload(self):
        for verb in ('load', 'preload'):
            with self.subTest(verb=verb):
                (self.root/'code.gd').write_text(f'var a = {verb}("res://missing.tres")')
                self.assertFalse(self.result()['passed'])
    def test_dynamic_path_not_misclassified(self):
        (self.root/'code.gd').write_text('var a = load("res://audio/"+key+".wav")')
        self.assertTrue(self.result()['passed'])
    def test_growth_budget_rejects(self):
        self.budgets['limits']['inventory_bytes'] = 1
        self.assertFalse(self.result()['passed'])
    def test_evidence_excluded(self):
        (self.root/'evidence').mkdir()
        (self.root/'evidence'/'bad.gd').write_text('var a = preload("res://missing.tres")')
        self.assertTrue(self.result()['passed'])
    def test_invalid_png(self):
        (self.root/'bad.png').write_bytes(b'not a PNG')
        self.assertFalse(self.result()['passed'])
    def test_png_dimensions_and_budget(self):
        (self.root/'header.png').write_bytes(b'\x89PNG\r\n\x1a\n'+b'\0\0\0\rIHDR'+struct.pack('>II',32,64))
        self.assertEqual(self.result()['metrics']['largest_png_pixels'], 2048)
        self.budgets['limits']['largest_png_pixels'] = 1024
        self.assertFalse(self.result()['passed'])
    def test_invalid_wav(self):
        (self.root/'bad.wav').write_bytes(b'not a WAV')
        self.assertFalse(self.result()['passed'])
    def test_pcm_accounting_and_truncation(self):
        path = self.root/'sound.wav'
        with wave.open(str(path), 'wb') as wav:
            wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(22050)
            wav.writeframes(b'\0'*200)
        self.assertEqual(self.result()['metrics']['wav_pcm_bytes'], 200)
        path.write_bytes(path.read_bytes()[:-10])
        self.assertFalse(self.result()['passed'])
    def test_unsafe_resource_path(self):
        (self.root/'code.gd').write_text('var a = preload("res://../outside.tres")')
        self.assertFalse(self.result()['passed'])

class ExactLargeAssetException(AssetGuards):
    def setUp(self):
        super().setUp()
        self.asset = self.root / 'reviewed.tres'
        self.asset.write_bytes(b'a' * 100)
        self.budgets['limits']['largest_file_bytes'] = 90
        self.budgets['largest_file_exceptions'] = [{
            'path': 'reviewed.tres', 'bytes': 100,
            'sha256': hashlib.sha256(self.asset.read_bytes()).hexdigest()}]
    def test_valid_exception(self):
        self.assertTrue(self.result()['passed'])
        self.assertEqual(self.result()['metrics']['largest_file_bytes'], 100)
    def test_changed_hash(self):
        self.asset.write_bytes(b'b' * 100)
        self.assertFalse(self.result()['passed'])
    def test_changed_size(self):
        self.asset.write_bytes(b'a' * 99)
        self.assertFalse(self.result()['passed'])
    def test_changed_path(self):
        self.asset.rename(self.root / 'renamed.tres')
        self.assertFalse(self.result()['passed'])
    def test_missing_exception_asset(self):
        self.asset.unlink()
        self.assertFalse(self.result()['passed'])
    def test_unlisted_oversize(self):
        (self.root / 'unlisted.tres').write_bytes(b'b' * 101)
        self.assertFalse(self.result()['passed'])
    def test_duplicate_exception(self):
        self.budgets['largest_file_exceptions'] *= 2
        self.assertFalse(self.result()['passed'])

if __name__ == '__main__':
    unittest.main()
