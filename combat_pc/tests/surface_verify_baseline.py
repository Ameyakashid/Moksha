"""Hash immutable M15 dependencies against the preserved v18 delivery."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument(
    "--baseline-zip", type=Path,
    default=root.parent / "moksha-backups/M15-start-20261005/MOKSHA-Two-Level-Project.zip",
    help="Path to your retained v18 MOKSHA-Two-Level-Project.zip. Defaults to the original local M15 backup path.",
)
archive = parser.parse_args().baseline_zip.expanduser().resolve()
paths = [
    "combat_pc/player.gd", "combat_pc/player.tscn",
    "movement/components/movement_motor.gd",
    "combat_pc/components/health_component.gd",
    "combat_pc/components/health_component.tscn",
    "combat_pc/components/defeat_response.gd",
    "combat_pc/components/defeat_response.tscn",
    "combat_pc/components/noise_relay.gd",
    "combat_pc/components/noise_relay.tscn",
    "scripts/sensory/noise_bus.gd", "scripts/sensory/sonar_view.gd",
    "scripts/sensory/sonar_geometry.gd", "scripts/sensory/sonar_canvas.gd",
    "resources/sensory/sonar_tuning.gd", "resources/sensory/sonar_default.tres",
]
try:
    with zipfile.ZipFile(archive) as baseline:
        records = []
        for path in paths:
            old = hashlib.sha256(baseline.read("MOKSHA/" + path)).hexdigest()
            current = hashlib.sha256((root / path).read_bytes()).hexdigest()
            records.append({"path": path, "baseline_sha256": old, "current_sha256": current, "match": old == current})
except (OSError, zipfile.BadZipFile, KeyError) as error:
    parser.error(
        f"Baseline comparison unavailable: {error}. "
        "Supply your retained v18 archive with --baseline-zip PATH. "
        "Existing reports were not refreshed; no successful comparison is claimed."
    )
report = {"baseline": str(archive), "files": records, "all_match": all(row["match"] for row in records)}
(root / "combat_pc/tests/surface_baseline_hashes.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"SURFACE_BASELINE: {sum(row['match'] for row in records)}/{len(records)} exact SHA-256 matches")
raise SystemExit(0 if report["all_match"] else 1)
