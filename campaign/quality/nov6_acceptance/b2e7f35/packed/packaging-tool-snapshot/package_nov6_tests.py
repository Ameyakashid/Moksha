#!/usr/bin/env python3
"""Packaging safety/unit checks. These never build or modify the game."""
import importlib.util
import math
import subprocess
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

    def test_fixture_receipts_fail_closed(self):
        self.assertEqual(package.result_receipt('TEST {"passed":true,"failures":[],"checks":3}', 'TEST ')["checks"], 3)
        for log in ('', 'TEST {}', 'TEST {"passed":false,"failures":[],"checks":3}',
                    'TEST {"passed":true,"failures":["broken"],"checks":3}',
                    'TEST {"passed":true,"failures":[],"checks":0}',
                    'TEST {"passed":true,"failures":[],"checks":true}',
                    'TEST {"passed":true,"failures":[],"checks":1.5}',
                    'TEST {"passed":true,"failures":[],"checks":"3"}',
                    'TEST {"passed":true,"failures":[],"checks":3}\nTEST {"passed":true,"failures":[],"checks":3}'):
            with self.subTest(log=log), self.assertRaises(RuntimeError):
                package.result_receipt(log, 'TEST ')

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

    def test_complete_source_and_history_variants(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            frozen = base / "frozen"
            frozen.mkdir()
            for name, data in {"project.godot": b"config_version=5\n", "campaign/tests/test.gd": b"extends SceneTree\n",
                               "campaign/docs/guide.md": b"All documentation stays.\n", "campaign/evidence/result.json": b'{"passed":true}',
                               "assets/data.bin": bytes(range(256))}.items():
                path = frozen / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            hashes = {p.relative_to(frozen).as_posix(): package.sha(p) for p in frozen.rglob("*") if p.is_file()}
            bundle = base / "history.bundle"
            bundle.write_bytes(b"# v2 git bundle\n" + b"preserved-history\n" * 200)
            dist = base / "dist"
            dist.mkdir()
            results = package.package_source_variants(frozen, hashes, "abcdef123", "abcdef123", bundle, "pckhash", dist, base)
            self.assertEqual(set(results), {"source", "history", "source_and_history"})
            self.assertEqual(results["source"]["intended_library_identity"], "existing_editable_source")
            self.assertFalse(results["source"]["history_embedded"])
            self.assertTrue(results["source_and_history"]["history_embedded"])
            for result in results.values():
                self.assertTrue(result["under_small_attachment_limit"])
            for key, root_name in (("source", "MOKSHA-Source"), ("source_and_history", "MOKSHA-Source-and-History")):
                package.verify_source_members(Path(results[key]["path"]), root_name, hashes)
                self.assertEqual(results[key]["all_source_files_verified"], len(hashes))
            with zipfile.ZipFile(results["source"]["path"]) as zipped:
                self.assertFalse(any(name.endswith(".bundle") for name in zipped.namelist()))
            with zipfile.ZipFile(results["history"]["path"]) as zipped:
                self.assertEqual(zipped.read("MOKSHA-History/MOKSHA-source-history.bundle"), bundle.read_bytes())
                self.assertFalse(any(name.endswith(".gd") for name in zipped.namelist()))
            with zipfile.ZipFile(results["source_and_history"]["path"]) as zipped:
                self.assertEqual(zipped.read("MOKSHA-Source-and-History/history/MOKSHA-source-history.bundle"), bundle.read_bytes())
            self.assertEqual({p.relative_to(frozen).as_posix(): package.sha(p) for p in frozen.rglob("*") if p.is_file()}, hashes)

    def test_source_omission_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "missing.zip"
            with zipfile.ZipFile(path, "w") as zipped:
                zipped.writestr("MOKSHA-Source/project.godot", "config_version=5\n")
            with self.assertRaises(RuntimeError):
                package.verify_source_members(path, "MOKSHA-Source", {"campaign/tests/missing.gd": "hash"})

    def test_full_history_restores_exact_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            repo = base / "repository"
            repo.mkdir()
            subprocess.run(["git", "init", "--quiet", str(repo)], check=True, capture_output=True)
            (repo / "project.godot").write_text("config_version=5\n")
            subprocess.run(["git", "add", "project.godot"], cwd=repo, check=True, capture_output=True)
            subprocess.run(["git", "-c", "user.name=Packaging test", "-c", "user.email=packaging-test@example.invalid", "commit", "--quiet", "-m", "History restoration fixture"], cwd=repo, check=True, capture_output=True)
            commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
            bundle = base / "full.bundle"
            subprocess.run(["git", "bundle", "create", str(bundle), "--all"], cwd=repo, check=True, capture_output=True)
            hashes = {"project.godot": package.sha(repo / "project.godot")}
            result = package.verify_full_history(bundle, commit, hashes, base / "restored.git")
            self.assertTrue(result["self_contained_bare_clone"])
            self.assertTrue(result["git_fsck_passed"])
            self.assertEqual(result["restored_source_files_verified"], 1)
            with self.assertRaises(RuntimeError):
                package.verify_full_history(bundle, commit, {"project.godot": "wrong"}, base / "wrong.git")

    def test_player_guides_are_exact_frozen_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            frozen = base / "frozen"
            dist = base / "game"
            frozen.mkdir(); dist.mkdir()
            for name in ("README.md", "campaign/docs/LOCAL_PLAYTEST.md", "campaign/docs/NOV6_GAMEPAD.md", "campaign/docs/NOV6_CHANGES.md"):
                path = frozen / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("Exact frozen guide: " + name)
            included = package.copy_player_guides(frozen, dist)
            self.assertEqual(len(included), 4)
            for name, digest in included.items():
                self.assertEqual(package.sha(dist / name), digest)
            self.assertEqual((dist / "docs/NOV6_GAMEPAD.md").read_bytes(), (frozen / "campaign/docs/NOV6_GAMEPAD.md").read_bytes())

    def test_native_wrapper_preserves_fixture_and_empty_resources(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            fixture = base / "frozen_native.gd"
            fixture.write_text("extends Node\n")
            pack = base / "game.pck"
            pack.write_bytes(b"GDPC-test")
            fixture_hash = package.sha(fixture)
            report = package.prepare_native_review(base, Path("/official/godot"), pack, fixture, fixture_hash, "provenance", "commit")
            self.assertEqual(package.sha(fixture), fixture_hash)
            self.assertFalse(any(Path(report["resource_directory"]).iterdir()))
            self.assertFalse(report["native_session_launched"])
            self.assertEqual(report["expected_ui_frames"], 31)
            wrapper = Path(report["wrapper"]).read_text()
            self.assertIn(fixture_hash, wrapper)
            self.assertIn("res://BUILD_PROVENANCE.json", wrapper)
            self.assertIn("root.add_child(fixture)", wrapper)
            self.assertNotIn("@FIXTURE", wrapper)
            self.assertIn("--main-pack", report["command"])
            self.assertIn("--capture-ui", report["command"])
            self.assertIn("--display-driver", report["command"])
            self.assertIn("x11", report["command"])
            self.assertIn("--audio-driver", report["command"])
            self.assertIn("Dummy", report["command"])
            self.assertIn("--disable-vsync", report["command"])
            self.assertNotIn("--headless", report["command"])


if __name__ == "__main__":
    unittest.main()
