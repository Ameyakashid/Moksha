"""Report isolated route evidence; never convert bot seconds to human minutes."""
import hashlib,json,pathlib
root=pathlib.Path(__file__).resolve().parents[2]
rows=[]
for path in sorted(pathlib.Path(__file__).parent.glob('l[23]*.json')):
    data=json.loads(path.read_text())
    mismatches=[]
    for res,digest in data.get('source_hashes',{}).items():
        source=root/res.removeprefix('res://')
        if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest()!=digest:
            mismatches.append(res)
    rows.append(dict(district=data['district'],sight='traded' if data['sight'] else 'retained',
        route_passed=data['passed'],bot_active_seconds=round(data['bot_active_seconds'],3),
        in_run_source_drift=data['source_drift'],current_source_mismatches=mismatches,
        frozen_current_acceptance=data['passed'] and not data['source_drift'] and not mismatches,
        evidence=str(path.relative_to(root))))
report=dict(scope='Isolated district-start and pre-run sight fixtures; not full campaign',
    human_duration_validated=False,results=rows)
print(json.dumps(report,indent=2))
