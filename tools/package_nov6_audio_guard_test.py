#!/usr/bin/env python3
"""Exercise the three audio-fixture output guards without writing probe paths."""
import argparse
import importlib.util
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package_nov6", Path(__file__).with_name("package_nov6.py"))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)

HARNESS = '''extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label)
func _initialize()->void:
    var source_root:=ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
    check(not source_root.is_empty(),"negative test has a real physical source root")
    for name in ["contract.gd","event_routing.gd","rejected_noise.gd"]:
        var script=load("res://campaign/quality/nov6_audio/"+name)
        var cases=[
            {"path":"res://must-not-write.json","root":source_root,"allowed":false,"label":"res scheme rejected"},
            {"path":source_root+"/must-not-write.json","root":source_root,"allowed":false,"label":"real source child rejected"},
            {"path":source_root,"root":source_root,"allowed":false,"label":"source root itself rejected"},
            {"path":source_root+"/nested/../must-not-write.json","root":source_root,"allowed":false,"label":"normalized source child rejected"},
            {"path":"relative-result.json","root":source_root,"allowed":false,"label":"relative path rejected"},
            {"path":source_root+"-separate-results/result.json","root":source_root,"allowed":true,"label":"similarly named sibling accepted"},
            {"path":"user://nov6_audio/result.json","root":source_root,"allowed":true,"label":"isolated user data accepted"},
            {"path":"user://nov6_audio/result.json","root":"","allowed":true,"label":"packed empty root accepts user data"},
            {"path":"/tmp/moksha-audio-guard/result.json","root":"","allowed":true,"label":"packed empty root accepts absolute report"},
            {"path":"res://must-not-write.json","root":"","allowed":false,"label":"packed res scheme still rejected"},
            {"path":"relative-result.json","root":"","allowed":false,"label":"packed relative path still rejected"},
            {"path":"/tmp/must-not-write.json","root":"/","allowed":false,"label":"filesystem-root project is not an empty root"}
        ]
        for example in cases:
            check(script.report_output_allowed(example.path,example.root)==example.allowed,name+": "+example.label)
    print("NOV6_PACKAGING_AUDIO_GUARD_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_root":source_root,"scope":"Read-only predicate negative controls on all three actual audio fixture guards; no probe path is written."}))
    quit(0 if failures.is_empty() else 1)
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    script = output / "output_guard_negative.gd"
    script.write_text(HARNESS)
    engine = shutil.which("godot") or "godot"
    package.command_check("audio_output_guard_negative", [engine, "--headless", "--path", str(ROOT), "--script", str(script)],
                          ROOT, package.isolated_environment(output, "isolated"), output,
                          "NOV6_PACKAGING_AUDIO_GUARD_RESULT ", result_prefix="NOV6_PACKAGING_AUDIO_GUARD_RESULT ")


if __name__ == "__main__":
    main()
