#!/usr/bin/env python3
"""Optional attachment-size fallback for an already verified Windows ZIP.

Prefer delivering the original single ZIP. This tool wraps 17 MiB pieces in
ordinary ZIPs and includes a Windows reassembly helper. The helper verifies the
complete SHA-256 before extracting, never downloads anything, never changes
PowerShell policy, never overwrites an existing game folder, and only opens the
finished folder. Windows execution of the helper is not claimed by this tool.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import zipfile

PART_BYTES = 17 * 1024 * 1024
DELIVERY_LIMIT = 18 * 1024 * 1024


def sha(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def make_parts(source: Path, output: Path, part_bytes: int = PART_BYTES) -> dict:
    if output.exists():
        raise RuntimeError("Choose a new output directory; existing parts are preserved")
    if not source.is_file() or source.suffix.lower() != ".zip":
        raise RuntimeError("Input must be the verified complete Windows ZIP")
    if part_bytes <= 0 or part_bytes > PART_BYTES:
        raise RuntimeError("Pieces must be positive and no larger than 17 MiB")
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None or "MOKSHA-Windows/MOKSHA.exe" not in archive.namelist() or "MOKSHA-Windows/MOKSHA.pck" not in archive.namelist():
            raise RuntimeError("Input is not a valid MOKSHA Windows package")
    output.mkdir(parents=True)
    digest = sha(source)
    count = math.ceil(source.stat().st_size / part_bytes)
    # Fixed digest-only names keep the generated Windows command free of
    # user-supplied shell syntax, even if an input ZIP has an unusual name.
    prefix = "MOKSHA-" + digest[:12]
    names = [f"{prefix}.part{i:02d}" for i in range(1, count + 1)]
    readme = f"""MOKSHA / SMALL-ATTACHMENT DOWNLOAD

The normal single ZIP is easier when your device accepts it. These {count} ZIPs
contain that exact same game, split only to fit the attachment size limit.

1. Download all {count} Part ZIPs.
2. Extract every Part ZIP into the SAME folder. Keep all {prefix}.part files
   beside Assemble-MOKSHA.cmd. Do not rename the part files.
3. Double-click Assemble-MOKSHA.cmd. It checks the complete file before unpacking.
4. In the folder that opens, open MOKSHA-Windows and double-click MOKSHA.exe.

The helper makes no downloads and does not alter system or security settings.
If the helper is blocked by your computer's policy, do not weaken the policy.
Ask for the original single ZIP or use a trusted file-join tool, verify the hash
below, and extract it with your usual ZIP tool.

Complete ZIP bytes: {source.stat().st_size}
Complete ZIP SHA-256: {digest}
Windows execution of this helper and game has not been tested here.
"""
    commands = [
        "$ErrorActionPreference='Stop'",
        "$base=$env:MOKSHA_PART_DIR",
        "$names=@(" + ",".join("'" + name + "'" for name in names) + ")",
        f"$zip=Join-Path $base '{prefix}-Complete.zip'",
        f"$dest=Join-Path $base '{prefix}-Ready'",
        "if(Test-Path -LiteralPath $dest){throw 'The completed game folder already exists. Open it, or assemble in a new folder.'}",
        "foreach($name in $names){if(!(Test-Path -LiteralPath (Join-Path $base $name))){throw ('Missing '+$name+'. Extract every Part ZIP into this same folder.')}}",
        "$out=[IO.File]::Open($zip,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)",
        "try{foreach($name in $names){$partStream=[IO.File]::OpenRead((Join-Path $base $name));try{$partStream.CopyTo($out)}finally{$partStream.Dispose()}}}finally{$out.Dispose()}",
        f"if((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() -ne '{digest}'){{throw 'Checksum mismatch. Keep the parts and download them again before retrying in a new folder.'}}",
        "Expand-Archive -LiteralPath $zip -DestinationPath $dest",
        "Write-Host 'Verified and extracted. Open MOKSHA-Windows and start MOKSHA.exe.'",
        "Invoke-Item -LiteralPath $dest",
    ]
    helper = ('@echo off\r\nsetlocal\r\nset "MOKSHA_PART_DIR=%~dp0"\r\n'
              'powershell.exe -NoLogo -NoProfile -Command "' + ";".join(commands) + '"\r\n'
              'if errorlevel 1 (\r\n  echo Assembly stopped. Read the error above. Your existing files have been kept.\r\n  pause\r\n  exit /b 1\r\n)\r\npause\r\n')
    parts = []
    with source.open("rb") as stream:
        for index, name in enumerate(names):
            data = stream.read(part_bytes)
            path = output / f"{prefix}-Part{index+1}-of{count}.zip"
            with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as archive:
                archive.writestr(name, data)
                archive.writestr("START_HERE.txt", readme)
                if index == 0:
                    archive.writestr("Assemble-MOKSHA.cmd", helper)
            if path.stat().st_size >= DELIVERY_LIMIT:
                raise RuntimeError("Part exceeds attachment budget")
            parts.append({"path": str(path), "bytes": path.stat().st_size, "sha256": sha(path),
                          "piece": name, "piece_bytes": len(data), "piece_sha256": hashlib.sha256(data).hexdigest()})
    reconstructed = hashlib.sha256()
    total = 0
    for part in parts:
        with zipfile.ZipFile(part["path"]) as archive:
            if archive.testzip() is not None:
                raise RuntimeError("Part ZIP CRC failed")
            data = archive.read(part["piece"])
            total += len(data)
            reconstructed.update(data)
    if total != source.stat().st_size or reconstructed.hexdigest() != digest:
        raise RuntimeError("Reassembled ZIP differs from original")
    report = {"complete_zip": str(source), "complete_sha256": digest, "complete_bytes": total,
              "parts": parts, "reassembly_verified": True, "windows_helper_executed": False}
    (output / "PARTS_REPORT.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("windows_zip", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(json.dumps(make_parts(args.windows_zip.resolve(), args.output.resolve()), indent=2))


if __name__ == "__main__":
    main()
