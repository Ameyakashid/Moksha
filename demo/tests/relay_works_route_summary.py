"""Validate/aggregate independent Relay Works route evidence without changing v27."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'demo/evidence'
rows = []
shared = None
for hz in (60, 120):
    for sight in ('retained', 'sacrificed'):
        filename = f'relay_works_route_{hz}hz_{sight}.json'
        path = EVIDENCE / filename
        report = json.loads(path.read_text())
        assert report['completed'] and len(report['sectors']) == 2, filename
        assert not report['failures'] and not report['sources_changed_during_run'], filename
        assert not report['human_duration_validated'], filename
        assert report['probe_sector'] == -1, filename
        assert all(area['blind'] == (sight == 'sacrificed') for area in report['sectors']), filename
        assert report['deaths'] == 0 and report['retry_count'] == 0, filename
        choices = [e for e in report['events'] if e['event'] == 'sight_choice']
        assert len(choices) == 1 and choices[0]['sacrificed'] == (sight == 'sacrificed'), filename
        exits = [e for e in report['events'] if e['event'] == 'sector_exit']
        assert len(exits) == 2 and exits[0]['activated_relays'] == 3 and exits[0]['closed_shutters'] == 0, filename
        assert exits[0]['remaining_enemies'] + report['kills'] == 13, filename
        assert any(e['event'] == 'pause_resume' and e['passed'] for e in report['events']), filename
        assert any(e['event'] == 'spawn_physics_acceptance' and e['grounded'] for e in report['events']), filename
        assert any(e['event'] == 'archive_read_and_close' for e in report['events']), filename
        if shared is None:
            shared = report['source_hashes']
        assert report['source_hashes'] == shared, filename
        log = Path(f'/tmp/relay_works_route_clean_{hz}_{sight}.log')
        text = log.read_text()
        assert not re.search(r'ERROR:|SCRIPT ERROR:|WARNING:', text), str(log)
        rows.append({
            'hz': hz, 'sight': sight, 'simulated_active_seconds': report['simulated_active_seconds'],
            'module_active_seconds': exits[0]['active_seconds'], 'kills': report['kills'],
            'authored_enemies': 13, 'bypassed_enemies': exits[0]['remaining_enemies'],
            'archives': report['caches'], 'authored_archives': 1,
            'health_at_module_exit': exits[0]['health'], 'deaths': report['deaths'], 'retries': report['retry_count'],
            'relays_activated': 3, 'closed_shutters_at_exit': 0,
            'report': 'demo/evidence/' + filename, 'report_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'log': str(log), 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest(), 'log_errors_warnings': 0,
        })
for path, expected in shared.items():
    actual = hashlib.sha256((ROOT / path.removeprefix('res://')).read_bytes()).hexdigest()
    assert actual == expected, f'Current source differs from captured source: {path}'
result = {
    'suite': 'Relay Works isolated raw-input route matrix',
    'all_completed': True,
    'human_duration_validated': False,
    'human_sonar_navigation_validated': False,
    'scope': 'Two sight states at60/120Hz, three live relay-controlled shutters, isolated area plus ending.',
    'limitations': 'Layout/AI-aware deterministic bot. Simulated active timing excludes paused panels. Does not validate human pacing, perception, difficulty or an integrated expanded main mission.',
    'routes': rows,
    'shared_source_hashes': shared,
    'current_sources_match_all_reports': True,
    'superseded_diagnostic': 'relay_works_route_pre_dispatch_diagnostic_60hz_retained.json used the old Dispatch ground ladder and resumed the test harness directly from a physics signal; it is not clean final acceptance.',
}
out = EVIDENCE / 'relay_works_route_matrix.json'
out.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
