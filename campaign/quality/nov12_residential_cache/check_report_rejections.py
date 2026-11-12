#!/usr/bin/env python3
"""Cheap subprocess checks: every invalid report target exits before gameplay."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[3]
fixture = "campaign/quality/nov12_residential_cache/route.gd"
receipts = sorted((project / Path(fixture).parent).glob("*.json"))
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
before = {str(p): digest(p) for p in receipts}
with tempfile.TemporaryDirectory(prefix="moksha-report-rejections-") as directory:
    temp = Path(directory)
    sentinel = temp / "existing.json"
    sentinel.write_bytes(b"DO NOT OVERWRITE\n")
    (temp / "source-link").symlink_to(project, target_is_directory=True)
    cases = {
        "missing": None,
        "relative": "relative.json",
        "project": str(project / "reject-report.json"),
        "res_scheme": "res://reject-report.json",
        "existing_file": str(sentinel),
        "existing_directory": str(temp),
        "symlink_into_project": str(temp / "source-link" / "reject-report.json"),
        "missing_parent": str(temp / "missing" / "report.json"),
    }
    env = os.environ.copy()
    for key, suffix in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
        path = temp / suffix
        path.mkdir()
        env[key] = str(path)
    results = []
    for name, target in cases.items():
        command = ["godot", "--headless", "--path", str(project), "--script", fixture, "--"]
        if target is not None:
            command.append("--report=" + target)
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        assert result.returncode == 2, (name, result.returncode, output)
        assert "L23 " not in output and "L23_RESULT" not in output and "CLIMB " not in output, (name, output)
        assert sentinel.read_bytes() == b"DO NOT OVERWRITE\n"
        assert not (project / "reject-report.json").exists()
        results.append({"case": name, "exit": result.returncode, "gameplay_started": False})
assert before == {str(p): digest(p) for p in receipts}
print(json.dumps({"passed": True, "checks": results, "archived_receipts_unchanged": True}, indent=2))
