#!/usr/bin/env python3
"""Reproduce paired-rate confirmed-strike target-health and review checks.

python combat_pc/tests/target_health_run.py --output-dir /tmp/moksha-health-checks
Requires installed Godot. Generated evidence never overwrites earlier reports.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = {
    "target_health": "combat_pc/tests/target_health_regression.gd",
    "target_health_review": "combat_pc/tests/target_health_review_smoke.gd",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-bin", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--output-dir", type=Path, default=ROOT / "combat_pc/tests/target_health_evidence")
    args = parser.parse_args()
    binary = shutil.which(args.godot_bin)
    if not binary:
        parser.error("Godot unavailable; provide --godot-bin /path/to/godot")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="moksha-target-health-") as directory:
        env = dict(os.environ)
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            path = Path(directory) / key
            path.mkdir()
            env[key] = str(path)
        log = output / "import.log"
        with log.open("w") as stream:
            imported = subprocess.run([binary,"--headless","--editor","--path",str(ROOT),"--quit"], stdout=stream,stderr=subprocess.STDOUT,env=env,timeout=180)
        if imported.returncode or any(marker in log.read_text() for marker in ["SCRIPT ERROR:", "\nERROR:"]):
            raise RuntimeError("Project import failed; see " + str(log))

        def run(item):
            suite, hz = item
            stem = f"{suite}_{hz}hz"
            raw = output / (stem + ".json")
            raw.unlink(missing_ok=True)
            log = output / (stem + ".log")
            command = [binary,"--headless","--fixed-fps",str(hz),"--path",str(ROOT),"--script","res://"+SCRIPTS[suite],"--",f"--hz={hz}",f"--output={raw}"]
            with log.open("w") as stream:
                process = subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,env=env,timeout=240)
            report = json.loads(raw.read_text()) if raw.is_file() else {}
            diagnostics = any(marker in log.read_text() for marker in ["SCRIPT ERROR:","\nERROR:","\nWARNING:","FAIL:"])
            passed = process.returncode == 0 and not diagnostics and bool(report) and not report.get("failures") and report.get("production_hash_stable_during_run")
            if report:
                with gzip.open(output / (stem + ".json.gz"),"wt",encoding="utf-8") as stream:
                    json.dump(report,stream,separators=(",",":"))
                raw.unlink()
            result = {"suite":suite,"physics_hz":hz,"passed":bool(passed),"exit_code":process.returncode,"diagnostics":diagnostics,
                "scenarios":len(report.get("scenarios",[])),"assertions":report.get("checks",0),"failures":report.get("failures",["No report"]),
                "source_stable":report.get("production_hash_stable_during_run",False),"trace":stem+".json.gz","log":log.name,
                "harness_sha256":hashlib.sha256((ROOT / SCRIPTS[suite]).read_bytes()).hexdigest(),"engine":report.get("engine")}
            print(f'{suite} {hz}Hz: {result["scenarios"]} scenarios, {result["assertions"]} assertions, {"PASS" if passed else "FAIL"}',flush=True)
            if not passed: print(log.read_text()[-5000:],flush=True)
            return result,report

        with ThreadPoolExecutor(max_workers=2) as pool:
            runs = list(pool.map(run,[(suite,hz) for suite in SCRIPTS for hz in [60,120]]))
    reports = {(result["suite"],result["physics_hz"]):report for result,report in runs}
    a,b = [reports[("target_health",hz)].get("paired_outcomes") for hz in [60,120]]
    paired = bool(a) and a == b
    summary = {"passed":all(result["passed"] for result,_ in runs) and paired,
        "paired_discrete_health_outcomes_equal":paired,"runs":[result for result,_ in runs],
        "limits":["Focused tests plus actual review-scene smoke; no full historical suite or rendered playtest claim.",
            "Discrete damage outcomes compared across rates. Per-frame trajectories are compared across health modes within each rate, not asserted identical across rates."]}
    (output / "target_health_run_summary.json").write_text(json.dumps(summary,indent=2)+"\n")
    print("Paired discrete health outcomes:","PASS" if paired else "FAIL",flush=True)
    return 0 if summary["passed"] else 1

if __name__ == "__main__":
    sys.exit(main())
