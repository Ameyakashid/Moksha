"""Portable M20 actual-physics tests and preserved-v23 compatibility checks.

Usage: python combat_pc/tests/combo_response_run.py --baseline-zip /path/to/v23.zip
The old combo/held harnesses run on both the archive and current controller.
The focused harness runs on current code. Only result destinations are redirected.
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
import zipfile

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / "combat_pc/tests"
PIN = "51365050b5e1086a94290aa7629b3e07a4f31dffcc63964ba05b0882de0e2ad6"
ALLOWED = {"combat_pc/player.gd", "combat_pc/resources/melee_chain.gd", "combat_pc/reference/generate_parameter_ledger.py", "tools/package_project.py"}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def audit(archive, output):
    rows = {}
    with zipfile.ZipFile(archive) as zipped:
        for name in zipped.namelist():
            relative = name.removeprefix("MOKSHA/")
            if not relative.endswith((".gd", ".tres", ".tscn", ".py")):
                continue
            source = digest(zipped.read(name))
            path = ROOT / relative
            current = digest(path.read_bytes()) if path.is_file() else None
            rows[relative] = {"v23_sha256": source, "current_sha256": current, "unchanged": source == current, "allowed_change": relative in ALLOWED}
    bad = [path for path, row in rows.items() if not row["unchanged"] and not row["allowed_change"]]
    result = {"baseline_version": 23, "baseline_zip_sha256": PIN, "checked_original_sources": len(rows), "unchanged_original_sources": sum(row["unchanged"] for row in rows.values()), "changed_sources": [path for path, row in rows.items() if not row["unchanged"]], "unexpected_changes": bad, "sources": rows}
    (output / "combo_response_baseline_hashes.json").write_text(json.dumps(result, indent=2) + "\n")
    if bad:
        raise RuntimeError("Unexpected changes to preserved original sources: " + ", ".join(bad))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-zip", type=Path, required=True, help="Retained v23 ZIP, checked against pinned SHA-256")
    parser.add_argument("--godot-bin", default=os.environ.get("GODOT_BIN", "godot"), help="Godot executable path or PATH command")
    parser.add_argument("--suites", nargs="+", choices=["focused", "comparison", "combo", "held", "current_combo", "current_held"], default=["focused", "comparison", "combo", "held", "current_combo", "current_held"])
    parser.add_argument("--hz", nargs="+", choices=[60, 120], type=int, default=[60, 120])
    parser.add_argument("--output-dir", type=Path, default=HERE)
    args = parser.parse_args()
    archive = args.baseline_zip.expanduser().resolve()
    if not archive.is_file() or digest(archive.read_bytes()) != PIN:
        parser.error("Baseline ZIP must match the retained v23 SHA-256")
    binary = shutil.which(args.godot_bin)
    if binary is None:
        parser.error("Godot executable is unavailable; supply --godot-bin /path/to/godot")
    output = args.output_dir.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    before_audit = audit(archive, output)
    with tempfile.TemporaryDirectory(prefix="moksha-m20-response-") as temporary:
        temp = Path(temporary)
        env = dict(os.environ)
        for key, directory in [("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config")]:
            (temp / directory).mkdir()
            env[key] = str(temp / directory)
        baseline_root = temp / "baseline/MOKSHA"
        if any(suite in args.suites for suite in ["combo", "held"]):
            with zipfile.ZipFile(archive) as zipped:
                for member in zipped.infolist():
                    target = (temp / "baseline" / member.filename).resolve()
                    if not target.is_relative_to((temp / "baseline").resolve()):
                        raise RuntimeError("Unsafe archive member")
                zipped.extractall(temp / "baseline")
            import_log = output / "combo_response_baseline_import.log"
            with import_log.open("w") as stream:
                result = subprocess.run([binary, "--headless", "--editor", "--path", str(baseline_root), "--quit"], env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
            if result.returncode or "SCRIPT ERROR:" in import_log.read_text():
                raise RuntimeError("Baseline project import failed; see " + str(import_log))

        def run(job):
            suite, hz = job
            historical = suite in ["combo", "held"]
            compatibility = historical or suite in ["current_combo", "current_held"]
            original_suite = suite.removeprefix("current_")
            project = baseline_root if historical else ROOT
            label = "baseline_" + suite if historical else suite
            stem = f"combo_response_{label}_{hz}hz"
            log_path = output / (stem + ".log")
            input_script = project / f"combat_pc/tests/{original_suite}_regression.gd" if compatibility else HERE / "combo_response_regression.gd"
            source = input_script.read_bytes()
            command_args = [f"--hz={hz}"]
            if compatibility:
                old = f'res://combat_pc/tests/{original_suite}_results_%dhz.json'
                new = f'res://combat_pc/tests/{stem}_results_%dhz.json'
                text = source.decode()
                if text.count(old) != 1:
                    raise RuntimeError("Unexpected historical output expression")
                redirected = text.replace(old, new)
                script = temp / f"{stem}_redirected.gd"
                script.write_text(redirected)
                report_path = project / f"combat_pc/tests/{stem}_results_{hz}hz.json"
            else:
                script = input_script
                variant = "candidate" if suite == "focused" else "baseline"
                report_path = HERE / f"combo_response_{variant}_results_{hz}hz.json"
                if suite == "comparison":
                    command_args.append("--chain=res://combat_pc/resources/light_chain.tres")
                redirected = source.decode()
            report_path.unlink(missing_ok=True)
            command = [binary, "--headless", "--fixed-fps", str(hz), "--path", str(project), "--script", str(script), "--", *command_args]
            with log_path.open("w") as stream:
                process = subprocess.run(command, env=env, cwd=project, stdout=stream, stderr=subprocess.STDOUT, timeout=240)
            log_text = log_path.read_text()
            diagnostics = any(marker in log_text for marker in ["SCRIPT ERROR:", "\nERROR:", "\nWARNING:", "FAIL:"])
            report = json.loads(report_path.read_text()) if report_path.is_file() else {}
            passed = process.returncode == 0 and not diagnostics and bool(report) and not report.get("failures") and report.get("production_hash_stable_during_run")
            trace_name = stem + ".json.gz"
            if report:
                with gzip.open(output / trace_name, "wt", encoding="utf-8") as target:
                    json.dump(report, target, separators=(",", ":"))
            provenance = {"original_harness_sha256": digest(source), "executed_harness_sha256": digest(redirected.encode()), "redirect_only": compatibility, "controller_origin": "preserved v23 archive" if historical else "current project", "controller_sha256": digest((project / "combat_pc/player.gd").read_bytes()), "harness_still_unchanged": digest(input_script.read_bytes()) == digest(source)}
            if historical:
                with zipfile.ZipFile(archive) as zipped:
                    provenance["controller_matches_v23"] = digest(zipped.read("MOKSHA/combat_pc/player.gd")) == provenance["controller_sha256"]
                    provenance["harness_matches_v23"] = digest(zipped.read(f"MOKSHA/combat_pc/tests/{suite}_regression.gd")) == provenance["original_harness_sha256"]
            if suite in ["current_combo", "current_held"]:
                previous = output / f"combo_response_baseline_{original_suite}_{hz}hz.json.gz"
                if previous.is_file():
                    with gzip.open(previous, "rt", encoding="utf-8") as stream:
                        archived = json.load(stream)
                    outcomes = lambda data: [(case["name"], case["checks"], case["failures"], [row["passed"] for row in case["assertions"]]) for case in data.get("scenarios", [])]
                    provenance["matches_archived_named_scenario_outcomes"] = outcomes(report) == outcomes(archived)
                    passed = passed and provenance["matches_archived_named_scenario_outcomes"]
                else:
                    provenance["matches_archived_named_scenario_outcomes"] = None
            result = {"suite": suite, "physics_hz": hz, "passed": bool(passed), "exit_code": process.returncode, "diagnostics": diagnostics, "scenarios": len(report.get("scenarios", [])), "assertions": report.get("checks", 0), "failures": report.get("failures", ["No result file"]), "source_stable": report.get("production_hash_stable_during_run", False), "trace": trace_name, "log": log_path.name, "provenance": provenance}
            (output / (stem + "_summary.json")).write_text(json.dumps(result, indent=2) + "\n")
            if report_path.is_file() and report and compatibility:
                report_path.unlink()
            print(f'{label} {hz} Hz: {result["scenarios"]} scenarios, {"PASS" if passed else "FAIL"}', flush=True)
            if not passed:
                print(log_text[-5000:], flush=True)
            return result

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(run, [(suite, hz) for suite in args.suites for hz in args.hz]))
    after_audit = audit(archive, output)
    stable = before_audit["sources"] == after_audit["sources"]
    summary = {"baseline_zip_sha256": PIN, "selected_suites": args.suites, "selected_hz": args.hz, "source_audit_stable_during_batch": stable, "runs": results, "passed": stable and all(result["passed"] for result in results)}
    (output / "combo_response_run_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
