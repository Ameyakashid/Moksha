"""Verify M17 protected runtime dependencies against retained v20 delivery."""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile
root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline-zip', type=Path, default=root.parent / 'moksha-backups/M17-start-20261005/MOKSHA-Two-Level-Project.zip')
archive = parser.parse_args().baseline_zip.resolve()
paths = [
 'combat_pc/player.gd', 'combat_pc/player.tscn',
 'movement/components/movement_motor.gd', 'movement/components/npc_intent.gd',
 'movement/actors/npc.tscn', 'movement/resources/npc.tres',
 'combat_pc/components/health_component.gd', 'combat_pc/components/health_component.tscn',
 'combat_pc/components/defeat_response.gd', 'combat_pc/components/defeat_response.tscn',
 'combat_pc/components/noise_relay.gd', 'combat_pc/components/noise_relay.tscn',
 'combat_pc/components/physics_contact_noise.gd', 'combat_pc/components/physics_contact_noise.tscn',
 'combat_pc/resources/contact_noise_profile.gd', 'combat_pc/resources/contact_noise_profile.tres',
 'combat_pc/fixtures/contact_noise_prop.gd', 'combat_pc/fixtures/contact_noise_prop.tscn',
 'combat_pc/components/surface_pulse.gd', 'combat_pc/components/surface_pulse.tscn',
 'combat_pc/resources/surface_pulse_default.tres',
 'scripts/sensory/noise_bus.gd', 'scripts/sensory/sonar_view.gd',
 'scripts/sensory/sonar_geometry.gd', 'scripts/sensory/sonar_canvas.gd',
 'resources/sensory/sonar_tuning.gd', 'resources/sensory/sonar_default.tres',
 'prop.gd', 'scenes/props/crate.tscn', 'resources/tuning/prop_tuning.gd',
]
with ZipFile(archive) as baseline:
 for name in baseline.namelist():
  path = name.removeprefix('MOKSHA/')
  if ('enemy' in path or 'guard' in path) and path.endswith(('.gd','.tscn','.tres')) and '/tests/' not in path:
   if path not in paths: paths.append(path)
 records = []
 for path in paths:
  old = hashlib.sha256(baseline.read('MOKSHA/'+path)).hexdigest()
  current = hashlib.sha256((root/path).read_bytes()).hexdigest()
  records.append({'path':path,'baseline_sha256':old,'current_sha256':current,'match':old == current})
report = {'milestone':17,'baseline':str(archive),'files':records,'all_match':all(row['match'] for row in records)}
(root/'combat_pc/tests/npc_footstep_baseline_hashes.json').write_text(json.dumps(report,indent=2)+'\n')
print(f"NPC_FOOTSTEP_BASELINE: {sum(row['match'] for row in records)}/{len(records)} exact SHA-256 matches")
raise SystemExit(0 if report['all_match'] else 1)
