#!/usr/bin/env python3
"""Verify pre-existing projects against the captured baseline, without importing them."""
from pathlib import Path
import hashlib
import json
import sys

project = Path(__file__).resolve().parents[1]
baseline = json.loads((project / "tests/preserved-projects.json").read_text())
checks = []
for name, files in baseline.items():
    directory = project.parent / name
    missing, changed = [], []
    for relative, expected in files.items():
        path = directory / relative
        if not path.is_file():
            missing.append(relative)
        elif hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            changed.append(relative)
    checks.append({"project": name, "baseline_files": len(files), "missing": missing,
                   "changed": changed, "pass": not missing and not changed})
report = {"scope": "Every captured original file SHA-256; does not treat generated caches or new files as original content", "checks": checks}
(project / "tests/flow_preservation_report.json").write_text(json.dumps(report, indent=2) + "\n")
for check in checks:
    print(("PASS" if check["pass"] else "FAIL"), check["project"],
          f'{check["baseline_files"]} preserved file hashes', check["missing"], check["changed"])
sys.exit(0 if all(check["pass"] for check in checks) else 1)
