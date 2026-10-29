"""Reproduce M21 focused real-physics checks and pinned v24 source audit.

python combat_pc/tests/knockback_response_run.py --baseline-zip /path/to/v24.zip
Requires Godot 4.6.3. Frame samples are evidence, never independent test cases.
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
PIN = "48752e6b00f630937360772799bac58b2af9527d9146185c592f6faa439ff6bd"
ALLOWED = {"combat_pc/reference/generate_parameter_ledger.py", "tools/package_project.py", "project.godot"}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def audit(archive, output):
    rows = {}
    with zipfile.ZipFile(archive) as zipped:
        for name in zipped.namelist():
            relative = name.removeprefix("MOKSHA/")
            if not relative.endswith((".gd", ".tres", ".tscn", ".py", "project.godot")):
                continue
            original = digest(zipped.read(name))
            path = ROOT / relative
            current = digest(path.read_bytes()) if path.is_file() else None
            rows[relative] = {"v24_sha256": original, "current_sha256": current, "unchanged": original == current, "allowed_host_change": relative in ALLOWED}
    bad = [path for path, row in rows.items() if not row["unchanged"] and not row["allowed_host_change"]]
    result = {"baseline_version": 24, "baseline_zip_sha256": PIN, "checked_original_sources": len(rows), "unchanged_original_sources": sum(row["unchanged"] for row in rows.values()), "changed_sources": [path for path, row in rows.items() if not row["unchanged"]], "unexpected_changes": bad, "sources": rows, "passed": not bad}
    (output / "knockback_response_baseline_hashes.json").write_text(json.dumps(result, indent=2) + "\n")
    if bad:
        raise RuntimeError("Unexpected changes to preserved v24 sources: " + ", ".join(bad))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-zip", type=Path, required=True)
    parser.add_argument("--godot-bin", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--hz", nargs="+", type=int, choices=[60, 120], default=[60, 120])
    parser.add_argument("--output-dir", type=Path, default=HERE)
    args = parser.parse_args()
    archive = args.baseline_zip.expanduser().resolve()
    if not archive.is_file() or digest(archive.read_bytes()) != PIN:
        parser.error("Baseline ZIP must match the retained v24 SHA-256")
    binary = shutil.which(args.godot_bin)
    if binary is None:
        parser.error("Godot unavailable; supply --godot-bin /path/to/godot")
    output = args.output_dir.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    before = audit(archive, output)
    with tempfile.TemporaryDirectory(prefix="moksha-m21-knockback-") as directory:
        temporary = Path(directory)
        env = dict(os.environ)
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            (temporary / key).mkdir()
            env[key] = str(temporary / key)
        import_log = output / "knockback_response_import.log"
        with import_log.open("w") as stream:
            imported = subprocess.run([binary, "--headless", "--editor", "--path", str(ROOT), "--quit"], stdout=stream, stderr=subprocess.STDOUT, env=env, timeout=180)
        if imported.returncode or any(marker in import_log.read_text() for marker in ["SCRIPT ERROR:", "\nERROR:"]):
            raise RuntimeError("Project import failed; see " + str(import_log))

        def run(hz):
            stem = f"knockback_response_{hz}hz"
            log = output / (stem + ".log")
            report_path = HERE / f"knockback_response_results_{hz}hz.json"
            report_path.unlink(missing_ok=True)
            command = [binary, "--headless", "--fixed-fps", str(hz), "--path", str(ROOT), "--script", "res://combat_pc/tests/knockback_response_regression.gd", "--", f"--hz={hz}"]
            with log.open("w") as stream:
                process = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, env=env, timeout=240)
            diagnostic = any(marker in log.read_text() for marker in ["SCRIPT ERROR:", "\nERROR:", "\nWARNING:", "FAIL:"])
            report = json.loads(report_path.read_text()) if report_path.is_file() else {}
            passed = process.returncode == 0 and not diagnostic and bool(report) and not report.get("failures") and report.get("production_hash_stable_during_run")
            trace = stem + ".json.gz"
            if report:
                with gzip.open(output / trace, "wt", encoding="utf-8") as stream:
                    json.dump(report, stream, separators=(",", ":"))
            result = {"physics_hz": hz, "passed": bool(passed), "exit_code": process.returncode, "diagnostics": diagnostic, "scenarios": len(report.get("scenarios", [])), "assertions": report.get("checks", 0), "failures": report.get("failures", ["No result file"]), "source_stable": report.get("production_hash_stable_during_run", False), "trace": trace, "log": log.name, "harness_sha256": digest((HERE / "knockback_response_regression.gd").read_bytes()), "controller_sha256": digest((ROOT / "combat_pc/player.gd").read_bytes()), "engine": report.get("engine")}
            (output / (stem + "_summary.json")).write_text(json.dumps(result, indent=2) + "\n")
            print(f'{hz} Hz: {result["scenarios"]} scenarios, {result["assertions"]} assertions, {"PASS" if passed else "FAIL"}', flush=True)
            if not passed:
                print(log.read_text()[-8000:], flush=True)
            if report_path.is_file():
                report_path.unlink()
            return result

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(run, args.hz))
    after = audit(archive, output)
    protected = lambda value: {path: row for path, row in value["sources"].items() if not row["allowed_host_change"]}
    stable = protected(before) == protected(after)
    summary = {"milestone": 21, "baseline_zip_sha256": PIN, "selected_hz": args.hz, "protected_source_audit_stable_during_batch": stable, "runs": results, "passed": stable and all(row["passed"] for row in results), "limits": ["Focused passive target acceptance only; no NPC AI, broad moving-platform or full controller-suite rerun claimed.", "Existing controller and adapters are checked byte-for-byte against v24; actual combo contacts are exercised in the new suite."]}
    (output / "knockback_response_run_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
