"""Strict frozen-source summary of the 24 post-health-rebind isolated routes."""
import hashlib,json,pathlib
root=pathlib.Path(__file__).resolve().parents[2]
folder=pathlib.Path(__file__).parent/'final'
rows=[];manifests={};all_errors=[]
for path in sorted(folder.glob('l[23]*.json')):
 d=json.loads(path.read_text());mismatch=[]
 for res,expected in d['source_hashes'].items():
  source=root/res.removeprefix('res://')
  if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest()!=expected:mismatch.append(res)
 manifest_hash=hashlib.sha256(json.dumps(d['source_hashes'],sort_keys=True,separators=(',',':')).encode()).hexdigest()
 manifests[manifest_hash]=d['source_hashes']
 hp=[r['health'] for r in d['trace'] if 'health' in r]
 passed=d['passed'] and not d['failures'] and not d['source_drift'] and not mismatch
 rows.append(dict(district=d['district'],sight='traded' if d['sight'] else 'retained',passed=passed,
  bot_active_seconds=d['bot_active_seconds'],minimum_sampled_health=min(hp) if hp else None,
  source_count=len(d['source_hashes']),source_manifest_sha256=manifest_hash,
  current_source_mismatches=mismatch,in_run_source_drift=d['source_drift'],failures=d['failures'],
  evidence=str(path.relative_to(root)),goals=d['goals_observed']))
 if not passed:all_errors.append(str(path.name))
ids={r['district'] for r in rows}
coverage=len(rows)==24 and len(ids)==12 and all({r['sight'] for r in rows if r['district']==i}=={'retained','traded'} for i in ids)
if not coverage:all_errors.append('Expected exactly12districts x2sightfixtures')
if len(manifests)!=1:all_errors.append('Expected a single identical captured source manifest')
report=dict(suite='L2/L3 final isolated production-input routes after health receiver rebinding',passed=not all_errors,
 coverage='12 districts x retained/traded sight at60Hz',expected_runs=24,actual_runs=len(rows),
 human_duration_validated=False,full_campaign_validated=False,failures=all_errors,
 method='Explicit initial district/sight fixture, then ordinary raw movement/combat and idle-dispatched E/Q key events. No measured-phase teleport, health, goal, gate, enemy-state or collision writes.',
 actual_damage_context='All reports use rebound incoming health receivers. Minimum sampled health is a diagnostic sample, not an exhaustive damage receipt or end-health claim.',
 source_manifests=list(manifests),results=rows)
(folder/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
if len(manifests)==1:(folder/'source_manifest.json').write_text(json.dumps(next(iter(manifests.values())),indent=2,sort_keys=True)+'\n')
lines=['# L2/L3 final isolated input validation','',f'**{sum(r["passed"] for r in rows)}/24 accepted runs.** Overall: '+('PASS' if report['passed'] else 'NOT ACCEPTED')+'.','',
 'Post-health-rebind production.12 districts ×2 actual sight fixtures,60Hz. Each starts in an explicitly selected district; these are not a continuous campaign or human-duration measurement.','',
 '| District | Retained bot seconds | Traded bot seconds |','|---|---:|---:|']
for i in sorted(ids):
 pair={r['sight']:r for r in rows if r['district']==i}
 lines.append(f'| {i} | {pair.get("retained",{}).get("bot_active_seconds",0):.2f} | {pair.get("traded",{}).get("bot_active_seconds",0):.2f} |')
lines+=['','All reported accepted runs have no in-run source drift, no failures and matching current captured code/resource hashes. The manifest includes the executing observer and inherited navigation plus production scripts/scenes/resources. No exclusions are applied.','',
 'The retained/traded timings above belong only to these knowledgeable isolated bots. They must not be multiplied into a human playtime claim or added together as evidence of a continuous campaign.','',
 'Historical diagnostics, including the embedded Dispatch terminal failure and pre-health-rebind survival-invalidated results, remain under `../diagnostics/`.']
if all_errors:lines+=['','Acceptance errors: '+', '.join(all_errors)]
(folder/'SUMMARY.md').write_text('\n'.join(lines)+'\n')
print(json.dumps({k:report[k] for k in ['passed','actual_runs','failures','source_manifests']},indent=2))
