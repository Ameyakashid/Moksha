#!/usr/bin/env python3
"""Optional source attachment fallback; the existing Windows splitter is unchanged.

Use only if the complete editable-source or combined source/history ZIP needs
smaller attachments. This tool never uploads, downloads, installs, or runs a game.
The Windows assembly helper is generated, not executed or Windows-tested here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile

PART_BYTES = 17 * 1024 * 1024
DELIVERY_LIMIT = 18 * 1024 * 1024
ROLES = {
    "editable-source": ("MOKSHA-Source", "Editable-Source", "complete editable source; full Git history is a separate companion"),
    "source-and-history": ("MOKSHA-Source-and-History", "Source-and-History", "canonical complete editable source plus embedded full Git history"),
}
WINDOWS_RESERVED = {"con", "prn", "aux", "nul"} | {f"{kind}{i}" for kind in ("com", "lpt") for i in range(1, 10)}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def safe_relative(name: str) -> bool:
    if not isinstance(name, str) or not name or "\\" in name or ":" in name or any(ord(c) < 32 for c in name):
        return False
    path = PurePosixPath(name)
    return (bool(path.parts) and not path.is_absolute() and str(path) == name
            and all(p not in {".", ".."} and not p.endswith((" ", "."))
                    and p.split(".")[0].casefold() not in WINDOWS_RESERVED for p in path.parts))


def digest_string(value: object, length: int = 64) -> bool:
    return isinstance(value, str) and re.fullmatch("[0-9a-f]{" + str(length) + "}", value) is not None


def validate_source_archive(source: Path, kind: str) -> dict:
    require(isinstance(kind, str) and kind in ROLES, "Choose editable-source or source-and-history")
    require(source.is_file() and source.suffix.lower() == ".zip", "Input must be a complete source ZIP")
    root, _, variant = ROLES[kind]
    with zipfile.ZipFile(source) as archive:
        infos = archive.infolist()
        names = [i.filename for i in infos]
        require(len(names) == len(set(names)), "Duplicate archive members")
        folded_names = {name.casefold() for name in names}
        require(len(names) == len(folded_names), "Case-insensitive archive member collision")
        require(not any(str(parent).casefold() in folded_names for name in names for parent in PurePosixPath(name).parents),
                "Archive file/directory member collision")
        for info in infos:
            mode = stat.S_IFMT(info.external_attr >> 16)
            require(safe_relative(info.filename) and not info.is_dir() and not info.external_attr & 0x10 and mode in (0, stat.S_IFREG),
                    "Unsafe or non-file archive member: " + info.filename)
            require(not info.flag_bits & 1, "Encrypted archives are not supported")
            require(info.filename.startswith(root + "/"), "Archive root does not match the requested source role")
        manifest_name = root + "/DELIVERY_SOURCE_MANIFEST.json"
        require(manifest_name in names, "Missing source-delivery manifest")
        manifest = json.loads(archive.read(manifest_name))
        require(isinstance(manifest, dict) and manifest.get("variant") == variant, "Wrong source archive role")
        require(manifest.get("all_source_tests_and_docs_preserved") is True and manifest.get("runtime_matches_freeze") is True,
                "Manifest does not describe a complete frozen source delivery")
        for field in ("source_commit", "runtime_commit"):
            require(digest_string(manifest.get(field), 40), "Invalid frozen commit identity")
        for field in ("pck_sha256", "history_bundle_sha256"):
            require(digest_string(manifest.get(field)), "Invalid manifest digest: " + field)
        require(type(manifest.get("history_bundle_bytes")) is int and manifest["history_bundle_bytes"] > 0,
                "Invalid history bundle length")
        source_hashes = manifest.get("source_sha256")
        require(isinstance(source_hashes, dict) and {"project.godot", "campaign/logic/campaign.gd"} <= source_hashes.keys(),
                "Manifest is missing the editable campaign source")
        expected = {manifest_name, root + "/START_HERE_SOURCE.txt"}
        for relative, digest in source_hashes.items():
            require(safe_relative(relative) and digest_string(digest), "Invalid source member identity")
            require(relative not in ("DELIVERY_SOURCE_MANIFEST.json", "START_HERE_SOURCE.txt"), "Reserved source member")
            expected.add(root + "/" + relative)
        history = "history/MOKSHA-source-history.bundle"
        if kind == "source-and-history":
            require(manifest.get("history_embedded_path") == history and history not in source_hashes, "Wrong embedded history member")
            expected.add(root + "/" + history)
        else:
            require("history_embedded_path" not in manifest, "Editable-only archive claims embedded history")
        require(set(names) == expected, "Archive has missing or extra members outside its declared source role")
        require(archive.testzip() is None, "Source archive CRC failure")
        for relative, digest in source_hashes.items():
            with archive.open(root + "/" + relative) as stream:
                require(hashlib.file_digest(stream, "sha256").hexdigest() == digest, "Source member hash mismatch: " + relative)
        if kind == "source-and-history":
            require(archive.getinfo(root + "/" + history).file_size == manifest["history_bundle_bytes"], "History bundle size mismatch")
            with archive.open(root + "/" + history) as stream:
                require(hashlib.file_digest(stream, "sha256").hexdigest() == manifest["history_bundle_sha256"], "History bundle hash mismatch")
    return {"kind": kind, "root": root, "source_commit": manifest["source_commit"],
            "source_files_verified": len(source_hashes), "history_embedded": kind == "source-and-history",
            "complete_bytes": source.stat().st_size, "complete_sha256": sha(source)}


def validate_part_manifest(report: dict) -> None:
    kind = report.get("kind")
    require(isinstance(kind, str) and kind in ROLES and report.get("root") == ROLES[kind][0], "Invalid part-set role")
    require(digest_string(report.get("complete_sha256")), "Invalid complete ZIP hash")
    require(type(report.get("complete_bytes")) is int and report["complete_bytes"] > 0, "Invalid complete ZIP size")
    prefix = "MOKSHA-" + ROLES[kind][1] + "-" + report["complete_sha256"][:12]
    parts = report.get("parts")
    require(isinstance(parts, list) and bool(parts), "Missing part records")
    for index, part in enumerate(parts, 1):
        require(isinstance(part, dict), "Invalid piece record")
        require(part.get("piece") == f"{prefix}.part{index:03d}", "Wrong piece name or order")
        require(type(part.get("piece_bytes")) is int and 0 < part["piece_bytes"] <= PART_BYTES, "Invalid piece size")
        require(digest_string(part.get("piece_sha256")), "Invalid piece hash")
    require(sum(p["piece_bytes"] for p in parts) == report["complete_bytes"], "Piece lengths do not match complete ZIP")


def reassemble_parts(report: dict, pieces: Path, recovered_zip: Path) -> dict:
    """Offline Python verifier for extracted pieces. Never overwrites or extracts."""
    validate_part_manifest(report)
    require(not os.path.lexists(recovered_zip), "Recovered ZIP already exists")
    require(recovered_zip.parent.is_dir(), "Recovered ZIP parent must exist")
    require(recovered_zip.suffix.lower() == ".zip", "Recovered file must have a .zip extension")
    for part in report["parts"]:
        path = pieces / part["piece"]
        require(path.is_file() and not path.is_symlink(), "Missing or non-regular piece: " + part["piece"])
        require(path.stat().st_size == part["piece_bytes"] and sha(path) == part["piece_sha256"], "Wrong piece: " + part["piece"])
    with recovered_zip.open("xb") as stream:
        for part in report["parts"]:
            with (pieces / part["piece"]).open("rb") as incoming:
                for block in iter(lambda: incoming.read(1024 * 1024), b""):
                    stream.write(block)
    require(recovered_zip.stat().st_size == report["complete_bytes"] and sha(recovered_zip) == report["complete_sha256"],
            "Reconstructed ZIP hash/size mismatch; output is preserved for inspection")
    return validate_source_archive(recovered_zip, report["kind"])


def assembly_helper(report: dict, prefix: str) -> str:
    # All command values are validated fixed-format strings or integers, never
    # interpolated user-supplied filenames, source paths, or shell expressions.
    validate_part_manifest(report)
    require(prefix == "MOKSHA-" + ROLES[report["kind"]][1] + "-" + report["complete_sha256"][:12], "Invalid assembly prefix")
    rows = ",".join("@{Name='" + p["piece"] + "';Size=" + str(p["piece_bytes"]) + ";Hash='" + p["piece_sha256"] + "'}" for p in report["parts"])
    commands = ["$ErrorActionPreference='Stop'", "$base=$env:MOKSHA_SOURCE_PART_DIR", "$parts=@(" + rows + ")",
                f"$zip=Join-Path $base '{prefix}-Complete.zip'", f"$dest=Join-Path $base '{prefix}-Ready'",
                "if((Test-Path -LiteralPath $zip) -or (Test-Path -LiteralPath $dest)){throw 'Output already exists. Keep it and assemble in a new folder.'}",
                "foreach($p in $parts){$f=Join-Path $base $p.Name;if(!(Test-Path -LiteralPath $f -PathType Leaf)){throw ('Missing '+$p.Name)};if((Get-Item -LiteralPath $f).Length -ne $p.Size -or (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower() -ne $p.Hash){throw ('Wrong piece '+$p.Name)}}",
                "$out=[IO.File]::Open($zip,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)",
                "try{foreach($p in $parts){$s=[IO.File]::OpenRead((Join-Path $base $p.Name));try{$s.CopyTo($out)}finally{$s.Dispose()}}}finally{$out.Dispose()}",
                f"if((Get-Item -LiteralPath $zip).Length -ne {report['complete_bytes']} -or (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() -ne '{report['complete_sha256']}'){{throw 'Complete ZIP checksum mismatch. Keep the files and retry in a new folder.'}}",
                "New-Item -ItemType Directory -Path $dest -ErrorAction Stop | Out-Null",
                "Expand-Archive -LiteralPath $zip -DestinationPath $dest",
                "Write-Host 'Source ZIP verified and extracted. Open project.godot in Godot 4.6.3 to edit.'", "Invoke-Item -LiteralPath $dest"]
    require(len(";".join(commands)) < 7500, "Too many small pieces for the Windows command-line budget; use larger pieces")
    return ('@echo off\r\nsetlocal\r\nset "MOKSHA_SOURCE_PART_DIR=%~dp0"\r\n'
            'powershell.exe -NoLogo -NoProfile -Command "' + ";".join(commands) + '"\r\n'
            'if errorlevel 1 (\r\n  echo Assembly stopped. Existing files were preserved.\r\n  pause\r\n  exit /b 1\r\n)\r\npause\r\n')


def make_parts(source: Path, output: Path, kind: str, part_bytes: int = PART_BYTES) -> dict:
    require(not os.path.lexists(output), "Choose a new output directory; existing files are preserved")
    require(type(part_bytes) is int and 0 < part_bytes <= PART_BYTES, "Pieces must be positive integers no larger than 17 MiB")
    report = validate_source_archive(source, kind)
    prefix = "MOKSHA-" + ROLES[kind][1] + "-" + report["complete_sha256"][:12]
    parts = []
    with source.open("rb") as stream:
        while data := stream.read(part_bytes):
            parts.append({"piece": f"{prefix}.part{len(parts)+1:03d}", "piece_bytes": len(data),
                          "piece_sha256": hashlib.sha256(data).hexdigest()})
    report["parts"] = parts
    validate_part_manifest(report)
    helper_name = "Assemble-" + prefix + ".cmd"
    readme_name = "README-" + prefix + ".txt"
    manifest_name = prefix + "-Manifest.json"
    history = ("Full Git history is included under history/MOKSHA-source-history.bundle.\n" if kind == "source-and-history" else
               "Full Git history is a separate companion. This set contains complete editable source.\n")
    readme = (f"MOKSHA / {kind.upper()} / OPTIONAL SMALL-ATTACHMENT FALLBACK\n\n"
              "Prefer the complete single ZIP if your device accepts it. No source, tests, docs,\n"
              "or evidence were removed. These pieces reconstruct that exact ZIP.\n\n"
              f"1. Download all {len(parts)} Part ZIPs and extract them into the SAME folder.\n"
              f"2. Keep all {prefix}.part files beside {helper_name}.\n"
              f"3. Run {helper_name}. It checks every piece and the complete SHA-256 before extraction.\n"
              f"4. Open {ROLES[kind][0]}/project.godot inside the resulting Ready folder in Godot 4.6.3.\n\n"
              "This is editable source, not the portable Windows game. No engine is bundled.\n" + history +
              "The helper makes no downloads, needs no admin access, and changes no security policy.\n"
              "If blocked by your computer's policy, do not weaken it. Use the complete ZIP or a\n"
              "trusted file-join tool and verify the complete checksum below. Existing output is\n"
              "never overwritten; retry in a new folder. Windows execution of this helper was\n"
              "not tested here. Python reconstruction and source-member hashes were verified.\n\n"
              f"Complete ZIP bytes: {report['complete_bytes']}\nComplete SHA-256: {report['complete_sha256']}\n")
    helper = assembly_helper(report, prefix)
    output.mkdir(parents=True)
    wrappers = []
    with source.open("rb") as stream:
        for index, part in enumerate(parts, 1):
            data = stream.read(part["piece_bytes"])
            require(hashlib.sha256(data).hexdigest() == part["piece_sha256"], "Source ZIP changed during splitting")
            path = output / f"{prefix}-Part{index}-of{len(parts)}.zip"
            with zipfile.ZipFile(path, "x", zipfile.ZIP_STORED) as archive:
                archive.writestr(part["piece"], data)
                archive.writestr(readme_name, readme)
                if index == 1:
                    archive.writestr(helper_name, helper)
                    archive.writestr(manifest_name, json.dumps(report, indent=2) + "\n")
            require(path.stat().st_size < DELIVERY_LIMIT, "Part ZIP exceeds the 18 MiB attachment budget")
            wrappers.append({"path": str(path), "bytes": path.stat().st_size, "sha256": sha(path), "piece": part["piece"]})
    reconstructed = hashlib.sha256(); total = 0
    for wrapper in wrappers:
        with zipfile.ZipFile(wrapper["path"]) as archive:
            require(archive.testzip() is None, "Part ZIP CRC failed")
            data = archive.read(wrapper["piece"]); reconstructed.update(data); total += len(data)
    require(total == report["complete_bytes"] and reconstructed.hexdigest() == report["complete_sha256"], "Piece reconstruction differs from complete ZIP")
    report.update(part_zips=wrappers, helper_name=helper_name, readme_name=readme_name, manifest_name=manifest_name,
                  reassembly_verified=True, windows_helper_executed=False)
    (output / "SOURCE_PARTS_REPORT.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_zip", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--kind", choices=ROLES, required=True)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    if args.validate_only:
        result = validate_source_archive(args.source_zip.resolve(), args.kind)
    else:
        if args.output is None:
            parser.error("output is required unless --validate-only is used")
        result = make_parts(args.source_zip.resolve(), args.output.absolute(), args.kind)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
