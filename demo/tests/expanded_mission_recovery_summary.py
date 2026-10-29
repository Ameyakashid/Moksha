"""Validate separate, explicitly positioned closed-compartment recovery fixtures."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
ROOT=Path(__file__).resolve().parents[2]
EVIDENCE=ROOT/'demo/evidence'
rows=[]
shared=None
expected={'service_left_floor_to_hub','service_hub_to_left_floor','lift_right_floor_to_upper_relay','lift_hub_to_right_floor','dispatch_right_floor_to_relay','dispatch_left_floor_to_relay'}
for hz in (60,120):
    for sight in ('retained','sacrificed'):
        name=f'expanded_mission_recovery_audit_{hz}hz_{sight}.json'
        path=EVIDENCE/name
        report=json.loads(path.read_text())
        assert not report['failures'] and not report['sources_changed_during_run'],name
        assert {c['case'] for c in report['cases']}==expected,name
        assert len(report['cases'])==6,name
        for case in report['cases']:
            assert case['completed'] and not case['failure'],(name,case['case'])
            assert case['all_three_shutters_remained_closed'],(name,case['case'])
            assert len(case['starting_closed_rectangles'])==3,(name,case['case'])
            assert case['blind']==(sight=='sacrificed'),(name,case['case'])
            assert all(len(t['closed_shutters'])==3 and not t['active_relays'] for t in case['trace']),(name,case['case'])
            if case['case']=='dispatch_right_floor_to_relay':
                assert any(e['event']=='climb_detached' and 'top_exit' in e['payload'] and '(3610.0,' in e['position'] for e in case['events']),(name,'actual Dispatch ladder top exit')
            if case['case']=='lift_right_floor_to_upper_relay':
                assert any(e['event']=='climb_detached' and 'top_exit' in e['payload'] and '(1740.0,' in e['position'] for e in case['events']),(name,'actual Lift ladder top exit')
        if shared is None: shared=report['source_hashes']
        assert shared==report['source_hashes'],name
        log=Path(f'/tmp/expanded_mission_recovery_audit_{hz}_{sight}.log')
        assert not re.search(r'ERROR:|SCRIPT ERROR:|WARNING:',log.read_text()),str(log)
        rows.append({'hz':hz,'sight':sight,'cases':[{key:value for key,value in case.items() if key not in ('events','trace','starting_closed_rectangles')} for case in report['cases']], 'report':'demo/evidence/'+name,'report_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'log':str(log),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'log_errors_warnings':0,'log_text':log.read_text()})
for path,expected_hash in shared.items():
    assert hashlib.sha256((ROOT/path.removeprefix('res://')).read_bytes()).hexdigest()==expected_hash,path
result={'suite':'Relay Works closed-compartment recovery fixtures','all_completed':True,'passed_cases':24,'human_duration_validated':False,'full_mission_evidence':False,'method':'Explicit pre-run position and sight fixtures; normal measured PC movement/combat thereafter, with all three relays inactive and all shutter colliders closed. Tests both sides of each barrier.','runs':rows,'shared_source_hashes':shared,'current_sources_match_all_reports':True}
result['verified_at_utc'] = datetime.now(timezone.utc).isoformat()
(EVIDENCE/'expanded_mission_recovery_matrix.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
