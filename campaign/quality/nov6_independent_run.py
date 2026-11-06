#!/usr/bin/env python3
"""Run the independent Nov6 review with fresh user data and reviewed-source hashes."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
REVIEWED = [
    "campaign/logic/campaign.gd", "campaign/logic/campaign_input_gate.gd",
    "campaign/logic/objective.gd", "campaign/logic/breaker_contact.gd",
    "campaign/input/gamepad_navigation.gd", "campaign/presentation/camera_follow.gd",
    "campaign/presentation/campaign_scenery.gd", "campaign/presentation/scenery_backdrop.gd",
    "campaign/views/campaign_hud.gd", "campaign/views/campaign_hud_owner.gd",
    "campaign/views/objective_caption.gd", "campaign/views/objective_view.gd",
    "campaign/layouts/level_01.gd", "campaign/layouts/level_02.gd", "campaign/layouts/level_03.gd",
    "campaign/logic/build_health.gd", "campaign/logic/campaign_data.gd",
    "demo/mission.gd", "simulation/ui/mission_hud.gd", "combat_pc/player.gd",
    "tools/verify_nov6.py", "project.godot",
]
SCRIPTS = [
    ("nov6_independent_focus_upgrade.gd", "NOV6_INDEPENDENT_FOCUS_UPGRADE "),
    ("nov6_independent_review.gd", "NOV6_INDEPENDENT_RESULT "),
    ("nov6_independent_controller.gd", "NOV6_INDEPENDENT_CONTROLLER "),
    ("nov6_independent_hud_pipeline.gd", "NOV6_INDEPENDENT_HUD_PIPELINE "),
    ("nov6_independent_paused_release.gd", "NOV6_INDEPENDENT_PAUSED_RELEASE "),
]


def hashes():
    files = [ROOT / name for name in REVIEWED]
    files += sorted((ROOT / "campaign/quality").glob("nov6_independent*"))
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in files if p.is_file() and p.suffix not in {".json", ".md"}}


def main():
    spec = importlib.util.spec_from_file_location("nov6_runner", ROOT / "tools/verify_nov6.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = Path(tempfile.mkdtemp(prefix=f"moksha-independent-{stamp}-"))
    before = hashes()
    rows = []
    godot = os.environ.get("GODOT_BIN", "godot")
    for hz in (60, 120):
        for script, marker in SCRIPTS:
            command = [godot, "--headless", "--path", str(ROOT), "--fixed-fps", str(hz),
                       "--script", "res://campaign/quality/" + script, "--", f"--hz={hz}"]
            rows.append(runner.run_case(f"{Path(script).stem}_{hz}", command, output, marker, 120))
    rows.append(runner.run_case("caption_overlap_final", [godot, "--headless", "--path", str(ROOT),
                "--script", "res://campaign/quality/nov6_independent_caption_overlap.gd"], output, None, 90))
    rows.append(runner.run_case("runner_negative_controls", [sys.executable,
                str(ROOT / "campaign/quality/nov6_independent_runner_test.py")], output,
                "NOV6_INDEPENDENT_RUNNER ", 60))
    after = hashes()
    drift = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    version_env = dict(os.environ)
    for key in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        location = output / ("version_" + key.lower())
        location.mkdir()
        version_env[key] = str(location)
    version = subprocess.run([godot, "--headless", "--version"], env=version_env,
                             capture_output=True, text=True, check=True).stdout.strip()
    report = {
        "utc": stamp,
        "scope": "Independent Nov6 review of selected production files plus explicit menu, authored-level-completion, actual HUD-owner, and synthesized keyboard/Joypad event fixtures. Not physical controller, full campaign, native visual/audio, or human-pacing acceptance.",
        "godot_version": version,
        "reviewed_source_sha256": before,
        "reviewed_source_drift": drift,
        "stages": rows,
        "passed": not drift and all(row["passed"] for row in rows),
        "resolved_findings": [
            "Pending retry, upgrade scene load and automatic intro expiration could resume off-focus; focus guard now suspends them until explicit resume.",
            "Canceling a focus-paused level exit retained the chosen upgrade and completion receipts at the old exit; staged transition rollback now removes uncommitted upgrade, metric and receipt while successful onward load commits once.",
            "Parent native review found additive HUD fields discarded by base owner; independent host-to-owner-to-View suite validates campaign-only adapter and rejection atomicity.",
            "Multi-line floor completion notices overlapped12pixels of actor legs; revised layout has zero measured overlap with floor-body rectangle across authored floor objective notices.",
            "Runner accepted empty, negative, boolean or absent assertion counts; independent negative controls now verify their rejection.",
            "Releasing jump while paused lost the engine release edge and failed to shorten the ascent; device sampling now permits the preserved actor to infer a release from its last held state.",
        ],
        "remaining_confirmed_review_findings": [{"stage": row["name"],
            "failures": row["validation"].get("receipt", {}).get("failures", []),
            "errors": row["errors"]} for row in rows if not row["passed"]],
        "blocking_runtime_failures": [{"stage": row["name"], "errors": row["errors"],
                                        "receipt": row["validation"]} for row in rows if not row["passed"]],
    }
    destination = ROOT / "campaign/quality" / f"nov6_independent_results_{stamp}.json"
    with destination.open("x") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(f"NOV6_INDEPENDENT_REPORT {destination} passed={report['passed']} drift={drift}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
