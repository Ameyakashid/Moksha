"""Final isolated45 acceptance: completeness, zero drift, current source identity."""
import hashlib,json,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).parent/'final'
AREAS=['works_receiving','works_baffle_hall','works_cargo_exchange','works_memory_loom','works_service_refuge','works_three_crews','works_dispatch_refusal','crown_ascent','crown_witness_galleries','crown_manual_governor','crown_refuge_channel','crown_coolant_interlock','crown_last_warden','crown_choice_threshold']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
current={}
for directory,children,files in os.walk(ROOT):
 children[:]=[c for c in children if not(c.startswith('.') or 'test' in c or 'evidence' in c or 'qa' in c or c=='docs')]
 for filename in files:
  p=Path(directory)/filename
  if p.suffix in ['.gd','.tres','.tscn','.godot','.gdshader']:current['res://'+str(p.relative_to(ROOT))]=digest(p)
failures=[];rows=[];totals={}
for area in AREAS:
 for mode in ['sighted','blind']:
  p=OUT/f'{area}_{mode}_60hz.json'
  if not p.exists():failures.append(f'Missing {p.name}');continue
  d=json.loads(p.read_text());end=d.get('source_hashes_at_end',{});start=d.get('source_hashes_at_start',{})
  stale=[path for path,h in end.items() if digest(ROOT/path.removeprefix('res://'))!=h]
  added=[path for path in current if path not in end]
  row={'area':area,'sight':mode,'passed':d['passed'],'hz':d.get('hz'),'simulated_seconds':d['frames']/d['hz'],'failures':d['failures'],'drift':d.get('sources_changed_during_run',[]),'stale_sources_now':stale,'new_production_sources_now':added}
  if not d['passed'] or d.get('hz')!=60 or row['drift'] or stale or added or start!=end:failures.append(f'Unaccepted {p.name}')
  rows.append(row)
  key=f"level_{4 if area.startswith('works_') else 5}_{mode}"
  totals[key]=totals.get(key,0)+row['simulated_seconds']
summary={'passed':not failures and len(rows)==28,'expected_runs':28,'observed_runs':len(rows),'failures':failures,'isolated_optimized_seconds_summed_not_campaign_playtime':totals,'human_duration_validated':False,'continuous_campaign_verified':False,'method':'Each district starts from explicitly labeled fixture, then real movement/combat/idle key inputs with live opponents. All28 must pass zero start/end drift and source identity against current production. Final threshold enters choice but does not resolve ending.','runs':rows}
OUT.mkdir(exist_ok=True);(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='runs'},indent=2))
raise SystemExit(0 if summary['passed'] else 1)
