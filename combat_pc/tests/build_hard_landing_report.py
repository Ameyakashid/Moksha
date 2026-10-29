"""Pin actual-physics M6 acceptance, its compatibility runs and historical proof."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import zipfile
ROOT=Path(__file__).resolve().parents[2]
TESTS=ROOT/'combat_pc/tests'
def read(p): return json.loads(p.read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
files={'hard_landing':'hard_landing_results','movement_compatibility':'movement_compat_m6_results',
       'combat_compatibility':'combat_compat_m6_results','traversal_compatibility':'traversal_compat_m6_results',
       'climb_compatibility':'climb_compat_m6_results','wall_compatibility':'wall_compat_m6_results'}
suites={name:{hz:read(TESTS/f'{prefix}_{hz}hz.json') for hz in (120,60)} for name,prefix in files.items()}
preserved=read(TESTS/'hard_landing_preserved_evidence.json')
for path,digest in preserved['files'].items():
    update=preserved.get('documentation_updates',{}).get(path)
    if update:
        assert digest==update['original_sha256']
        assert sha(ROOT/path)==update['current_sha256'],('unrecorded documentation change',path)
        with zipfile.ZipFile(ROOT.parent/'moksha-backups'/update['original_archive']) as z:
            assert hashlib.sha256(z.read(update['original_archive_entry'])).hexdigest()==digest
    else: assert sha(ROOT/path)==digest,('historical artifact changed',path)
assert len(preserved['archives'])==5
for name,digest in preserved['archives'].items():
    assert sha(ROOT.parent/'moksha-backups'/name)==digest,('historical snapshot changed',name)
unchanged=len(preserved['files'])-len(preserved.get('documentation_updates',{}))
logs={}
for name,pair in suites.items():
    for hz,run in pair.items():
        assert not run['failures'],(name,hz,run['failures'])
        assert run['production_hash_stable_during_run'],(name,hz,'source changed during execution')
        for path,digest in run['hashes'].items():
            assert sha(ROOT/path.removeprefix('res://'))==digest,(name,hz,'stale source',path)
        short=name.removesuffix('_compatibility')
        log=TESTS/f'm6_{short}_{hz}.log';content=log.read_text()
        assert 'MOKSHA ' in content and '0 failures' in content,(log,'no completion')
        assert all(token not in content for token in ('SCRIPT ERROR','ERROR:','FAIL:','WARNING:')),(log,'engine diagnostic')
        logs[str(log.relative_to(ROOT))]=sha(log)
    assert pair[120]['hashes']==pair[60]['hashes'],('different rate-pair revisions',name)
    assert [s['name'] for s in pair[120]['scenarios']]==[s['name'] for s in pair[60]['scenarios']],name
hard=suites['hard_landing'][120];controller=hard['hashes']['res://combat_pc/player.gd']
assert all(pair[120]['hashes']['res://combat_pc/player.gd']==controller for pair in suites.values())
for hz,run in suites['hard_landing'].items():
    for scenario in run['scenarios']:
        assert not scenario['measurements'].get('sampling_gaps'),(hz,scenario['name'])
        ticks=[f['tick'] for f in scenario['frames']]
        assert all(b==a+1 for a,b in zip(ticks,ticks[1:])),(hz,scenario['name'],'physics sample gap')
comparisons=[]
def scenario(suite,hz,label): return next(s for s in suites[suite][hz]['scenarios'] if s['name']==label)
def compare(suite,label,metric,bound,reason,extract=None):
    values={hz:(extract(scenario(suite,hz,label),hz) if extract else scenario(suite,hz,label)['measurements'][metric]) for hz in (120,60)}
    row={'suite':suite,'scenario':label,'metric':metric,'value_120hz':values[120],'value_60hz':values[60],
         'allowed_difference':bound,'tolerance_reason':reason,'passed':abs(values[120]-values[60])<=bound+1e-12}
    comparisons.append(row);assert row['passed'],row
compare('hard_landing','ordinary high fall impact recovery and restored control','hard_land_seconds',1/60+1e-9,
        'Impact overshoot carries into recovery; only one final physics boundary may quantize')
for offset in (-.25,0,.25):
    compare('hard_landing',f'hard landing distance boundary {offset:.2f}','observed_contact_travel',.03,
            'Same static geometry and collision margin; 0.03 px covers positional float arithmetic')
for boundary in ('before','at','after','outside_iframes'):
    compare('hard_landing','descent roll protection contact '+boundary,'contact_roll_seconds',1/60+1e-9,
            'Each fixture independently schedules actual contact on the selected roll boundary sample')
for prefix in ('moving floor relative impact','late callback floor relative impact'):
    for velocity in ('500 150','350 -100'):
        compare('hard_landing',prefix+' '+velocity,'relative_impact_speed',.2,
                'Independent constant actor/floor velocities; 0.2 px/s covers transform differencing')
for direction in (-1,1):
    for kind in ('downhill','uphill','uphill_ceiling'):
        compare('hard_landing',f'hard skid {direction} {kind}','slope_recovery_seconds',1/60+1e-9,
                'Same total recovery clock with one final boundary step')
        compare('hard_landing',f'hard skid {direction} {kind}','incoming_hard_horizontal_speed',.02,
                'A controlled motion driver supplies identical incoming horizontal momentum')
for boundary in ('before','at','after'):
    compare('hard_landing','native hard recovery boundary jump '+boundary,'action_after_contact_seconds',1/60+1e-9,
            'Parsed input at the first eligible sample or its immediate neighbors; at most one step difference')
def top_seconds(s,hz):
    start=next(e['tick'] for e in s['events'] if e['event']=='climb_attached')
    end=next(e['tick'] for e in s['events'] if e['event']=='climb_detached' and e['data'].get('reason')=='top_exit')
    return (end-start)/hz
for old in read(ROOT/'combat_pc/wall_verification.json')['cross_rate_comparisons']:
    suite='wall_compatibility' if old['suite']=='wall' else old['suite']
    compare(suite,old['scenario'],old['metric'],old['allowed_difference'],old['tolerance_reason'],
            top_seconds if old['metric']=='top_exit_seconds' else None)
corrections=read(TESTS/'hard_landing_correction_evidence.json')['corrections']
for correction in corrections:
    assert all(any(s['name']==label for s in hard['scenarios']) for label in correction['final_cases']),correction['id']
limits=[
 'All thresholds, fall-history resets, phase durations, skid braking, gates, queues and poses are authored MOKSHA policy. The pinned audit supports ordinary high-fall stun and the historical live-stomp-to-roll exception; no recovered Dead Cells numerical or executable parity is claimed.',
 'The optional hard-landing trigger defaults false; these fixtures explicitly enable it. The previous movement and combat contexts remain covered separately with their original settings.',
 'Trigger classification uses actual swept free-fall excursion and the downward Y component relative to the contacted floor. Carrier displacement is excluded; ordinary roll, dive, weapon and hurt ownership does not erase the excursion. Ground/grip and genuine fresh jumps have explicit reset policies.',
 'Only the exact roll accepted from live dive descent is protected, before its exclusive lifetime end. The protection is independent of combat i-frames. Startup, expired/post-impact dives and cancelled or ordinary rolls do not acquire persistent immunity.',
 'Hard recovery retains existing finite input buffers through its bounded phases. A hitpause requested by a synchronous mid-tick callback freezes subsequent callbacks; the already-admitted physics step may finish using the new owner. This policy does not roll back motion already processed.',
 'Hard recovery preserves incoming horizontal momentum and follows the confirmed floor tangent with swept braking. The inherited final collision travel and soft-land solver are not normalized; comparisons do not claim arbitrary frame-identical pre-impact paths.',
 'The landed hard flag records pre-callback physical qualification; current recovery ownership is reported separately by main_action and hard_land_active. A synchronous later hurt/forced reaction can legitimately preempt the recovery.',
 'The bounded fixtures cover rectangular/one-way floors, supported slopes, thin geometry, moving supports and explicit invalidation. They do not establish escape from an indefinitely advancing crusher, arbitrary collision meshes or a new hazard/health/respawn system.',
 'Headless acceptance uses actual Godot physics and parsed keyboard events. Native presentation, final export boot and subjective feel checks are separate; this report does not infer animation parity.'
]
audit=ROOT.parent/'reference_sources/dead-cells-audit/HARD_LANDING_EVIDENCE.md'
report={'title':'MOKSHA combat PC hard-landing verification','milestone':6,'status':'passed','generated_utc':datetime.now(timezone.utc).isoformat(),
 'controller_sha256':controller,'engine':hard['engine'],'production_hashes':hard['hashes'],
 'contract_sha256':sha(ROOT/'combat_pc/MOTOR_CONTRACT.md'),'report_builder_sha256':sha(Path(__file__)),
 'reference_pin':'77c3ad263c4187ade6d048ba77bb61f79e6cec44','hard_landing_audit_sha256':sha(audit),
 'movement_profile':hard['movement_profile'],'combat_profile':hard['combat_profile'],
 'execution':'Production actor in actual physics callbacks; every post-actor physics tick recorded with native edges, shape contacts, support transforms and semantic/noise events. Native input is centrally released between scenarios.',
 'suites':{},'cross_rate_comparisons':comparisons,'scenarios':[],'verified_corrections':corrections,
 'correction_evidence_sha256':sha(TESTS/'hard_landing_correction_evidence.json'),'console_logs_sha256':logs,
 'preserved_evidence':{'unchanged_original_paths':unchanged,'recorded_previous_results_and_traces_unchanged':True,'original_documentation_content_preserved':True,**preserved},
 'compatibility_method':'Original five regression harnesses copied to /tmp with only output filenames redirected to M6. Prior traces, acceptance artifacts and M1–M5 snapshots remain preserved; intentional documentation changes are separately classified.',
 'harness_clarifications':[
  'Weapon phase at contact is observed from the actual cancellation event; a phase may legitimately advance on the same physics tick before the floor sweep.',
  'Skid stopping is measured after the authored braking interval, rather than assuming the impact-to-recovery boundary already implies zero horizontal speed.',
  'A callback that requests hurt and pause before the motion portion of an active tick may complete one ordinary recoil step. Later paused callbacks must preserve that position/velocity.',
  'Boundary input is scheduled on the first physics sample at or beyond the total authored duration and its immediate neighbors; duration overshoot carries across the two phases.'
 ],'limits':limits}
for name,pair in suites.items():
    report['suites'][name]={str(hz):{'scenarios':len(run['scenarios']),'assertions':run['checks'],'failures':len(run['failures']),
      'frames':sum(len(s['frames']) for s in run['scenarios']),'source_stable':True,'path':str((TESTS/f'{files[name]}_{hz}hz.json').relative_to(ROOT)),
      'sha256':sha(TESTS/f'{files[name]}_{hz}hz.json')} for hz,run in pair.items()}
for index,s in enumerate(hard['scenarios']):
    report['scenarios'].append({'name':s['name'],'passed_at':[120,60],'assertions':[a['label'] for a in s['assertions']],
      'traces':{str(hz):{'path':f'combat_pc/tests/hard_landing_results_{hz}hz.json','json_pointer':f'/scenarios/{index}'} for hz in (120,60)}})
(ROOT/'combat_pc/hard_landing_verification.json').write_text(json.dumps(report,indent=2)+'\n')
lines=['# Hard-landing verification','',
 f'**Passed at 120 Hz and 60 Hz:** {len(hard["scenarios"])} hard-landing scenarios / {hard["checks"]} assertions per rate. All five earlier movement, combat, drop/dive, climb and wall suites also pass on the same controller. Twelve runs have zero failures and clean engine logs.','',
 f'Controller SHA-256: `{controller}`. [Detailed evidence](hard_landing_verification.json) pins tested production files, profiles, harnesses, traces and console logs.','',
 '## Connected behavior','',
 '- Optional trigger; below/at/above height and speed boundaries; both conditions required; final swept distance and relative moving-floor impact velocity.',
 '- Ordinary and high/low dive impacts, exactly-once semantic/noise dispatch, bounded small-body impact/recovery, finite skid, host-facing gates, and fresh input before/at/after release.',
 '- Independent airborne budgets; real jump/grip reset rules; no reset from roll/dive/weapon/hurt; carrier motion excluded; actual spent-resource landing and repeated same-instance reset.',
 '- Exact active-dive roll protection through its own lifetime, including after i-frames, plus contact immediately before/at/after expiry and cancelled/startup/expired/post-impact exclusions.',
 '- Native queued taps and latest repress through recovery and pause; host permission changes, disabled input, low headroom, floor removal, moving support, one-way stacked drops, thin geometry and mirrored slopes.',
 '- Synchronous host callbacks retain newer hurt/forced ownership; the old landing transaction cannot continue stale setup, phase work or handoff over a newer owner.','',
 '## Corrections and evidence','']
for correction in corrections:
    lines.append('- **'+correction['issue']+'.** Evidence: '+correction['evidence_kind']+'.')
lines += ['', 'The [correction evidence](tests/hard_landing_correction_evidence.json) distinguishes physical pre-fix traces from review corrections verified afterward. No collision tolerance was widened to hide a failure. Setup/observation clarifications are recorded in the JSON.','',
 '## Rate comparison and preservation','',
 f'All {len(comparisons)} paired bounds pass, including the unchanged 28 previous bounds. Controlled slope tests preserve the same incoming X at both rates; recovery timing allows one boundary step. The project remains at 120 Hz, with 60 Hz used only as a runtime test override.','',
 f'{unchanged} earlier artifacts and all five milestone ZIPs retain their hashes. TRACE_ARCHIVE.md has one intentional archive-instructions update, with before/after hashes and original text verified in the M5 snapshot. Current M6 traces and compatibility outputs are separate from earlier evidence.','',
 '## Scope','']
lines += ['- '+limit for limit in limits]
lines += ['', '## Reproduce','',
 'Run the new harness with writable XDG paths, redirecting the console to the matching `combat_pc/tests/m6_hard_landing_<rate>.log`:','', '```sh',
 'XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/hard_landing_regression.gd -- --hz=120',
 'XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/hard_landing_regression.gd -- --hz=60',
 '```','',
 'For compatibility, copy movement/combat/traversal/climb/wall harnesses to `/tmp` and redirect only output filenames to `<suite>_compat_m6_results_%dhz.json` (movement retains its extra `%s` suffix). Save `m6_<suite>_<rate>.log`. Run `python3 combat_pc/tests/build_hard_landing_report.py` to reject stale sources, failed checks, engine errors, missing physics samples, changed historical evidence or exceeded bounds.','',
 'The current evidence is delivered separately in `MOKSHA-PC-Landing-Verification.zip`. Historical preservation re-audits also require the earlier datasets and original snapshots; they are not needed merely to play the project or execute a current regression.','',
 'Traces: [landing 120 Hz](tests/hard_landing_results_120hz.json), [landing 60 Hz](tests/hard_landing_results_60hz.json), and ten `*_compat_m6_results_*hz.json` files indexed in the detailed report.','']
(ROOT/'combat_pc/hard_landing_verification.md').write_text('\n'.join(lines))
print(f'PASS: {len(hard["scenarios"])} landing scenarios; six paired suites, {len(comparisons)} bounds, {unchanged} unchanged historical artifacts and five snapshots verified')
