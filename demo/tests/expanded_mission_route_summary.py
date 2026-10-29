"""Validate the expanded full-mission matrix without altering earlier evidence."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'demo/evidence'
shared = None
rows = []
for hz in (60, 120):
    for sight in ('retained', 'sacrificed'):
        name = f'expanded_mission_route_{hz}hz_{sight}.json'
        path = EVIDENCE / name
        report = json.loads(path.read_text())
        assert report['completed'], name
        assert report['scene'] == 'res://demo/mission.tscn' and not report['relay_recovery_probe'], name
        assert all(report['input_held_frames'][button] > 0 for button in ('attack', 'jump', 'shield', 'roll', 'tap')), name
        assert report['authored_sector_count'] == 9, f'Expected eight expanded areas plus ending: {name}'
        assert report['authored_area_ids'] == ['rainline','quarantine_intake','exchange','freight_lock','cistern','upper_residential_crossing','relay_works','lift_warden','above_the_rain'], name
        assert len(report['sectors']) == report['authored_sector_count'], name
        assert not report['failures'] and not report['sources_changed_during_run'], name
        assert report['probe_sector'] == -1 and not report['human_duration_validated'], name
        assert not report['pre_run_sight_fixture'], name
        assert report['sectors'][-1]['blind'] == (sight == 'sacrificed'), name
        choices = [e for e in report['events'] if e['event'] == 'sight_choice']
        assert len(choices) == 1 and choices[0]['sacrificed'] == (sight == 'sacrificed'), name
        exits = [e for e in report['events'] if e['event'] == 'sector_exit']
        assert len(exits) == report['authored_sector_count'], name
        assert [e['area_id'] for e in exits] == report['authored_area_ids'], name
        assert any(e['event'] == 'pause_resume' and e['passed'] for e in report['events']), name
        relay_exits = [e for e in exits if e['area_id'] == 'relay_works']
        assert len(relay_exits) == 1 and relay_exits[0]['activated_relays'] == 3 and relay_exits[0]['closed_shutters'] == 0, name
        freight_exits = [e for e in exits if e['area_id'] == 'freight_lock']
        assert len(freight_exits) == 1 and freight_exits[0]['freight']['latched'], name
        assert freight_exits[0]['freight']['intact'] and freight_exits[0]['freight']['hit_count'] >= 1, name
        assert freight_exits[0]['closed_shutters'] == 0, name
        assert any(e['event'] == 'freight_actual_launch' for e in report['events']), name
        assert any(e['event'] == 'freight_latched' and e['intact'] for e in report['events']), name
        if shared is None:
            shared = report['source_hashes']
        assert report['source_hashes'] == shared, name
        log = Path(f'/tmp/expanded_mission_route_{hz}_{sight}.log')
        log_text = log.read_text()
        assert not re.search(r'ERROR:|SCRIPT ERROR:|WARNING:', log_text), str(log)
        previous = 0.0
        areas = []
        for entry in exits:
            areas.append({'title': entry['title'], 'seconds': entry['active_seconds'] - previous,
                          'remaining_enemies': entry['remaining_enemies'], 'health': entry['health']})
            previous = entry['active_seconds']
        rows.append({
            'hz': hz, 'sight': sight, 'simulated_active_seconds': report['simulated_active_seconds'],
            'kills': report['kills'], 'authored_enemies': report['authored_enemy_count'],
            'bypassed_enemies': sum(e['remaining_enemies'] for e in exits),
            'archives': report['caches'], 'authored_archives': report['authored_archive_count'],
            'deaths': report['deaths'], 'retries': report['retry_count'], 'areas': areas,
            'input_held_frames': report['input_held_frames'], 'damage_receipt_count': len(report['damage_receipts']),
            'freight': freight_exits[0]['freight'],
            'report': 'demo/evidence/' + name, 'report_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'log': str(log), 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest(), 'log_errors_warnings': 0, 'log_text': log.read_text(),
        })
for path, expected in shared.items():
    actual = hashlib.sha256((ROOT / path.removeprefix('res://')).read_bytes()).hexdigest()
    assert actual == expected, f'Current source differs from captured source: {path}'
result = {
    'suite': 'Expanded full-mission raw-input route matrix',
    'all_completed': True, 'human_duration_validated': False, 'human_sonar_navigation_validated': False,
    'scope': 'Seven substantial areas plus ending at60/120Hz with both sight choices.',
    'limitations': 'Layout/AI-aware deterministic bot. Simulated active timing excludes paused panels. Does not validate human pacing, perception, difficulty or first-time discovery.',
    'routes': rows, 'shared_source_hashes': shared, 'current_sources_match_all_reports': True,
}
result['verified_at_utc'] = datetime.now(timezone.utc).isoformat()
(EVIDENCE / 'expanded_mission_route_matrix.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
