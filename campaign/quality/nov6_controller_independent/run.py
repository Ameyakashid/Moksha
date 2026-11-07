#!/usr/bin/env python3
"""Hash-bound independent controller lifecycle/keyboard reference review.
The supplied repository and candidate are read only. All Godot runs use a new
archive-based snapshot and fresh XDG paths beneath --output.
"""
from __future__ import annotations
import argparse, hashlib, io, json, os, pathlib, re, shutil, subprocess, tarfile

BASE = 'b2e7f352b96b11e9a5137145416ddeaf4a974e27'
OVERLAYS = ('campaign/logic/campaign.gd', 'campaign/input/controller_bindings.gd', 'campaign/input/gamepad_navigation.gd')
HERE = pathlib.Path(__file__).resolve().parent
DIAGNOSTICS = re.compile(r'(?m)^(?:SCRIPT ERROR:|ERROR:|WARNING:.*(?:leaked|orphan))')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def manifest(root):
    return {str(p.relative_to(root)): sha(p) for p in sorted(root.rglob('*'))
            if p.is_file() and '.godot' not in p.parts}

def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')

def invoke(command, env, logfile):
    with logfile.open('w') as handle:
        done = subprocess.run(command, env=env, stdout=handle, stderr=subprocess.STDOUT,
                              timeout=240, check=False)
    log = logfile.read_text()
    return {'command': command, 'exit_code': done.returncode,
            'diagnostics': DIAGNOSTICS.findall(log), 'log_sha256': sha(logfile)}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', type=pathlib.Path, required=True)
    parser.add_argument('--candidate', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--rates', type=int, nargs='+', default=[60, 120])
    parser.add_argument('--paired-reentry-controls', action='store_true',
                        help='Also preserve the v2-pass/v4-fail frozen helper reentry proof')
    parser.add_argument('--expect-candidate', type=pathlib.Path,
                        help='Optional JSON dictionary of exact overlay path -> SHA256')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error('--output must not exist; prior evidence is never overwritten')
    output.mkdir(parents=True)
    evidence = output / 'evidence'; evidence.mkdir()
    project = output / 'project'; project.mkdir()
    observed = {rel: sha(args.candidate / rel) for rel in OVERLAYS}
    if args.expect_candidate:
        expected = json.loads(args.expect_candidate.read_text())
        if any(observed.get(rel) != value for rel, value in expected.items()):
            raise RuntimeError('Candidate does not match the supplied expected hashes')
    archive = subprocess.check_output(['git', '-C', str(args.repository), 'archive', BASE])
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(project, filter='data')
    for rel in OVERLAYS:
        target = project / rel; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(args.candidate / rel, target)
    if observed != {rel: sha(args.candidate / rel) for rel in OVERLAYS}:
        raise RuntimeError('Candidate changed while snapshotting; no tests were run')
    if observed != {rel: sha(project / rel) for rel in OVERLAYS}:
        raise RuntimeError('Copied candidate hashes do not match')
    source = manifest(project)
    write(evidence / 'source_manifest.json', {'base_commit': BASE, 'overlays': observed,
                                             'archive_sha256': hashlib.sha256(archive).hexdigest(),
                                             'files': source})
    stage = project / 'campaign/quality/independent_multipad'; stage.mkdir(exist_ok=True)
    staged = {'review.gd': HERE/'review.gd', 'cache_lifecycle.gd': HERE/'cache_lifecycle.gd',
              'baseline_campaign.gd': HERE/'baselines/b2_campaign.gd',
              'prepass_campaign.gd': HERE/'baselines/prepass_9e_campaign.gd'}
    for name, src in staged.items(): shutil.copy2(src, stage/name)
    fixture_hashes = {name: sha(stage/name) for name in staged}
    write(evidence/'fixture_manifest.json', fixture_hashes)
    initial = manifest(project)
    env = dict(os.environ)
    for variable, folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
        path = output/'runtime'/folder; path.mkdir(parents=True); env[variable] = str(path)
    engine = subprocess.check_output([args.godot, '--version'], env=env, text=True).strip()
    (evidence/'engine.txt').write_text(engine+'\n')
    imported = invoke([args.godot,'--headless','--editor','--path',str(project),'--import'], env, evidence/'import.log')
    runs=[]
    if imported['exit_code'] != 0 or imported['diagnostics']:
        raise RuntimeError('Snapshot import failed; see evidence/import.log')
    for rate in args.rates:
        for fixture, stem in [('review.gd','review'),('cache_lifecycle.gd','cache')]:
            report=evidence/f'{stem}_{rate}.json'
            record=invoke([args.godot,'--headless','--path',str(project),'--fixed-fps',str(rate),
                           '--script',f'res://campaign/quality/independent_multipad/{fixture}','--',
                           f'--hz={rate}',f'--out={report}'],env,evidence/f'{stem}_{rate}.log')
            result=json.loads(report.read_text()) if report.exists() else {}
            record.update({'fixture':fixture,'hz':rate,'checks':result.get('checks',0),'failures':result.get('failures',[]),
                           'report_sha256':sha(report) if report.exists() else None,
                           'passed':record['exit_code']==0 and not record['diagnostics'] and result.get('passed') is True
                                    and result.get('harness_sha256')==fixture_hashes[fixture]})
            runs.append(record)
    controls=[]
    if args.paired_reentry_controls:
        for version, expected_exit, expected_after in [('v2',0,0.0),('v4',1,1.0)]:
            control_root=output/'controls'/version;control_project=control_root/'project'
            control_project.mkdir(parents=True)
            with tarfile.open(fileobj=io.BytesIO(archive)) as tar: tar.extractall(control_project,filter='data')
            helper=control_project/'campaign/input/controller_bindings.gd'
            shutil.copy2(HERE/f'baselines/{version}_controller_bindings.gd',helper)
            control_stage=control_project/'campaign/quality/independent_multipad';control_stage.mkdir(exist_ok=True)
            shutil.copy2(HERE/'reentry_held.gd',control_stage/'reentry_held.gd')
            control_before=manifest(control_project)
            write(evidence/f'{version}_control_source_manifest.json',control_before)
            control_env=dict(env)
            for variable,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
                path=control_root/'runtime'/folder;path.mkdir(parents=True);control_env[variable]=str(path)
            control_import=invoke([args.godot,'--headless','--editor','--path',str(control_project),'--import'],control_env,evidence/f'{version}_control_import.log')
            log_path=evidence/f'{version}_reentry_control.log'
            record=invoke([args.godot,'--headless','--path',str(control_project),'--fixed-fps','60',
                           '--script','res://campaign/quality/independent_multipad/reentry_held.gd'],control_env,log_path)
            markers=[line[len('REENTRY_HELD '):] for line in log_path.read_text().splitlines() if line.startswith('REENTRY_HELD ')]
            result=json.loads(markers[0]) if len(markers)==1 else {}
            control_after=manifest(control_project)
            control_drift=[rel for rel,digest in control_before.items() if control_after.get(rel)!=digest]
            record.update({'version':version,'helper_sha256':sha(helper),'fixture_sha256':sha(HERE/'reentry_held.gd'),
                           'expected_exit_code':expected_exit,'observation':result,'source_drift':control_drift,
                           'passed':record['exit_code']==expected_exit and not record['diagnostics'] and not control_drift
                                    and result.get('after_release_while_detached')==expected_after
                                    and result.get('before')==1.0 and result.get('same_name') is True
                                    and result.get('removed') is True and result.get('native_cp_right')==0.0
                                    and control_import['exit_code']==0 and not control_import['diagnostics']})
            controls.append(record)
    after=manifest(project)
    # Godot may add resource UID sidecars during import. Those new files are
    # recorded, but existing archived sources and staged fixtures must not change.
    drift=[rel for rel,digest in initial.items() if after.get(rel)!=digest]
    summary={'passed':all(r['passed'] for r in runs) and all(r['passed'] for r in controls) and not drift,'engine':engine,
             'runner_sha256':sha(pathlib.Path(__file__)), 'controls':controls,
             'base_commit':BASE,'candidate':observed,'fixture_hashes':fixture_hashes,
             'import':imported,'runs':runs,'source_drift':drift,
             'generated_files':sorted(set(after)-set(initial))}
    write(evidence/'summary.json',summary)
    print(json.dumps({'passed':summary['passed'],'checks':sum(r['checks'] for r in runs),
                      'source_drift':drift,'summary':str(evidence/'summary.json')}))
    return 0 if summary['passed'] else 1

if __name__=='__main__': raise SystemExit(main())
