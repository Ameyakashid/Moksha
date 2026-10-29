"""Cross-run comparisons use completed real-physics reports; no in-engine oracle."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
reports={hz:json.loads((ROOT/f'ground_response_results_{hz}hz.json').read_text()) for hz in (60,120)}
checks=[]
def check(condition,description,details=None):
    checks.append({'passed':bool(condition),'description':description,'details':details})
rows={}
for hz,report in reports.items():
    check(not report['failures'] and report['candidate_loaded_from_actual_resource'] and report['production_hash_stable_during_run'],f'{hz} Hz report is clean and uses actual stable candidate resource')
    for row in report['response_rows']: rows[hz,row['variant'],row['direction']]=row
metrics=['start_to_cap_seconds','stop_seconds','stop_distance','reverse_zero_seconds','reverse_full_seconds']
for hz in reports:
    for variant in ('baseline','candidate'):
        a,b=rows[hz,variant,-1],rows[hz,variant,1]
        check(all(abs(a[m]-b[m])<1e-5 for m in metrics),f'{hz} Hz {variant} measured response is symmetric left/right')
        check(a['max_speed']==b['max_speed']==218,f'{hz} Hz {variant} run cap is 218 px/s in both directions')
    baseline,candidate=rows[hz,'baseline',1],rows[hz,'candidate',1]
    for metric in metrics:
        check(candidate[metric]<baseline[metric],f'{hz} Hz candidate improves {metric}',{'baseline':baseline[metric],'candidate':candidate[metric]})
for variant in ('baseline','candidate'):
    a,b=rows[60,variant,1],rows[120,variant,1]
    for metric in metrics:
        allowance=218/60 if metric=='stop_distance' else 1/60+1e-9
        check(abs(a[metric]-b[metric])<=allowance,f'{variant} cross-rate {metric} differs by no more than one 60 Hz callback travel/time',{'60hz':a[metric],'120hz':b[metric],'allowance':allowance})
    # A split deceleration-then-acceleration reversal has the same end-to-end
    # sampled duration at both tested rates for this authored candidate.
    check(abs(a['reverse_full_seconds']-b['reverse_full_seconds'])<1e-9,f'{variant} full reversal duration agrees at 60 and 120 Hz')
for suite in ('health','defeat','noise'):
    for hz in reports:
        d=json.loads((ROOT/f'ground_response_{suite}_results_{hz}hz.json').read_text())
        check(not d['failures'] and d['production_hash_stable_during_run'],f'{suite} preserved integration clean on candidate at {hz} Hz',{'scenarios':len(d['scenarios'])})
result={'suite':'M18 cross-rate response comparison','failures':[row for row in checks if not row['passed']],'comparisons':checks}
(ROOT/'ground_response_rate_comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(f"Ground response cross-rate: {len(checks)} behavioral comparisons, {len(result['failures'])} failures")
assert not result['failures'],result['failures']
