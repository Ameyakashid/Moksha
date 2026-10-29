"""Verify protected M16 dependencies against retained v19 delivery."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline-zip', type=Path, default=root.parent / 'moksha-backups/M16-start-20261005/MOKSHA-Two-Level-Project.zip')
archive = parser.parse_args().baseline_zip.expanduser().resolve()
paths = [
    'combat_pc/player.gd', 'combat_pc/player.tscn', 'movement/components/movement_motor.gd',
    'combat_pc/components/health_component.gd', 'combat_pc/components/health_component.tscn',
    'combat_pc/components/defeat_response.gd', 'combat_pc/components/defeat_response.tscn',
    'combat_pc/components/noise_relay.gd', 'combat_pc/components/noise_relay.tscn',
    'combat_pc/components/surface_pulse.gd', 'combat_pc/components/surface_pulse.tscn',
    'combat_pc/resources/surface_pulse_default.tres',
    'scripts/sensory/noise_bus.gd', 'scripts/sensory/sonar_view.gd',
    'scripts/sensory/sonar_geometry.gd', 'scripts/sensory/sonar_canvas.gd',
    'resources/sensory/sonar_tuning.gd', 'resources/sensory/sonar_default.tres',
    'prop.gd', 'scenes/props/crate.tscn', 'resources/tuning/prop_tuning.gd',
]
try:
    with zipfile.ZipFile(archive) as baseline:
        records = []
        for path in paths:
            old = hashlib.sha256(baseline.read('MOKSHA/' + path)).hexdigest()
            current = hashlib.sha256((root / path).read_bytes()).hexdigest()
            records.append({'path':path,'baseline_sha256':old,'current_sha256':current,'match':old == current})
except (OSError, zipfile.BadZipFile, KeyError) as error:
    parser.error(f'Baseline unavailable: {error}. Supply retained v19 archive. No successful comparison claimed.')
report = {'milestone':16,'baseline':str(archive),'files':records,'all_match':all(row['match'] for row in records)}
(root / 'combat_pc/tests/contact_noise_baseline_hashes.json').write_text(json.dumps(report, indent=2) + '\n')
print(f"CONTACT_NOISE_BASELINE: {sum(row['match'] for row in records)}/{len(records)} exact SHA-256 matches")
raise SystemExit(0 if report['all_match'] else 1)
