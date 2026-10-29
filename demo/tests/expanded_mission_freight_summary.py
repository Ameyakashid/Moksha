"""Verify independent actual-input Freight approaches; no full-mission claims."""
from pathlib import Path
from datetime import datetime, timezone
import json
import hashlib
import re
ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'demo/evidence'
rows = []
shared = None
cases = [(hz, sight, approach) for hz in (60, 120) for sight in ('retained', 'sacrificed') for approach in ('direct', 'flank')]
for hz, sight, approach in cases:
    name = f'freight_lock_route_{hz}hz_{sight}_{approach}.json'
    path = EVIDENCE / name
    report = json.loads(path.read_text())
    assert report['completed'] and len(report['sectors']) == 2, name
    assert not report['failures'] and not report['sources_changed_during_run'], name
    assert report['pre_run_sight_fixture'] == (sight == 'sacrificed'), name
    assert all(area['blind'] == (sight == 'sacrificed') for area in report['sectors']), name
    exits = [e for e in report['events'] if e['event'] == 'sector_exit']
    assert exits[0]['freight']['latched'] and exits[0]['freight']['intact'], name
    assert exits[0]['closed_shutters'] == 0, name
    assert any(e['event'] == 'freight_actual_launch' for e in report['events']), name
    assert any(e['event'] == 'freight_latched' and e['intact'] for e in report['events']), name
    if approach == 'flank':
        assert len([e for e in report['events'] if e['event'] == 'freight_flank_waypoint']) == 2, name
    if shared is None:
        shared = report['source_hashes']
    assert shared == report['source_hashes'], name
    log = Path(f'/tmp/freight_lock_route_final_{hz}_{sight}_{approach}.log')
    assert not re.search(r'ERROR:|SCRIPT ERROR:|WARNING:', log.read_text()), str(log)
    rows.append({'hz': hz, 'sight': sight, 'approach': approach,
                 'pre_run_sight_fixture': report['pre_run_sight_fixture'],
                 'simulated_active_seconds': report['simulated_active_seconds'],
                 'kills': report['kills'], 'bypassed_enemies': exits[0]['remaining_enemies'],
                 'health_at_freight_exit': exits[0]['health'], 'deaths': report['deaths'],
                 'retries': report['retry_count'], 'freight': exits[0]['freight'],
                 'report': 'demo/evidence/' + name, 'report_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                 'log': str(log), 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest(), 'log_errors_warnings': 0, 'log_text': log.read_text()})
for path, expected in shared.items():
    assert hashlib.sha256((ROOT / path.removeprefix('res://')).read_bytes()).hexdigest() == expected, path
result = {'suite': 'Isolated Freight Lock raw-input approaches', 'all_completed': True,
          'human_duration_validated': False, 'full_mission_evidence': False,
          'sight_fixture_note': 'Sacrificed isolated runs configure sight before the active clock starts. Full-mission sight choices are tested separately at the actual Exchange station.',
          'routes': rows, 'shared_source_hashes': shared, 'current_sources_match_all_reports': True}
result['verified_at_utc'] = datetime.now(timezone.utc).isoformat()
(EVIDENCE / 'freight_lock_route_matrix.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
