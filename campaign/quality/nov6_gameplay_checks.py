#!/usr/bin/env python3
"""Fail-closed Nov 6 campaign gameplay regressions, isolated from player saves."""
import argparse
import json
import os
from pathlib import Path
import sys
import tempfile
import time

from run_quality import ROOT, hashes, run_stage

CASES = (
    ("input", "NOV6_GAMEPLAY_INPUT_RESULT "),
    ("objectives", "NOV6_GAMEPLAY_OBJECTIVES_RESULT "),
    ("build", "NOV6_GAMEPLAY_BUILD_RESULT "),
    ("save_feedback", "NOV6_GAMEPLAY_SAVE_FEEDBACK_RESULT "),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New evidence directory; never overwrites old receipts")
    parser.add_argument("--rates", type=int, nargs="+", default=[60, 120])
    args = parser.parse_args()
    output = (args.output or ROOT / "campaign/quality/results" / time.strftime("nov6-gameplay-%Y%m%d-%H%M%S")).resolve()
    output.mkdir(parents=True, exist_ok=False)
    godot = os.environ.get("GODOT_BIN", "godot")
    before = hashes()
    rows = []
    for rate in args.rates:
        for case, marker in CASES:
            # Each scene has its own directory. A failure fixture cannot change
            # another test's checkpoint, let alone a user's actual checkpoint.
            with tempfile.TemporaryDirectory(prefix="moksha-nov6-gameplay-") as temporary:
                env = dict(os.environ, MOKSHA_QUALITY_ISOLATED="1")
                for key in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                    path = Path(temporary) / key
                    path.mkdir()
                    env[key] = str(path)
                command = [godot, "--headless", "--path", str(ROOT), "--fixed-fps", str(rate),
                           "--script", f"res://campaign/quality/nov6_gameplay_{case}.gd", "--", f"--hz={rate}"]
                if case == "save_feedback":
                    command.append("--isolated-save-tests")
                row = run_stage(f"{case}_{rate}", command, env, output, marker, timeout=120)
                rows.append(row)
                print(json.dumps(row), flush=True)
    after = hashes()
    drift = sorted(path for path in before.keys() | after.keys() if before.get(path) != after.get(path))
    owned = {path: digest for path, digest in before.items()
             if path.startswith("campaign/logic/") or path.startswith("campaign/quality/nov6_gameplay")}
    owned_drift = [path for path in drift
                   if path.startswith("campaign/logic/") or path.startswith("campaign/quality/nov6_gameplay")]
    report = {
        "scope": "Campaign modal/focus boundaries, actual breaker contacts and live reward strikes, isolated save feedback. Not a full campaign/human playthrough or hardware acceptance.",
        "source_sha256": before,
        "owned_source_sha256": owned,
        "owned_source_drift": owned_drift,
        "checks_passed": all(row["passed"] for row in rows),
        "source_drift": drift,
        "stages": rows,
        "passed": not drift and all(row["passed"] for row in rows),
    }
    (output / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Report: {output / 'summary.json'}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
