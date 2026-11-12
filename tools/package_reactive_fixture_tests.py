#!/usr/bin/env python3
"""Source-only new release fixture matrix and path controls; does not export."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package_nov6", ROOT / "tools/package_nov6.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
HARNESS = 'extends SceneTree\nvar failures:Array[String]=[]\nvar checks:=0\nfunc _initialize()->void:\n\tfor path in ["res://campaign/quality/nov12_run_history/store_contract.gd","res://campaign/quality/nov12_run_history/lifecycle_contract.gd","res://campaign/quality/nov12_reactive_integration.gd"]:\n\t\tvar script=load(path)\n\t\tfor row in [["/tmp/moksha-fresh", "/",false],["/tmp/moksha-fresh", "",true],["/tmp/moksha-fresh","/tmp/source",true],["/tmp/source/child","/tmp/source",false],["/tmp/source","/tmp/source",false],["/tmp/source-sibling","/tmp/source",true],["/tmp/a/../outside","",false],["relative","",false],["res://data","",false],["user://data","",false],["","",false]]:\n\t\t\tchecks+=1\n\t\t\tif script.valid_fixture_root(row[0],row[1])!=row[2]:failures.append(path+" "+str(row))\n\tprint("PACKAGING_PATH_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))\n\tquit(0 if failures.is_empty() else 1)\n'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error("output must be outside source")
    output.mkdir(parents=True, exist_ok=False)
    script = output / "path_contract.gd"
    script.write_text(HARNESS)
    engine = shutil.which("godot") or "godot"
    results = []
    with tempfile.TemporaryDirectory(prefix="moksha-reactive-source-", dir="/tmp") as temporary:
        for hz in package.PACKED_TEST_RATES:
            for name, relative, prefix, needs_root in package.REACTIVE_RECEIPT_FIXTURES:
                label = f"{name}_{hz}"
                command = [engine, "--headless", "--fixed-fps", str(hz), "--path", str(ROOT),
                           "--script", str(ROOT / relative), "--", f"--hz={hz}"]
                if needs_root:
                    command.append("--root=" + str(Path(temporary) / label))
                results.append(package.command_check(label, command, ROOT,
                    package.isolated_environment(output / "isolated", label), output, result_prefix=prefix))
        results.append(package.command_check("path_negative", [engine, "--headless", "--path", str(ROOT),
            "--script", str(script)], ROOT, package.isolated_environment(output / "isolated", "path_negative"),
            output, result_prefix="PACKAGING_PATH_RESULT "))
    (output / "summary.json").write_text(json.dumps({"passed": all(r["passed"] for r in results),
        "scope": "Source-only fixture wiring and pure path controls; no PCK exported or tested", "checks": results}, indent=2))

if __name__ == "__main__":
    main()
