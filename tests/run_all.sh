#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="${MOKSHA_TEST_DATA_HOME:-/tmp/moksha-data}"
export XDG_CONFIG_HOME="${MOKSHA_TEST_CONFIG_HOME:-/tmp/moksha-config}"
export XDG_CACHE_HOME="${MOKSHA_TEST_CACHE_HOME:-/tmp/moksha-cache}"
export GODOT_BIN="${GODOT_BIN:-godot}"
python3 - "$@" <<'PY'
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import subprocess
import sys
import time

project = Path.cwd()
godot = os.environ["GODOT_BIN"]
base = [godot, "--headless", "--path", str(project)]
stages = [
    ("import", base + ["--editor", "--import", "--quit"]),
    ("main_boot", base + ["--fixed-fps", "120", "--quit-after", "120"]),
    ("movement_motor", base + ["--fixed-fps", "120", "--script", "res://movement/tests/motor_regression.gd"]),
    ("movement_lab", base + ["--fixed-fps", "120", "--script", "res://movement/tests/lab_contracts.gd"]),
    ("movement_npc", base + ["--fixed-fps", "120", "--script", "res://movement/tests/npc_regression.gd"]),
    ("archive_boot", base + ["res://main.tscn", "--fixed-fps", "120", "--quit-after", "120"]),
    ("actors_compile", base + ["--script", "res://tests/actors_compile.gd"]),
    ("actors_regression", base + ["--fixed-fps", "120", "--script", "res://tests/actors_regression.gd"]),
    ("sonar_regression", base + ["--fixed-fps", "120", "--script", "res://tests/sonar_regression.gd"]),
    ("levels_validate", base + ["--fixed-fps", "120", "--script", "res://tests/levels_validate.gd"]),
    ("levels_props_settle", base + ["--fixed-fps", "120", "--script", "res://tests/levels_props_settle.gd"]),
    ("flow_scene_contracts", base + ["--fixed-fps", "120", "--script", "res://tests/flow_scene_contracts.gd"]),
    ("flow_regression", base + ["--fixed-fps", "120", "--script", "res://tests/flow_regression.gd"]),
    ("polish_sensory", base + ["--fixed-fps", "120", "--script", "res://tests/polish_sensory_regression.gd"]),
    ("polish_route", base + ["--fixed-fps", "120", "--script", "res://tests/polish_route_regression.gd"]),
    ("graphics_regression", base + ["--fixed-fps", "120", "--script", "res://tests/graphics_regression.gd"]),
    ("attack_pose_regression", base + ["--fixed-fps", "120", "--script", "res://tests/attack_pose_regression.gd"]),
    ("blind_feedback_regression", base + ["--fixed-fps", "120", "--script", "res://tests/blind_feedback_regression.gd"]),
]
if all((project.parent / name).is_dir() for name in ("emberwake", "moksha-assets")) or "--require-preservation" in sys.argv:
    stages.append(("flow_preservation", [sys.executable, "tests/flow_preservation.py"]))
results = []
for name, command in stages:
    started = time.monotonic()
    try:
        process = subprocess.run(command, cwd=project, capture_output=True, text=True,
                                 timeout=180 if name == "import" else 120)
        output = process.stdout + process.stderr
        exit_code = process.returncode
    except subprocess.TimeoutExpired as error:
        output = f"TIMEOUT: {name} exceeded its maximum runtime\n" + str(error.stdout or "") + str(error.stderr or "")
        exit_code = 124
    except OSError as error:
        output, exit_code = str(error), 127
    log = project / "tests" / f"flow_all_{name}.log"
    log.write_text(output)
    diagnostics = [line for line in output.splitlines()
                   if re.match(r"^(?:SCRIPT ERROR:|ERROR:|FAIL\b|TIMEOUT:)", line)]
    passed = exit_code == 0 and not diagnostics
    result = {"stage": name, "status": "passed" if passed else "failed", "exit_code": exit_code,
              "seconds": round(time.monotonic() - started, 3), "log": str(log.relative_to(project)),
              "diagnostics": diagnostics}
    summaries = [line for line in output.splitlines()
                 if line.startswith(("ACTOR REGRESSION:", "FLOW RESULT", "SCENE RESULT", "LEVEL VALIDATION", "PLACED PROP SETTLING:"))]
    if summaries:
        result["summary"] = summaries[-1]
    if name == "sonar_regression" and (project / "tests/sonar_report.json").is_file():
        sonar = json.loads((project / "tests/sonar_report.json").read_text())
        result["checks"] = sonar["checks"] if isinstance(sonar["checks"], int) else len(sonar["checks"])
    results.append(result)
    print("PASS" if passed else "FAIL", name, result.get("summary", ""), flush=True)
    if diagnostics:
        print("\n".join(diagnostics[:10]), flush=True)
    elif not passed:
        print(output[-2000:], flush=True)
if not any(result["stage"] == "flow_preservation" for result in results):
    results.append({"stage": "flow_preservation", "status": "not_run",
                    "reason": "Original sibling projects are not present. Use --require-preservation when available."})
    print("NOT RUN preservation: original sibling projects are not present", flush=True)
hashes = {}
for path in sorted(project.rglob("*")):
    relative = path.relative_to(project)
    if ".godot" in relative.parts or "tests" in relative.parts or not path.is_file():
        continue
    if path.suffix in {".gd", ".tscn", ".tres", ".gdshader"} or path.name == "project.godot":
        hashes[str(relative)] = hashlib.sha256(path.read_bytes()).hexdigest()
report = {"completed_at_utc": datetime.now(timezone.utc).isoformat(),
          "scope": "Headless engine, physical-body, focused input flow, saved-scene and preservation tests. Native visual review is separate.",
          "passed": not any(result["status"] == "failed" for result in results),
          "all_stages_run": all(result["status"] != "not_run" for result in results),
          "stages": results, "tested_source_sha256": hashes}
(project / "tests/flow_all_report.json").write_text(json.dumps(report, indent=2) + "\n")
print(f'{sum(result["status"] == "passed" for result in results)}/{len(results)} stages passed; tests/flow_all_report.json', flush=True)
sys.exit(0 if report["passed"] else 1)
PY
