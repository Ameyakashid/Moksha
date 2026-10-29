"""Verify preserved v21 delivery plus scope-limited source changes; never edits it."""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BASELINE_VERSION = 21
# Pinned from the accepted M17/v21 delivery manifest, which is not required here.
EXPECTED_SHA256 = 'c93e187cdbf1a449227ae7d647ee84ead71e5d76f627a6b84ee43a91f8837d1f'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline-zip', type=Path, default=ROOT.parent / 'moksha-backups/M18-start-20261005/MOKSHA-Two-Level-Project.zip', help='Path to the retained, unmodified v21 MOKSHA-Two-Level-Project.zip')
args = parser.parse_args()
BACKUP = args.baseline_zip.expanduser().resolve()
if not BACKUP.is_file():
    parser.error('Retained v21 archive is required; provide --baseline-zip /path/to/MOKSHA-Two-Level-Project.zip')
sha = lambda content: hashlib.sha256(content).hexdigest()
actual = sha(BACKUP.read_bytes())
if actual != EXPECTED_SHA256:
    raise SystemExit(f'Archive SHA-256 does not match retained v{BASELINE_VERSION}: {actual}')
# The pass adds a guarded opt-in resource and presentation; the old base values,
# every earlier harness, components, fixtures, and remaining visuals stay intact.
allowed = {'combat_pc/player.gd', 'combat_pc/resources/movement_profile.gd', 'combat_pc/visuals/wireframe.gd', 'combat_pc/reference/generate_parameter_ledger.py'}
rows = {}
with zipfile.ZipFile(BACKUP) as archive:
    for entry in archive.namelist():
        relative = entry.removeprefix('MOKSHA/')
        if not relative.endswith(('.gd', '.tres', '.tscn', '.py')):
            continue
        original = sha(archive.read(entry))
        path = ROOT / relative
        current = sha(path.read_bytes()) if path.exists() else None
        rows[relative] = {'v21_sha256': original, 'current_sha256': current, 'same': original == current, 'allowed_changed': relative in allowed}
unexpected = [path for path, row in rows.items() if not row['same'] and not row['allowed_changed']]
report = {'baseline_version':BASELINE_VERSION, 'backup_path':str(BACKUP), 'baseline_archive_sha256':actual, 'pinned_expected_sha256':EXPECTED_SHA256,
          'archive_matches_pinned_v21':True, 'checked_original_sources':len(rows), 'unchanged_original_sources':sum(row['same'] for row in rows.values()),
          'changed_sources':[path for path,row in rows.items() if not row['same']], 'unexpected_changes':unexpected, 'sources':rows}
(ROOT/'combat_pc/tests/ground_response_baseline_hashes.json').write_text(json.dumps(report,indent=2)+'\n')
print(f"v21 archive verified; {report['unchanged_original_sources']}/{len(rows)} original sources unchanged; changed: {report['changed_sources']}")
assert not unexpected, unexpected
