#!/usr/bin/env python3
"""Offline source-piece tests. No PowerShell or Windows helper is executed."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("source_split", Path(__file__).with_name("package_nov6_source_split.py"))
split = importlib.util.module_from_spec(spec)
spec.loader.exec_module(split)
ORIGINAL_WINDOWS_SPLITTER_SHA256 = "65abf212144caaf0c60b1a526b02af866b643aac2c0ba1a09033e4a5de5594f6"


def source_zip(path, kind="editable-source", payload=None, extra=None, mutate=None):
    root, _, variant = split.ROLES[kind]
    files = {"project.godot": b"config_version=5\n", "campaign/logic/campaign.gd": b"extends Node\n",
             "campaign/tests/fixture.gd": b"extends SceneTree\n", "campaign/docs/guide.md": b"All docs remain.\n",
             "campaign/evidence/receipt.json": b'{"passed":true}', "assets/data.bin": payload or os.urandom(16000)}
    bundle = b"# v2 git bundle\nFull history fixture bytes.\n"
    manifest = {"variant": variant, "source_commit": "a" * 40, "runtime_commit": "b" * 40,
                "pck_sha256": "c" * 64, "runtime_matches_freeze": True,
                "all_source_tests_and_docs_preserved": True,
                "history_bundle_bytes": len(bundle), "history_bundle_sha256": hashlib.sha256(bundle).hexdigest(),
                "source_sha256": {n: hashlib.sha256(data).hexdigest() for n, data in files.items()}}
    if kind == "source-and-history":
        manifest["history_embedded_path"] = "history/MOKSHA-source-history.bundle"
    if mutate:
        mutate(manifest)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as archive:
        for name, data in files.items():
            archive.writestr(root + "/" + name, data)
        archive.writestr(root + "/DELIVERY_SOURCE_MANIFEST.json", json.dumps(manifest))
        archive.writestr(root + "/START_HERE_SOURCE.txt", "Source project, not a playable Windows build.\n")
        if kind == "source-and-history":
            archive.writestr(root + "/history/MOKSHA-source-history.bundle", bundle)
        if extra:
            archive.writestr(*extra)
    return files


def extract_generated_parts(report, directory):
    directory.mkdir(exist_ok=True)
    for row in report["part_zips"]:
        with zipfile.ZipFile(row["path"]) as archive:
            # All names are generated and flat; do not extract arbitrary inputs.
            for name in archive.namelist():
                assert Path(name).name == name
                path = directory / name
                if path.exists():
                    assert path.read_bytes() == archive.read(name)
                else:
                    path.write_bytes(archive.read(name))


class SourceSplitTests(unittest.TestCase):
    def test_original_windows_splitter_is_byte_for_byte_preserved(self):
        self.assertEqual(split.sha(Path(__file__).with_name("package_nov6_split.py")), ORIGINAL_WINDOWS_SPLITTER_SHA256)

    def test_both_source_roles_round_trip_every_byte_and_member(self):
        for kind in split.ROLES:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary); source = base / "complete.zip"; files = source_zip(source, kind)
                report = split.make_parts(source, base / "parts", kind, 4096)
                self.assertTrue(report["reassembly_verified"]); self.assertFalse(report["windows_helper_executed"])
                self.assertGreater(len(report["parts"]), 1)
                extract_generated_parts(report, base / "pieces")
                result = split.reassemble_parts(report, base / "pieces", base / "recovered.zip")
                self.assertEqual((base / "recovered.zip").read_bytes(), source.read_bytes())
                self.assertEqual(result["source_files_verified"], len(files))
                self.assertEqual(result["history_embedded"], kind == "source-and-history")
                with zipfile.ZipFile(base / "recovered.zip") as archive:
                    for name, data in files.items():self.assertEqual(archive.read(report["root"] + "/" + name), data)

    def test_missing_and_wrong_pieces_fail_before_output_creation(self):
        for failure in ("missing", "wrong-bytes", "truncated"):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary); source = base / "complete.zip"; source_zip(source)
                report = split.make_parts(source, base / "parts", "editable-source", 4096)
                extract_generated_parts(report, base / "pieces"); piece = base / "pieces" / report["parts"][1]["piece"]
                if failure == "missing":piece.unlink()
                elif failure == "wrong-bytes":piece.write_bytes(b"x" * piece.stat().st_size)
                else:piece.write_bytes(piece.read_bytes()[:-1])
                with self.assertRaises(RuntimeError):split.reassemble_parts(report, base / "pieces", base / "recovered.zip")
                self.assertFalse((base / "recovered.zip").exists())

    def test_wrong_archive_role_is_rejected_before_output_creation(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary); source = base / "source.zip"; source_zip(source)
            with self.assertRaises(RuntimeError):split.make_parts(source, base / "parts", "source-and-history")
            with zipfile.ZipFile(base / "windows.zip", "w") as z:
                z.writestr("MOKSHA-Windows/MOKSHA.exe", b"MZ");z.writestr("MOKSHA-Windows/MOKSHA.pck", b"GDPC")
            with self.assertRaises(RuntimeError):split.make_parts(base / "windows.zip", base / "parts", "editable-source")
            with zipfile.ZipFile(base / "history.zip", "w") as z:z.writestr("MOKSHA-History/MOKSHA-source-history.bundle", b"bundle")
            with self.assertRaises(RuntimeError):split.make_parts(base / "history.zip", base / "parts", "source-and-history")
            self.assertFalse((base / "parts").exists())

    def test_role_manifest_member_and_bundle_tampering_rejected(self):
        mutations = [lambda m:m.update(variant="wrong role"), lambda m:m.update(all_source_tests_and_docs_preserved=False),
                     lambda m:m["source_sha256"].update({"project.godot": "0" * 64}),
                     lambda m:m["source_sha256"].update({"missing.md": "0" * 64}),
                     lambda m:m.update(history_bundle_sha256="0" * 64),
                     lambda m:m.update(history_embedded_path="history/wrong.bundle")]
        for mutate in mutations:
            with tempfile.TemporaryDirectory() as temporary:
                source = Path(temporary) / "source.zip";source_zip(source, "source-and-history", mutate=mutate)
                with self.assertRaises(RuntimeError):split.validate_source_archive(source, "source-and-history")

    def test_extra_duplicate_unsafe_and_symlink_members_rejected(self):
        for name in ["MOKSHA-Source/extra.bin", "MOKSHA-Source/project.godot", "MOKSHA-Source/PROJECT.GODOT",
                     "MOKSHA-Source/assets", "../escape", "/absolute", "MOKSHA-Source/a\\b", "MOKSHA-Source/a:stream",
                     "MOKSHA-Source/CON.txt", "MOKSHA-Source/file.", "MOKSHA-Source/file "]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                source=Path(temporary)/"source.zip";source_zip(source,extra=(name,b"unexpected"))
                with self.assertRaises(RuntimeError):split.validate_source_archive(source,"editable-source")
        with tempfile.TemporaryDirectory() as temporary:
            source=Path(temporary)/"source.zip";info=zipfile.ZipInfo("MOKSHA-Source/link");info.create_system=3;info.external_attr=0o120777 << 16
            source_zip(source,extra=(info,b"../outside"))
            with self.assertRaises(RuntimeError):split.validate_source_archive(source,"editable-source")

    def test_existing_output_and_recovered_zip_are_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            base=Path(temporary);source=base/"source.zip";source_zip(source);report=split.make_parts(source,base/"parts","editable-source",4096)
            before={p.name:split.sha(p) for p in (base/"parts").iterdir()}
            with self.assertRaises(RuntimeError):split.make_parts(source,base/"parts","editable-source")
            self.assertEqual(before,{p.name:split.sha(p) for p in (base/"parts").iterdir()})
            extract_generated_parts(report,base/"pieces");recovered=base/"existing.zip";recovered.write_bytes(b"keep me")
            with self.assertRaises(RuntimeError):split.reassemble_parts(report,base/"pieces",recovered)
            self.assertEqual(recovered.read_bytes(),b"keep me")
            (base/"dangling").symlink_to(base/"missing")
            with self.assertRaises(RuntimeError):split.make_parts(source,base/"dangling","editable-source")
            self.assertFalse((base/"missing").exists())

    def test_part_names_are_role_and_digest_specific_without_windows_collisions(self):
        with tempfile.TemporaryDirectory() as temporary:
            base=Path(temporary);reports=[]
            for kind in split.ROLES:
                source=base/(kind+".zip");source_zip(source,kind);r=split.make_parts(source,base/kind,kind,4096);reports.append(r);extract_generated_parts(r,base/"shared-pieces")
            self.assertNotEqual(reports[0]["helper_name"],reports[1]["helper_name"])
            self.assertNotEqual(reports[0]["readme_name"],reports[1]["readme_name"])
            for r in reports:
                self.assertNotEqual(r["helper_name"],"Assemble-MOKSHA.cmd");self.assertNotEqual(r["readme_name"],"START_HERE.txt")
                split.reassemble_parts(r,base/"shared-pieces",base/(r["kind"]+"-restored.zip"))

    def test_generated_helper_has_preflight_hashes_no_policy_or_download_steps(self):
        with tempfile.TemporaryDirectory() as temporary:
            base=Path(temporary);source=base/"source.zip";source_zip(source);r=split.make_parts(source,base/"parts","editable-source",4096)
            with zipfile.ZipFile(r["part_zips"][0]["path"]) as z:
                helper=z.read(r["helper_name"]).decode();readme=z.read(r["readme_name"]).decode()
            for text in ["Get-FileHash", "SHA256", "CreateNew", "New-Item -ItemType Directory", r["complete_sha256"]]:self.assertIn(text,helper)
            self.assertLess(helper.index("Wrong piece"),helper.index("CreateNew"))
            self.assertLess(helper.index("Complete ZIP checksum mismatch"),helper.index("Expand-Archive"))
            for text in ["ExecutionPolicy", "Invoke-WebRequest", "Download", "RunAs", "-Force", "Remove-Item"]:self.assertNotIn(text,helper)
            self.assertIn("not the portable Windows game",readme);self.assertIn("not tested here",readme)

    def test_part_manifest_tampering_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            base=Path(temporary);source=base/"source.zip";source_zip(source);r=split.make_parts(source,base/"parts","editable-source",4096)
            for field,value in [("piece","../outside"),("piece_bytes",True),("piece_bytes",split.PART_BYTES+1),("piece_sha256","bad")]:
                bad=copy.deepcopy(r);bad["parts"][0][field]=value
                with self.subTest(field=field,value=value),self.assertRaises(RuntimeError):split.validate_part_manifest(bad)
            with self.assertRaises(RuntimeError):split.assembly_helper(r,"unsafe';shell")

    def test_invalid_and_maximum_piece_sizes(self):
        with tempfile.TemporaryDirectory() as temporary:
            base=Path(temporary);source=base/"source.zip";source_zip(source,payload=b"A"*(split.PART_BYTES+1000))
            for size in [0,-1,True,1.5,split.PART_BYTES+1]:
                with self.subTest(size=size),self.assertRaises(RuntimeError):split.make_parts(source,base/"invalid","editable-source",size)
            r=split.make_parts(source,base/"maximum","editable-source",split.PART_BYTES)
            self.assertEqual(r["parts"][0]["piece_bytes"],split.PART_BYTES)
            self.assertEqual(len(r["parts"]),2)
            self.assertTrue(all(p["bytes"] < split.DELIVERY_LIMIT for p in r["part_zips"]))
            extract_generated_parts(r,base/"pieces");split.reassemble_parts(r,base/"pieces",base/"restored.zip")


if __name__ == "__main__":
    unittest.main()
