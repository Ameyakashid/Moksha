"""Independent cross-rate and cross-variant comparisons of completed physics evidence."""
from pathlib import Path
import hashlib
import json
ROOT=Path(__file__).resolve().parents[2]
HERE=ROOT/'combat_pc/tests'
checks=[]
def check(condition,description,details=None):
    checks.append({'passed':bool(condition),'description':description,'details':details})
reports={hz:json.loads((HERE/f'air_response_results_{hz}hz.json').read_text()) for hz in [60,120]}
rows={(hz,row['variant'],row['direction']):row for hz,r in reports.items() for row in r['response_rows']}
jumps={(hz,row['variant'],row['direction'],row['kind']):row for hz,r in reports.items() for row in r['jump_rows']}
for hz in reports:
    for suite in ['','_owners','_ground','_archive','_health','_defeat','_noise']:
        report=json.loads((HERE/f'air_response{suite}_results_{hz}hz.json').read_text())
        fresh=all(hashlib.sha256((ROOT/path.removeprefix('res://')).read_bytes()).hexdigest()==digest for path,digest in report['source_hashes'].items())
        check(not report['failures'] and report['production_hash_stable_during_run'] and fresh,f'{suite or "ordinary air"} {hz} Hz evidence is passing, source-stable, and current',{'scenarios':len(report['scenarios'])})
    for mode in ['baseline','candidate']:
        a,b=rows[hz,mode,-1],rows[hz,mode,1]
        metrics=['start_to_cap_seconds','start_to_cap_distance','reverse_zero_seconds','reverse_full_seconds','reversal_overshoot','neutral_stop_seconds','neutral_stop_distance']
        check(all(abs(a[m]-b[m])<1e-5 for m in metrics),f'{mode} {hz} Hz air response is symmetric left/right')
        check(a['maximum_speed']==b['maximum_speed']==218,f'{mode} {hz} Hz sampled cap remains exactly 218 px/s')
    base,candidate=rows[hz,'baseline',1],rows[hz,'candidate',1]
    for metric in ['start_to_cap_seconds','reverse_zero_seconds','reverse_full_seconds','reversal_overshoot']:
        check(candidate[metric]<base[metric],f'{hz} Hz candidate improves {metric}',{'baseline':base[metric],'candidate':candidate[metric]})
    check(abs(candidate['neutral_stop_seconds']-base['neutral_stop_seconds'])<1e-9 and abs(candidate['neutral_stop_distance']-base['neutral_stop_distance'])<.00005,f'{hz} Hz neutral release duration and travel preserve baseline',{'baseline_seconds':base['neutral_stop_seconds'],'candidate_seconds':candidate['neutral_stop_seconds'],'baseline_distance':base['neutral_stop_distance'],'candidate_distance':candidate['neutral_stop_distance']})
    for direction in [-1,1]:
        for kind in ['held','release','air_jump']:
            old,new=jumps[hz,'baseline',direction,kind],jumps[hz,'candidate',direction,kind]
            check(old['air_seconds']==new['air_seconds'] and abs(old['apex_height']-new['apex_height'])<=.00005,f'{hz} Hz {kind} direction{direction} preserves airtime and apex within float sweep tolerance',{'air_seconds':new['air_seconds'],'maximum_apex_difference':abs(old['apex_height']-new['apex_height'])})
        old,new=jumps[hz,'baseline',direction,'landing_correction'],jumps[hz,'candidate',direction,'landing_correction']
        check(new['landing_error']<old['landing_error'] and new['landing_error']<16,f'{hz} Hz direction{direction} fixed timed jump correction reduces marked-target error',{'baseline':old['landing_error'],'candidate':new['landing_error'],'target_half_width':16})
for mode in ['baseline','candidate']:
    slow,fast=rows[60,mode,1],rows[120,mode,1]
    for metric in ['start_to_cap_seconds','reverse_zero_seconds','reverse_full_seconds','neutral_stop_seconds']:
        check(abs(slow[metric]-fast[metric])<=1/60+1e-9,f'{mode} {metric} cross-rate difference is at most one 60 Hz callback',{'60hz':slow[metric],'120hz':fast[metric]})
    for metric in ['start_to_cap_distance','reversal_overshoot','neutral_stop_distance']:
        check(abs(slow[metric]-fast[metric])<=218/60,f'{mode} {metric} cross-rate difference is at most one 60 Hz cap-speed travel step',{'60hz':slow[metric],'120hz':fast[metric]})
    for kind in ['held','release','air_jump','landing_correction']:
        slow,fast=jumps[60,mode,1,kind],jumps[120,mode,1,kind]
        check(abs(slow['air_seconds']-fast['air_seconds'])<=1/60+1e-9,f'{mode} {kind} airborne duration agrees within one 60 Hz callback')
result={'milestone':19,'suite':'air steering cross-rate comparison','comparisons':checks,'failures':[row for row in checks if not row['passed']],'scope':'Comparisons summarize completed real physics runs; no frame-by-frame assertion-count inflation.'}
(HERE/'air_response_rate_comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'Air response cross-rate: {len(checks)} behavioral comparisons, {len(result["failures"])} failures')
if result['failures']:
    for failure in result['failures']:print(failure)
    raise SystemExit(1)
