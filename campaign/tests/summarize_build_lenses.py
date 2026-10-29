#!/usr/bin/env python3
from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[2];rows=[]
for lens in ['strength','agility']:
 path=root/'campaign/tests'/f'full_route_60_{lens}_retained.json';report=json.loads(path.read_text());log=path.with_suffix('.log').read_text()
 errors=[x for x in log.splitlines() if x.startswith(('ERROR:','SCRIPT ERROR:'))]
 mismatch=[p for p,h in report['source_hashes'].items() if hashlib.sha256((root/p.removeprefix('res://')).read_bytes()).hexdigest()!=h]
 passed=report['passed'] and report['completed'] and not report['failures'] and not report['source_drift'] and not errors and not mismatch and 'FULL_CAMPAIGN_RESULT ' in log
 rows.append(dict(lens=lens,observer_script='campaign/tests/full_campaign_strength_route.gd' if lens=='strength' else 'campaign/tests/full_campaign_route.gd',passed=passed,report=str(path.relative_to(root)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),active_seconds=report['active_seconds'],engine_errors=errors,current_source_mismatch=mismatch))
result=dict(passed=all(r['passed'] for r in rows),cases=rows,human_duration_validated=False)
(root/'campaign/tests/build_lens_matrix.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));raise SystemExit(0 if result['passed'] else 1)
