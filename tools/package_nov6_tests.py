#!/usr/bin/env python3
"""Packaging safety/unit checks. These never build or modify the game."""
import importlib.util
import math
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("package_nov6", Path(__file__).with_name("package_nov6.py"))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
split_spec = importlib.util.spec_from_file_location("package_nov6_split", Path(__file__).with_name("package_nov6_split.py"))
split_package = importlib.util.module_from_spec(split_spec)
split_spec.loader.exec_module(split_package)


class PackagingTests(unittest.TestCase):
    def test_runtime_selection_keeps_game_and_dynamic_data(self):
        for name in ("project.godot", "campaign/logic/campaign.gd", "campaign/layouts/level_05.gd",
                     "simulation/actors/shared_actor.tscn", "campaign/assets/themes/01_rainline.tres",
                     "audio/hit.wav.import", "fonts/DejaVuSansMono.ttf", "assets/characters/operative_animations.json"):
            with self.subTest(name=name):
                self.assertTrue(package.included_runtime(Path(name)))

    def test_runtime_selection_excludes_developer_scenes_and_receipts(self):
        for name in ("campaign/tests/campaign_smoke.gd", "campaign/quality/replay_probe.gd",
                     "campaign/qa_audit/incoming_health.gd", "campaign/route_tests/report.json",
                     "simulation/body_echo_pixels.tscn", "tools/package_nov6.py",
                     ".godot/imported/anything.ctex", "export_templates/windows_release_x86_64.exe"):
            with self.subTest(name=name):
                self.assertFalse(package.included_runtime(Path(name)))

    def test_member_paths_reject_traversal_and_absolute_names(self):
        for name in ("", "/tmp/file", "../file", "game/../../file", "game\\file"):
            self.assertFalse(package.safe_member(name), name)
        for name in ("MOKSHA/MOKSHA.pck", "MOKSHA/licenses/LICENSE.txt", "game/"):
            self.assertTrue(package.safe_member(name), name)

    def test_error_scanner_detects_errors_despite_success_exit(self):
        for text in ("ERROR: resource missing", "SCRIPT ERROR: Parser Error", "FAIL save changed", "  ERROR: file"):
            self.assertIsNotNone(package.ERROR_PATTERN.match(text))
        self.assertIsNone(package.ERROR_PATTERN.match("PACK_AUDIT_RESULT failures=[]"))

    def test_zip_round_trip_and_executable_mode(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            tree = base / "MOKSHA-Linux"
            tree.mkdir()
            launcher = tree / "Start-MOKSHA.sh"
            launcher.write_text("#!/bin/sh\necho game\n")
            launcher.chmod(0o755)
            (tree / "MOKSHA.pck").write_bytes(b"GDPC" + bytes(range(256)))
            report = package.archive_tree(tree, base / "build.zip")
            self.assertEqual(report["sha256"], package.sha(base / "build.zip"))
            package.extract_zip(base / "build.zip", base / "fresh")
            self.assertEqual((base / "fresh/MOKSHA-Linux/MOKSHA.pck").read_bytes(), (tree / "MOKSHA.pck").read_bytes())
            self.assertEqual((base / "fresh/MOKSHA-Linux/Start-MOKSHA.sh").stat().st_mode & 0o777, 0o755)
            with self.assertRaises(RuntimeError):
                package.archive_tree(tree, base / "build.zip")

    def test_zip_rejects_traversal_duplicates_and_symlinks(self):
        for case in ("traversal", "duplicate", "symlink"):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary)
                zipped = base / "bad.zip"
                with zipfile.ZipFile(zipped, "w") as archive:
                    if case == "traversal":
                        archive.writestr("../escape.txt", "bad")
                    elif case == "duplicate":
                        archive.writestr("same.txt", "first")
                        archive.writestr("same.txt", "second")
                    else:
                        info = zipfile.ZipInfo("link")
                        info.create_system = 3
                        info.external_attr = 0o120777 << 16
                        archive.writestr(info, "../escape")
                with self.assertRaises(RuntimeError):
                    package.extract_zip(zipped, base / "fresh")
                self.assertFalse((base / "escape.txt").exists())

    def test_attachment_split_exact_round_trip(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            zipped = base / "build.zip"
            with zipfile.ZipFile(zipped, "w") as archive:
                archive.writestr("MOKSHA-Windows/MOKSHA.exe", b"MZ" + b"1" * 6000)
                archive.writestr("MOKSHA-Windows/MOKSHA.pck", b"GDPC" + b"2" * 6000)
            result = split_package.make_parts(zipped, base / "parts", 4096)
            self.assertTrue(result["reassembly_verified"])
            self.assertEqual(len(result["parts"]), math.ceil(zipped.stat().st_size / 4096))
            self.assertEqual(result["complete_sha256"], package.sha(zipped))
            self.assertFalse(result["windows_helper_executed"])
            with zipfile.ZipFile(result["parts"][0]["path"]) as archive:
                helper = archive.read("Assemble-MOKSHA.cmd").decode()
                self.assertIn("Get-FileHash", helper)
                self.assertIn("CreateNew", helper)
                self.assertNotIn("ExecutionPolicy", helper)
                self.assertNotIn("Invoke-WebRequest", helper)
            with self.assertRaises(RuntimeError):
                split_package.make_parts(zipped, base / "parts", 4096)


if __name__ == "__main__":
    unittest.main()
