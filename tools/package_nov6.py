#!/usr/bin/env python3
"""Build portable MOKSHA archives from one immutable, explicitly frozen Git commit.

No network, source edits, template installs, or upload occurs here. A verified
prior Windows package supplies its unchanged official 4.6.3 release runtime.
Godot imports a separate stage and exports a new text-script PCK. Checks run
against that PCK from a directory with no loose game resources, and again after
extracting the finished Windows archive. Linux delivery optionally includes the
installed official engine binary and a game-mode launcher, not an installer.
Source delivery includes a complete editable-source ZIP, a separate full-history
ZIP, and a canonical combined archive. No source/tests/docs are omitted for size.

Example (only after the source owner declares a freeze):
  python3 tools/package_nov6.py --source-commit COMMIT --output NEW_DIRECTORY \
    --windows-archive /absolute/MOKSHA-Windows-x64-9e22722.zip --with-linux

--rehearsal validates a candidate without producing delivery ZIPs or a bundle.
Every output directory must be new; historical deliveries are never replaced.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import shlex
import shutil
import stat
import sys
import subprocess
import tarfile
import tempfile
import time
from urllib.parse import unquote, urlsplit
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_WINDOWS_ZIP_SHA256 = "88ef3a4ea5a7379135207fb6fb308dd38e06cb0fddd086825ffdc92ba8b77541"
# Both delivered archives contain the same byte-verified official runtime.
# The November 6 archive was recovered from Library and CRC/runtime-checked
# on November 12. Unknown archives still fail closed; executable validation
# below remains independent of this allowlist.
TRUSTED_WINDOWS_ARCHIVES = {
    EXPECTED_WINDOWS_ZIP_SHA256: "9e22722",
    "c7b900b7e82d41020bd6c7e5d96dc62285dd42872ecddec67926c09d72e06126": "c73159b",
}
EXPECTED_WINDOWS_EXE_SHA256 = "91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6"
EXPECTED_ENGINE = "4.6.3.stable.official.7d41c59c4"
SMALL_ATTACHMENT_LIMIT = 18 * 1024 * 1024
EXCLUDED_PARTS = {
    ".git", ".godot", "__pycache__", "tests", "enemy_tests", "qa_audit",
    "route_tests", "route_tests_45", "evidence", "docs", "quality", "reference",
    "native_visual_fixture", "historical_foundation", "history",
}
EXCLUDED_ROOTS = {
    "tools", "export_templates", "feature_profiles", "script_templates",
    "text_editor_themes", "delivery", "art_sources", "pc",
}
RUNTIME_SUFFIXES = {
    ".gd", ".uid", ".tscn", ".scn", ".tres", ".res", ".gdshader", ".gdshaderinc",
    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".wav", ".ogg", ".mp3",
    ".ttf", ".otf", ".json", ".import", ".glb", ".gltf", ".obj", ".mtl",
}
ERROR_PATTERN = re.compile(r"^\s*(?:SCRIPT ERROR:|ERROR:|FAIL\b)", re.MULTILINE)
PACKED_TEST_RATES = (60, 120)
# Every receipt fixture is copied from the frozen Git snapshot, kept outside
# the PCK, and validated by result_receipt rather than a success substring.
RECEIPT_FIXTURES = (
    ("gamepad_navigation", "campaign/quality/nov6_gamepad_navigation.gd", "NOV6_GAMEPAD_NAVIGATION_RESULT "),
    ("independent_controller", "campaign/quality/nov6_independent_controller.gd", "NOV6_INDEPENDENT_CONTROLLER "),
    ("controller_devices", "campaign/quality/nov6_controller_devices.gd", "NOV6_CONTROLLER_DEVICES_RESULT "),
    ("paused_release", "campaign/quality/nov6_independent_paused_release.gd", "NOV6_INDEPENDENT_PAUSED_RELEASE "),
    ("runtime_lifecycle", "campaign/quality/nov6_runtime_lifecycle.gd", "NOV6_RUNTIME_LIFECYCLE_RESULT "),
    ("input_guidance", "campaign/quality/nov6_input_guidance.gd", "NOV6_INPUT_GUIDANCE_RESULT "),
    ("audio_contract", "campaign/quality/nov6_audio/contract.gd", "NOV6_AUDIO_CONTRACT_RESULT "),
    ("audio_routing", "campaign/quality/nov6_audio/event_routing.gd", "NOV6_AUDIO_ROUTING_RESULT "),
    ("audio_rejected_noise", "campaign/quality/nov6_audio/rejected_noise.gd", "NOV6_AUDIO_REJECTED_NOISE_RESULT "),
)


# Additional milestone gates; legacy31 checks below remain unchanged.
REACTIVE_RECEIPT_FIXTURES = (
    ("history_store", "campaign/quality/nov12_run_history/store_contract.gd", "RUN_HISTORY_STORE_RESULT ", True),
    ("history_lifecycle", "campaign/quality/nov12_run_history/lifecycle_contract.gd", "RUN_LIFECYCLE_RESULT ", True),
    ("companion_director", "campaign/quality/nov12_companion_contract.gd", "COMPANION_CONTRACT_RESULT ", False),
    ("companion_observer", "campaign/quality/nov12_companion_observer_contract.gd", "OBSERVER_FIXTURE_RESULT ", False),
    ("reactive_integration", "campaign/quality/nov12_reactive_integration.gd", "REACTIVE_INTEGRATION_RESULT ", True),
)

# Single executions at the fixtures' authored default cadence. Camera checks
# explicitly integrate both 60/120 trajectories internally; do not fake --hz.
HEARING_RECEIPT_FIXTURES = (
    ("hearing_schema", "simulation/tests/hearing_persistence_schema.gd", False),
    ("hearing_host", "campaign/quality/hearing_host_contract.gd", True),
    ("hearing_perception", "campaign/quality/hearing_perception_contract.gd", False),
    ("hearing_load_boundary", "campaign/quality/hearing_load_boundary_contract.gd", False),
    ("hearing_copy", "campaign/quality/hearing_copy_contract.gd", False),
)


def externalize_camera_contract(contract: Path, baseline: Path, destination: Path) -> dict:
    original = contract.read_text(encoding="utf-8")
    old = 'preload("res://campaign/quality/nov12_fall_framing/baseline.gd")'
    require(original.count(old) == 1, "Camera dependency must match exactly once")
    require(not destination.exists(), "Camera adapter destination must be fresh")
    destination.mkdir(parents=True)
    copied = destination / "baseline.gd"
    shutil.copy2(baseline, copied)
    adapted = destination / "contract.gd"
    adapted.write_text(original.replace(old, 'preload("baseline.gd")'), encoding="utf-8")
    return {"script": str(adapted), "original_sha256": sha(contract),
            "adapted_sha256": sha(adapted), "baseline_sha256": sha(copied),
            "adaptation": "Only QA baseline preload relocated to external sibling; runtime camera remains res://"}


PRESET = '''[preset.0]
name="Portable PCK"
platform="Linux"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json"
exclude_filter=""
export_path=""
script_export_mode=0

[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
'''

PACK_AUDIT = '''extends SceneTree
var failures:Array[String]=[]
var scripts_checked:=0
var resources_checked:=0
func check(ok:bool,label:String)->void:
    if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
    check(FileAccess.get_sha256("res://BUILD_PROVENANCE.json")=="@PROVENANCE_SHA@","embedded provenance bytes")
    var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://BUILD_PROVENANCE.json"))
    if not provenance is Dictionary:
        push_error("PACK_AUDIT missing provenance");quit(1);return
    check(provenance.source_commit=="@SOURCE_COMMIT@","frozen commit")
    for path in provenance.production_sha256:
        var uri="res://"+str(path)
        if str(path).ends_with(".gd"):
            check(FileAccess.get_sha256(uri)==provenance.production_sha256[path],"script hash "+str(path))
            scripts_checked+=1
        if str(path).ends_with(".tscn") or str(path).ends_with(".tres") or str(path).ends_with(".gdshader"):
            check(ResourceLoader.exists(uri) and ResourceLoader.load(uri)!=null,"resource loads "+str(path))
            resources_checked+=1
    for path in ["res://campaign/tests/campaign_smoke.gd", "res://campaign/quality/nov6_gamepad_navigation.gd", "res://campaign/quality/nov6_independent_controller.gd", "res://campaign/quality/nov6_controller_devices.gd"]:
        check(not FileAccess.file_exists(path),"developer fixture excluded "+path)
    var packed=load("res://campaign/campaign.tscn")
    if packed==null:
        push_error("PACK_AUDIT missing main scene");quit(1);return
    var host=packed.instantiate()
    host.save_enabled=false
    root.add_child(host)
    host.start_new(true)
    host.input_override={}
    var levels:Dictionary={}
    var districts:int=host.sectors.size()
    check(districts==32,"all 32 authored districts")
    for i in districts:
        host.load_sector(i)
        await physics_frame
        await process_frame
        levels[int(host.sectors[i].level)]=true
        check(is_instance_valid(host.player),"district player "+str(i))
        check(is_instance_valid(host.art),"district scenery "+str(i))
        check(is_instance_valid(host.actor_paint),"district actor paint "+str(i))
        check(is_instance_valid(host.object_paint),"district object paint "+str(i))
        check(host.player.get_node("BodyShape/IncomingStrikeReceiver")._health()==host.health,"district Health binding "+str(i))
    check(levels.size()==5,"five level data sets")
    host.state="choice"
    host.choose_sight(true)
    check(host.blind and host.sonar.blind,"real sight trade")
    check(not host.art.visible and not host.actor_paint.operative.visible,"sight trade hides presentation")
    host.load_sector(0)
    await process_frame
    check(not host.art.visible and not host.actor_paint.operative.visible,"sight trade survives district reload")
    host.start_new(true)
    await process_frame
    check(not host.blind and host.art.visible and host.actor_paint.operative.visible,"new run restores sight")
    host.queue_free()
    await process_frame
    var result={"source_commit":provenance.source_commit,"districts":districts,"levels":levels.size(),"script_hashes_checked":scripts_checked,"resources_loaded":resources_checked,"failures":failures}
    print("PACK_AUDIT_RESULT "+JSON.stringify(result))
    if failures.is_empty():print("PACK_AUDIT_PASS")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
'''

NATIVE_WRAPPER = '''extends SceneTree
const FIXTURE_PATH = @FIXTURE_PATH@
const FIXTURE_SHA = @FIXTURE_SHA@
const PROVENANCE_SHA = @PROVENANCE_SHA@
const SOURCE_COMMIT = @SOURCE_COMMIT@
func _initialize()->void:call_deferred("start")
func start()->void:
    var failures:Array[String]=[]
    if FileAccess.get_sha256(FIXTURE_PATH)!=FIXTURE_SHA:failures.append("external native fixture hash mismatch")
    if FileAccess.get_sha256("res://BUILD_PROVENANCE.json")!=PROVENANCE_SHA:failures.append("packed provenance mismatch")
    if FileAccess.file_exists("res://campaign/quality/nov6_native_review.gd"):failures.append("native fixture must not be a loose or packed runtime resource")
    for arg in OS.get_cmdline_user_args():
        if arg in ["--capture-ui","--capture-all"] and DisplayServer.get_name()=="headless":failures.append("native capture requires a real renderer")
    if not failures.is_empty():
        for failure in failures:push_error(failure)
        quit(1);return
    var fixture_script=load(FIXTURE_PATH)
    if fixture_script==null:
        push_error("Could not load frozen external native fixture");quit(1);return
    var fixture=fixture_script.new()
    if not fixture is Node:
        push_error("Frozen native fixture is not a Node");quit(1);return
    root.add_child(fixture)
    print("PACKED_NATIVE_WRAPPER_READY "+JSON.stringify({"passed":true,"checks":4,"failures":[],"source_commit":SOURCE_COMMIT,"fixture_sha256":FIXTURE_SHA,"display_server":DisplayServer.get_name(),"scope":"Frozen external native fixture, production resources from verified PCK; controlled visual fixtures, not a route or Windows test."}))
'''


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def portable_build_report(report: dict, *, build: Path, source: Path,
                          godot: Path, receipts: Path) -> dict:
    """Copy public metadata with portable paths; never change raw test receipts.

    Only known local path values (including command arguments) are normalized.
    This is presentation, not redaction of arbitrary secrets or runnable commands.
    Longest roots win so the frozen source and sibling receipts keep their labels.
    """
    replacements = sorted(((str(build), "$BUILD"), (str(source), "$SOURCE"),
                           (str(godot), "$GODOT"), (str(receipts), "$RECEIPTS")),
                          key=lambda item: len(item[0]), reverse=True)

    def copy_value(value, command_argument=False):
        if isinstance(value, dict):
            return {key: copy_value(item, key == "command" and isinstance(item, list))
                    for key, item in value.items()}
        if isinstance(value, list):
            return [copy_value(item, command_argument) for item in value]
        if isinstance(value, str):
            if command_argument:
                # Only our owned temporary fixture-root argument; not arbitrary
                # /tmp paths, prose, command strings or unrelated root options.
                match = re.fullmatch(
                    r"--root=/tmp/moksha-packed-reactive-[A-Za-z0-9_-]+/"
                    r"((?:history_store|history_lifecycle|reactive_integration)_(?:60|120))", value)
                if match:
                    return "--root=$FIXTURE_ROOT/" + match.group(1)
            for local, label in replacements:
                # Do not rewrite unrelated prefix siblings, e.g. build-old.
                pattern = re.escape(local) + r"(?=$|[/\\\s\"'<>),;])"
                value = re.sub(pattern, lambda _match: label, value)
        return value

    result = copy_value(report)
    result["path_format_note"] = (
        "Local execution paths use explanatory placeholders: $BUILD is the "
        "packaging workspace, $SOURCE the frozen source checkout, $GODOT the "
        "Godot executable, $RECEIPTS the external fixture receipt directory, and "
        "$FIXTURE_ROOT an owned temporary reactive-fixture directory. "
        "Test results and original log hashes are retained. Raw external reports "
        "are unchanged; these labels are not runnable shell commands."
    )
    return result


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def included_runtime(relative: Path) -> bool:
    if relative.name in {"moksha_five_levels_v1.json", "moksha_five_levels_results.json"} or "moksha_run_history" in relative.parts:
        return False  # User data is never a runtime resource; source/history archives remain complete.
    return not (EXCLUDED_PARTS.intersection(relative.parts) or relative.parts[0] in EXCLUDED_ROOTS) and (
        relative.name == "project.godot" or relative.suffix in RUNTIME_SUFFIXES
    ) and not relative.name.endswith("_pixels.tscn")


def safe_member(name: str) -> bool:
    path = PurePosixPath(name)
    return bool(name) and not path.is_absolute() and ".." not in path.parts and "\\" not in name


def extract_zip(archive: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=False)
    with zipfile.ZipFile(archive) as zipped:
        require(zipped.testzip() is None, f"ZIP CRC failure: {archive}")
        require(len(zipped.namelist()) == len(set(zipped.namelist())), "Duplicate ZIP members")
        for member in zipped.infolist():
            require(safe_member(member.filename), f"Unsafe ZIP path: {member.filename}")
            mode = member.external_attr >> 16
            require(not stat.S_ISLNK(mode), f"Unexpected archive link: {member.filename}")
        zipped.extractall(destination)
        for member in zipped.infolist():
            if not member.is_dir() and member.external_attr >> 16:
                (destination / member.filename).chmod((member.external_attr >> 16) & 0o777)


def snapshot(commit: str, destination: Path) -> dict[str, str]:
    destination.mkdir(parents=True, exist_ok=False)
    result = subprocess.run(["git", "archive", "--format=tar", commit], cwd=ROOT, capture_output=True, check=True)
    with tarfile.open(fileobj=io.BytesIO(result.stdout)) as archive:
        for member in archive.getmembers():
            require(safe_member(member.name) and (member.isfile() or member.isdir()), f"Unsupported Git archive entry: {member.name}")
        archive.extractall(destination, filter="data")
    return {p.relative_to(destination).as_posix(): sha(p) for p in sorted(destination.rglob("*")) if p.is_file()}


def isolated_environment(parent: Path, name: str) -> dict[str, str]:
    env = dict(os.environ, MOKSHA_QUALITY_ISOLATED="1")
    for key in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        path = parent / name / key
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    return env


def prepare_native_review(output: Path, engine: Path, pack: Path, fixture: Path,
                          fixture_sha256: str, provenance_sha256: str, commit: str) -> dict:
    """Prepare, but never launch, the parent's real-renderer capture session."""
    require(sha(fixture) == fixture_sha256, "Native-review fixture differs from frozen Git source")
    native = output / "native-review"
    native.mkdir()
    empty = native / "empty-resources"
    empty.mkdir()
    captures = native / "captures"
    captures.mkdir()
    wrapper = native / "native_review_wrapper.gd"
    text = NATIVE_WRAPPER
    for key, value in {"FIXTURE_PATH": str(fixture), "FIXTURE_SHA": fixture_sha256,
                       "PROVENANCE_SHA": provenance_sha256, "SOURCE_COMMIT": commit}.items():
        text = text.replace("@" + key + "@", json.dumps(value))
    wrapper.write_text(text, encoding="utf-8")
    command = [str(engine), "--display-driver", "x11", "--rendering-method", "gl_compatibility",
               "--audio-driver", "Dummy", "--disable-vsync", "--path", str(empty),
               "--main-pack", str(pack), "--script", str(wrapper), "--", "--capture-ui", "--output=" + str(captures)]
    env = isolated_environment(output / "isolated", "native_capture")
    launcher = native / "Start-native-review.sh"
    lines = ["#!/bin/sh", "set -eu"]
    for key in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        lines.append("export " + key + "=" + shlex.quote(env[key]))
    lines += ["EMPTY=" + shlex.quote(str(empty)), "CAPTURES=" + shlex.quote(str(captures)),
              'if [ -n "$(ls -A "$EMPTY")" ]; then echo "Native resource directory is not empty." >&2; exit 1; fi',
              'if [ -n "$(ls -A "$CAPTURES")" ]; then echo "Capture files already exist. Preserve them and choose a new capture directory." >&2; exit 1; fi',
              'cd "$EMPTY"', "exec " + shlex.join(command)]
    launcher.write_text("\n".join(lines) + "\n", encoding="utf-8")
    launcher.chmod(0o755)
    report = {"source_commit": commit, "fixture": str(fixture), "fixture_sha256": fixture_sha256,
              "wrapper": str(wrapper), "wrapper_sha256": sha(wrapper), "pck": str(pack), "pck_sha256": sha(pack),
              "resource_directory": str(empty), "capture_directory": str(captures), "expected_ui_frames": 31,
              "launcher": str(launcher), "command": command, "native_session_launched": False,
              "limitations": ["Dummy audio driver: this desktop has no soundcard; no audible-output verification",
                              "Software graphics with V-Sync disabled; no target-hardware performance claim"],
              "scope": "Prepared for parent native renderer capture; no UI automation or native execution performed by packager"}
    write_json(native / "NATIVE_REVIEW_MANIFEST.json", report)
    return report


def result_receipt(log: str, prefix: str) -> dict:
    # Empty prefix explicitly selects bare JSON, not every engine banner line.
    require(not ERROR_PATTERN.search(log), "Engine errors invalidate fixture receipt")
    lines = ([line.strip() for line in log.splitlines() if line.lstrip().startswith("{")]
             if prefix == "" else
             [line.removeprefix(prefix) for line in log.splitlines() if line.startswith(prefix)])
    require(len(lines) == 1, f"Expected exactly one {prefix.strip()} receipt")
    receipt = json.loads(lines[0])
    require(isinstance(receipt, dict) and receipt.get("passed") is True, "Fixture receipt did not pass")
    require(receipt.get("failures") == [], "Fixture receipt contains failures or no explicit failure list")
    require(type(receipt.get("checks")) is int and receipt["checks"] > 0, "Fixture ran no checks")
    return receipt


def command_check(name: str, command: list[str], cwd: Path, env: dict[str, str], logs: Path,
                  marker: str | None = None, timeout: int = 360, result_prefix: str | None = None) -> dict:
    start = time.monotonic()
    try:
        proc = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
        code, log = proc.returncode, proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout.decode(errors="replace") if isinstance(exc.stdout, bytes) else exc.stdout or ""
        stderr = exc.stderr.decode(errors="replace") if isinstance(exc.stderr, bytes) else exc.stderr or ""
        code, log = 124, stdout + stderr + "\nTIMEOUT\n"
    (logs / (name + ".log")).write_text(log, encoding="utf-8")
    clean = re.sub(r"\x1b\[[0-9;]*m", "", log)
    errors = [line for line in clean.splitlines() if ERROR_PATTERN.match(line)]
    row = {"name": name, "command": command, "exit_code": code, "errors": errors,
           "marker_found": marker is None or marker in clean,
           "passed": code == 0 and not errors and (marker is None or marker in clean),
           "wall_seconds": round(time.monotonic() - start, 3), "log_sha256": sha(logs / (name + ".log"))}
    if result_prefix is not None:
        try:
            row["fixture_receipt"] = result_receipt(clean, result_prefix)
        except (RuntimeError, ValueError) as exc:
            row["receipt_error"] = str(exc)
            row["passed"] = False
    progress = dict(row)
    if "fixture_receipt" in progress:
        progress["fixture_receipt"] = {key: value for key, value in progress["fixture_receipt"].items()
                                       if key in {"passed", "checks", "failures", "hz", "scope"}}
    print(json.dumps(progress), flush=True)
    write_json(logs / (name + ".json"), row)
    require(row["passed"], f"{name} failed; see {logs / (name + '.log')}")
    return row


def archive_tree(directory: Path, archive: Path) -> dict:
    require(not archive.exists(), f"Refusing to replace {archive}")
    temporary = archive.with_suffix(".partial.zip")
    require(not temporary.exists(), f"Refusing to replace {temporary}")
    members = {p.relative_to(directory.parent).as_posix(): sha(p) for p in sorted(directory.rglob("*")) if p.is_file()}
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zipped:
        for name in members:
            zipped.write(directory.parent / name, name)
    with zipfile.ZipFile(temporary) as zipped:
        require(zipped.testzip() is None, "Archive CRC failure")
        for name, digest in members.items():
            require(hashlib.sha256(zipped.read(name)).hexdigest() == digest, f"Archive byte mismatch: {name}")
    temporary.rename(archive)
    return {"path": str(archive), "bytes": archive.stat().st_size, "sha256": sha(archive), "members": members}


def checksums(directory: Path) -> None:
    rows = [f"{sha(p)}  {p.relative_to(directory).as_posix()}" for p in sorted(directory.rglob("*"))
            if p.is_file() and p.name != "CHECKSUMS.sha256"]
    (directory / "CHECKSUMS.sha256").write_text("\n".join(rows) + "\n", encoding="utf-8")


GUIDE_LINK = re.compile(r"\[([^\]\n]+)\]\(([^)\n]+)\)")


def validate_guide_links(package: Path, paths: list[str]) -> None:
    """Reject dangling or package-escaping relative Markdown guide links."""
    root = package.resolve()
    for relative in paths:
        guide = package / relative
        for match in GUIDE_LINK.finditer(guide.read_text(encoding="utf-8")):
            target = urlsplit(match.group(2))
            if target.scheme or target.netloc or not target.path:
                continue
            resolved = (guide.parent / unquote(target.path)).resolve()
            require(resolved.is_relative_to(root) and resolved.is_file(),
                    f"Broken package-local guide link in {relative}: {match.group(2)}")


def copy_player_guides(frozen: Path, package: Path) -> dict[str, dict]:
    """Adapt runtime references only; retain source and delivered hashes."""
    guides = {"README.md": "PROJECT_README.md",
              "campaign/docs/LOCAL_PLAYTEST.md": "LOCAL_PLAYTEST.md",
              "campaign/docs/NOV6_GAMEPAD.md": "NOV6_GAMEPAD.md",
              "campaign/docs/NOV6_CHANGES.md": "NOV6_CHANGES.md",
              "campaign/docs/PC_QUICKSTART.md": "PC_QUICKSTART.md",
              "campaign/docs/NOV12_EXTENDED_CHECKPOINT.md": "NOV12_EXTENDED_CHECKPOINT.md",
              "campaign/docs/NOV12_VISUAL_CHECKPOINT.md": "NOV12_VISUAL_CHECKPOINT.md",
              "campaign/docs/RUN_HISTORY_BOUNDARY.md": "RUN_HISTORY_BOUNDARY.md",
              "campaign/docs/REACTIVE_RUN_MILESTONE.md": "REACTIVE_RUN_MILESTONE.md",
              "campaign/docs/INTELLECT_SLICE.md": "INTELLECT_SLICE.md",
              "campaign/docs/HEARING_FOCUS_SLICE.md": "HEARING_FOCUS_SLICE.md"}
    destination = package / "docs"
    destination.mkdir()
    included = {}
    for relative, filename in guides.items():
        require((frozen / relative).is_file(), f"Player guide missing from source freeze: {relative}")
        source_hash = sha(frozen / relative)
        original = (frozen / relative).read_text(encoding="utf-8")
        adaptations = []

        def adapt_link(match: re.Match) -> str:
            label, raw_target = match.groups()
            target = urlsplit(raw_target)
            if target.scheme or target.netloc or not target.path:
                return match.group(0)
            source_target = posixpath.normpath(str(PurePosixPath(relative).parent / unquote(target.path)))
            if source_target in guides:
                local = guides[source_target]
                if target.fragment:
                    local += "#" + target.fragment
                label = label.replace(source_target, guides[source_target])
                replacement = f"[{label}]({local})"
                if replacement != match.group(0):
                    adaptations.append(f"Linked {source_target} to package-local {local}")
                return replacement
            adaptations.append(f"Marked {raw_target} as a source-only reference")
            reference = "`" + source_target + "`"
            if label.strip("`") != source_target:
                reference = label + " (" + reference + ")"
            return reference + " (source reference; requires the editable-source download)"

        delivered = GUIDE_LINK.sub(adapt_link, original)
        if relative == "README.md":
            for source_path, local_name in guides.items():
                if source_path != "README.md" and "`" + source_path + "`" in delivered:
                    delivered = delivered.replace("`" + source_path + "`", "`" + local_name + "`")
                    adaptations.append(f"Updated included guide filename {source_path} to {local_name}")
            delivered = ("Runtime-package reference adapted from the source README.\n"
                         "For this portable build, follow ../START_HERE.txt. Opening project.godot\n"
                         "and all other source/editor paths mentioned below require the separate\n"
                         "editable-source download. Included player guides are in this docs folder;\n"
                         "source-only references are labeled and are not package hyperlinks.\n"
                         "The editable-source ZIP preserves the original README unchanged.\n\n" + delivered)
            adaptations.insert(0, "Added runtime-package versus editable-source guidance")
        if delivered == original:
            shutil.copy2(frozen / relative, destination / filename)
        else:
            (destination / filename).write_text(delivered, encoding="utf-8")
        require(sha(frozen / relative) == source_hash, f"Frozen player guide changed: {relative}")
        included["docs/" + filename] = {"source_path": relative, "source_sha256": source_hash,
                                       "delivered_sha256": sha(destination / filename),
                                       "adapted": delivered != original, "adaptations": adaptations}
    validate_guide_links(package, list(included))
    return included


def verify_source_members(archive: Path, root_name: str, source_hashes: dict[str, str]) -> None:
    """Require every original Git file, including tests/docs, at its exact hash."""
    with zipfile.ZipFile(archive) as zipped:
        for relative, digest in source_hashes.items():
            name = root_name + "/" + relative
            require(name in zipped.namelist(), f"Source file omitted from archive: {relative}")
            require(hashlib.sha256(zipped.read(name)).hexdigest() == digest, f"Source archive drift: {relative}")


def verify_full_history(bundle: Path, commit: str, source_hashes: dict[str, str], destination: Path) -> dict:
    """Restore into a new bare repository, with no dependence on the checkout."""
    require(not destination.exists(), "History verification requires a new bare repository")
    subprocess.run(["git", "clone", "--bare", "--quiet", str(bundle), str(destination)], check=True, capture_output=True)
    subprocess.run(["git", "--git-dir", str(destination), "cat-file", "-e", commit + "^{commit}"], check=True, capture_output=True)
    subprocess.run(["git", "--git-dir", str(destination), "fsck", "--full", "--no-reflogs"], check=True, capture_output=True)
    restored = subprocess.run(["git", "--git-dir", str(destination), "archive", "--format=tar", commit], check=True, capture_output=True)
    restored_hashes = {}
    with tarfile.open(fileobj=io.BytesIO(restored.stdout)) as archive:
        for member in archive.getmembers():
            if member.isfile():
                stream = archive.extractfile(member)
                require(stream is not None, f"Missing restored history blob: {member.name}")
                restored_hashes[member.name] = hashlib.sha256(stream.read()).hexdigest()
    require(restored_hashes == source_hashes, "Full-history restoration does not reproduce every frozen source file")
    return {"self_contained_bare_clone": True, "git_fsck_passed": True, "source_commit": commit,
            "restored_source_files_verified": len(source_hashes), "bundle_sha256": sha(bundle)}


def package_source_variants(frozen: Path, source_hashes: dict[str, str], commit: str,
                            runtime_commit: str, bundle: Path, pck_sha256: str,
                            dist: Path, output: Path) -> dict:
    """Preserve full source/history while offering two naturally smaller files.

    The `source` result is the complete editable source variant intended to
    replace an existing source Library identity. `history` is its separate full
    Git-history companion. `source_and_history` is the canonical combined copy.
    No source/tests/docs are filtered and nothing is split into binary pieces.
    """
    source = dist / "MOKSHA-Source"
    shutil.copytree(frozen, source)
    for reserved in ("DELIVERY_SOURCE_MANIFEST.json", "START_HERE_SOURCE.txt"):
        require(not (source / reserved).exists(), f"Generated source note would overwrite a Git file: {reserved}")
    bundle_hash = sha(bundle)
    source_filename = f"MOKSHA-Editable-Source-{commit[:7]}.zip"
    history_filename = f"MOKSHA-Full-History-{commit[:7]}.zip"
    canonical_filename = f"MOKSHA-Source-and-History-{commit[:7]}.zip"
    manifest = {"source_commit": commit, "runtime_commit": runtime_commit, "runtime_matches_freeze": True,
                "source_sha256": source_hashes, "pck_sha256": pck_sha256,
                "history_bundle_sha256": bundle_hash, "history_bundle_bytes": bundle.stat().st_size,
                "history_companion": history_filename, "canonical_archive": canonical_filename,
                "variant": "complete editable source; full Git history is a separate companion",
                "all_source_tests_and_docs_preserved": True}
    write_json(source / "DELIVERY_SOURCE_MANIFEST.json", manifest)
    (source / "START_HERE_SOURCE.txt").write_text(f"""MOKSHA / COMPLETE EDITABLE SOURCE

Extract this entire ZIP and open project.godot in Godot 4.6.3.
It contains every file from source commit {commit}, including all source code,
assets, tests, documentation, and committed verification evidence.
The playable Windows ZIP is a separate download; this is the editable project.

To keep this download small, full Git history is delivered separately in:
{history_filename}
No source, tests, or documents were removed to reduce the ZIP size.
The separate history companion is only needed to inspect or restore Git history.

For a single archival copy containing both source and full history, use:
{canonical_filename}
DELIVERY_SOURCE_MANIFEST.json records every source-file checksum and the exact
full-history bundle checksum. Existing source and prior deliveries are preserved.
""", encoding="utf-8")
    source_result = archive_tree(source, output / source_filename)
    verify_source_members(Path(source_result["path"]), source.name, source_hashes)
    source_result.update({"role": "complete_editable_source", "intended_library_identity": "existing_editable_source",
                          "all_source_files_verified": len(source_hashes), "history_embedded": False})

    history = dist / "MOKSHA-History"
    history.mkdir()
    shutil.copy2(bundle, history / "MOKSHA-source-history.bundle")
    write_json(history / "HISTORY_MANIFEST.json", {"source_commit": commit, "runtime_commit": runtime_commit,
                                                  "bundle_sha256": bundle_hash, "bundle_bytes": bundle.stat().st_size,
                                                  "scope": "Complete self-contained Git bundle of all repository refs"})
    (history / "START_HERE_HISTORY.txt").write_text(f"""MOKSHA / FULL GIT HISTORY COMPANION

This is the complete repository history, not an incremental patch. The editable
project is supplied separately in {source_filename}.
You do not need this companion to open that project in Godot or play the game.

If Git is installed, extract this ZIP and run from this folder:
git clone MOKSHA-source-history.bundle MOKSHA-recovered
cd MOKSHA-recovered
git checkout {commit}

This creates a new recovered folder without modifying your existing project.
Bundle SHA-256: {bundle_hash}
The canonical combined source-and-history archive is {canonical_filename}.
""", encoding="utf-8")
    checksums(history)
    history_result = archive_tree(history, output / history_filename)
    with zipfile.ZipFile(history_result["path"]) as zipped:
        require(hashlib.sha256(zipped.read(history.name + "/MOKSHA-source-history.bundle")).hexdigest() == bundle_hash,
                "History companion bundle differs from verified full bundle")
    history_result.update({"role": "full_git_history_companion", "intended_library_identity": "new_history_companion",
                           "bundle_sha256": bundle_hash, "self_contained_history": True})

    canonical = dist / "MOKSHA-Source-and-History"
    shutil.copytree(source, canonical)
    (canonical / "history").mkdir(exist_ok=True)
    require(not (canonical / "history/MOKSHA-source-history.bundle").exists(), "Refusing to replace a committed history file")
    shutil.copy2(bundle, canonical / "history/MOKSHA-source-history.bundle")
    manifest["variant"] = "canonical complete editable source plus embedded full Git history"
    manifest["history_embedded_path"] = "history/MOKSHA-source-history.bundle"
    write_json(canonical / "DELIVERY_SOURCE_MANIFEST.json", manifest)
    (canonical / "START_HERE_SOURCE.txt").write_text(f"""MOKSHA / CANONICAL SOURCE AND FULL HISTORY

This is the complete archival copy for source commit {commit}.
Open project.godot in Godot 4.6.3 to edit the game. Every source file, asset,
test, document, and committed verification record is preserved.
Full repository history is included in history/MOKSHA-source-history.bundle.

For smaller downloads containing the same material, use these two companions:
{source_filename}
{history_filename}

DELIVERY_SOURCE_MANIFEST.json records source and full-history checksums.
This is source material, not a native Windows execution verification.
""", encoding="utf-8")
    canonical_result = archive_tree(canonical, output / canonical_filename)
    verify_source_members(Path(canonical_result["path"]), canonical.name, source_hashes)
    with zipfile.ZipFile(canonical_result["path"]) as zipped:
        require(hashlib.sha256(zipped.read(canonical.name + "/history/MOKSHA-source-history.bundle")).hexdigest() == bundle_hash,
                "Canonical history bundle mismatch")
    canonical_result.update({"role": "canonical_source_and_full_history", "intended_library_identity": "canonical_preservation_copy",
                             "all_source_files_verified": len(source_hashes), "history_embedded": True,
                             "bundle_sha256": bundle_hash})
    results = {"source": source_result, "history": history_result, "source_and_history": canonical_result}
    for result in results.values():
        result["small_attachment_limit_bytes"] = SMALL_ATTACHMENT_LIMIT
        result["under_small_attachment_limit"] = result["bytes"] < SMALL_ATTACHMENT_LIMIT
    return results


def readme(platform: str, commit: str, engine: str) -> str:
    start = ("Extract the complete ZIP to a folder, then double-click MOKSHA.exe.\n"
             "Keep MOKSHA.exe and MOKSHA.pck together. No editor install is needed.\n"
             "This unsigned development executable has NOT been executed on Windows.\n") if platform == "Windows" else (
             "Extract the complete ZIP. Open a terminal in the extracted MOKSHA-Linux folder\n"
             "(or cd into that folder), then run ./Start-MOKSHA.sh.\n"
             "If your extractor drops permissions, run from that same MOKSHA-Linux folder:\n"
             "chmod +x Start-MOKSHA.sh MOKSHA\n"
             "Then run ./Start-MOKSHA.sh again.\n"
             "The bundled official Linux engine runs the game without an installation.\n"
             "It includes editor functionality but the launcher starts game mode.\n")
    return f"""MOKSHA: FIVE ASCENTS / {platform} x86_64 development build

{start}
Use an OpenGL 3.3-compatible driver. No installer, account, or online service is required.

Enter: new campaign. C: Continue an active run, or View last result after completion.
Controller X follows the same title prompt. 1/2/3: select a build at the title.
A/D: move. Space: jump. W/S: ladder. S+Space: drop/dive.
J: attack. K: guard/parry. Shift: roll. E: interact. Q: sound pulse.
Tab: journal/navigation. Esc: pause. R: retry district. M: mute.
Follow the in-game prompts for choices, upgrades, and any newer controls.
See docs/NOV6_GAMEPAD.md for controller button mappings and modal controls,
docs/LOCAL_PLAYTEST.md for the play guide, and docs/NOV6_CHANGES.md for changes.

SAVE COMPATIBILITY: back up the entire existing user-data folder before switching builds.
The checkpoint is still named moksha_five_levels_v1.json, but this build writes
version-4 envelopes. Valid v1/v2/v3 saves migrate only after an exact preserved backup.
New runs preserve the prior checkpoint; completed records are immutable in
moksha_run_history/completed, with backups in moksha_run_history/preserved.
Older builds cannot read v4. Keep current files safe and restore a separate
backup compatible with the older build; never edit the version number. See docs/LOCAL_PLAYTEST.md
for the save-folder location and docs/RUN_HISTORY_BOUNDARY.md for exact guarantees.
Run only one game instance against a save folder. No concurrent-writer or
power-loss transaction guarantee is claimed. A failed completion save stays on
the ending screen; keep the game open and follow its retry/error message.

Optional HEARING -> FOCUS is offered after the first floor: accept or decline.
Hearing loss removes informative world/body sound, ambience and the sound-map;
visible melee can receive a brief late-windup opportunity, not automatic defense.
Combined sight/hearing loss is temporarily unavailable through normal choice UI.
Optional SMELL sacrifice after the third ascent removes coarse scent assistance
and prevents irritant cough interruptions, not damage or other hazards.
This is a prototype limit, not a permanent design ban. See docs/HEARING_FOCUS_SLICE.md.
Fall framing changes camera presentation only, not actor movement or collision.
Neither the original whole-game vision nor combat balance is claimed complete.

Frozen source: {commit}
Engine: {engine}
The actual packed game passed isolated Linux/headless checks, including all
district loads, script hashes, presentation concealment, incoming damage,
save/Continue, journal behavior, and synthetic controller/menu events. Detailed
receipts are in BUILD_REPORT.json. Controller events were synthesized through
the real input pipeline, not tested on physical controller hardware.
These are focused fixtures, not a complete human playthrough or a Windows test.
Human completion time, native Windows operation, and other devices remain unverified.

The source/history archive is the editable companion to this playable package.
Godot's MIT license and third-party notices are included under licenses/.
Existing saves are not altered by extracting this package. The game uses its
normal Godot user-data directory, separate from these portable program files.
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--runtime-commit", help="Earlier approved gameplay freeze; all packaged runtime paths must be unchanged")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--windows-archive", required=True, type=Path)
    parser.add_argument("--godot", default=shutil.which("godot") or "godot")
    parser.add_argument("--with-linux", action="store_true")
    parser.add_argument("--rehearsal", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    require(not output.exists(), "Output must be a new directory; old builds are preserved")
    require(not output.is_relative_to(ROOT), "Put build output outside the source checkout")
    prior = args.windows_archive.resolve()
    require(prior.is_file() and sha(prior) in TRUSTED_WINDOWS_ARCHIVES, "Prior Windows archive does not match trusted provenance")
    commit = subprocess.check_output(["git", "rev-parse", "--verify", args.source_commit + "^{commit}"], cwd=ROOT, text=True).strip()
    runtime_commit = subprocess.check_output(["git", "rev-parse", "--verify", (args.runtime_commit or commit) + "^{commit}"], cwd=ROOT, text=True).strip()
    changed_paths = subprocess.check_output(["git", "diff", "--name-only", "--no-renames", runtime_commit, commit, "--"], cwd=ROOT, text=True).splitlines()
    runtime_drift = [path for path in changed_paths if included_runtime(Path(path))]
    require(not runtime_drift, f"Runtime changed after approved freeze {runtime_commit}: {runtime_drift}")
    engine = Path(args.godot).resolve()
    require(engine.is_file(), "Godot executable is missing")
    output.mkdir(parents=True)
    logs = output / "verification"
    logs.mkdir()
    env = isolated_environment(output / "isolated", "build")
    version = subprocess.check_output([str(engine), "--version"], env=env, text=True).strip()
    require(version == EXPECTED_ENGINE, f"Expected official {EXPECTED_ENGINE}, found {version}")
    frozen = output / "frozen-source"
    source_hashes = snapshot(commit, frozen)
    stage = output / "export-stage"
    stage.mkdir()
    production = {}
    for relative, digest in source_hashes.items():
        if included_runtime(Path(relative)):
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(frozen / relative, target)
            production[relative] = digest
    require("project.godot" in production and "campaign/logic/campaign.gd" in production, "Missing campaign entry point")
    provenance = {"source_commit": commit, "runtime_commit": runtime_commit,
                  "runtime_matches_freeze": True, "engine": version, "production_sha256": production,
                  "scope": "Immutable Git snapshot; source resource inputs before Godot import/export"}
    write_json(stage / "BUILD_PROVENANCE.json", provenance)
    (stage / "export_presets.cfg").write_text(PRESET, encoding="utf-8")
    audit = output / "pack_audit.gd"
    audit.write_text(PACK_AUDIT.replace("@PROVENANCE_SHA@", sha(stage / "BUILD_PROVENANCE.json")).replace("@SOURCE_COMMIT@", commit), encoding="utf-8")
    reports = []
    # Separate source budget/provenance inventory gate, not a packed resource test.
    # Run the frozen script against the frozen source and its frozen policy.
    source_budget_report = logs / "source_asset_budget.json"
    reports.append(command_check("source_asset_budget", [sys.executable, "-B",
        str(frozen / "campaign/quality/assets_audit.py"), "--root", str(frozen),
        "--budgets", str(frozen / "campaign/quality/assets_budgets.json"),
        "--output", str(source_budget_report)], output, env, logs))
    source_budget = json.loads(source_budget_report.read_text())
    require(source_budget.get("passed") is True and source_budget.get("errors") == [],
            "Frozen source asset budget audit failed")
    reports.append(command_check("import", [str(engine), "--headless", "--editor", "--import", "--path", str(stage)], output, env, logs))
    pack = output / "MOKSHA.pck"
    reports.append(command_check("export_pack", [str(engine), "--headless", "--path", str(stage), "--export-pack", "Portable PCK", str(pack)], output, env, logs))
    require(pack.is_file() and pack.read_bytes()[:4] == b"GDPC", "Invalid exported PCK")
    test_root = output / "pack-only-run"
    test_root.mkdir()
    external_fixtures = output / "external-fixtures"
    external_fixtures.mkdir()
    # Exported PCKs may have an empty globalized res:// path. Keep explicitly
    # requested receipts in a separate sibling directory, never in the source
    # tree or resource working directory; frozen fixtures validate that policy.
    external_receipts = output.parent / (output.name + "-fixture-receipts")
    external_receipts.mkdir(exist_ok=False)
    fixture_hashes = {}

    def frozen_fixture(relative: str) -> Path:
        require(relative in source_hashes, f"Required frozen fixture missing: {relative}")
        path = external_fixtures / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            shutil.copy2(frozen / relative, path)
        require(sha(path) == source_hashes[relative], f"External fixture differs from frozen commit: {relative}")
        fixture_hashes[relative] = source_hashes[relative]
        return path

    def packed_check(name: str, script: Path | None, marker: str | None, pck: Path = pack,
                     binary: Path = engine, hz: int | None = None, result_prefix: str | None = None,
                     quit_after: int | None = None, report_output: Path | None = None,
                     fixture_root: Path | None = None) -> None:
        require(not any(test_root.iterdir()), "Packed test working directory must contain no loose resources")
        command = [str(binary), "--headless", "--path", str(test_root), "--main-pack", str(pck)]
        if script is None:
            command += ["--quit-after", "10"]
        else:
            command += ["--script", str(script)]
        if quit_after is not None:
            command += ["--quit-after", str(quit_after)]
        user_args = []
        # This destructive synthetic save fixture requires explicit opt-in even
        # though every packed invocation already owns isolated HOME/XDG roots.
        if script is not None and script.name == "save_draft.gd":
            user_args.append("--isolated-save-tests")
        if hz is not None:
            command += ["--fixed-fps", str(hz)]
            user_args.append("--hz=" + str(hz))
        if report_output is not None:
            require(not report_output.resolve().is_relative_to(output), "Fixture report must be outside the PCK project directory")
            user_args.append("--output=" + str(report_output))
        if fixture_root is not None:
            require(not fixture_root.exists(), "Fixture root must be fresh")
            user_args.append("--root=" + str(fixture_root))
        if user_args:
            command += ["--"] + user_args
        row = command_check(name, command, test_root, isolated_environment(output / "isolated", name), logs, marker, result_prefix=result_prefix)
        row["pck_sha256"] = sha(pck)
        row["resource_working_directory_empty"] = not any(test_root.iterdir())
        require(row["resource_working_directory_empty"], "Packed fixture wrote loose resources into the test working directory")
        if script is not None:
            row["external_script_sha256"] = sha(script)
        if report_output is not None:
            require(report_output.is_file(), "Fixture did not write its requested external receipt")
            require(json.loads(report_output.read_text()) == row.get("fixture_receipt"), "Console and file fixture receipts disagree")
            row["external_receipt_sha256"] = sha(report_output)
            row["external_receipt_path"] = str(report_output)
        write_json(logs / (name + ".json"), row)
        reports.append(row)

    packed_check("packed_title", None, None)
    packed_check("packed_audit", audit, "PACK_AUDIT_PASS")
    native_fixture = frozen_fixture("campaign/quality/nov6_native_review.gd")
    native_review = prepare_native_review(output, engine, pack, native_fixture,
                                          source_hashes["campaign/quality/nov6_native_review.gd"],
                                          sha(stage / "BUILD_PROVENANCE.json"), commit)
    packed_check("packed_native_wrapper_smoke", Path(native_review["wrapper"]), "PACKED_NATIVE_WRAPPER_READY ",
                 result_prefix="PACKED_NATIVE_WRAPPER_READY ", quit_after=12)
    fixtures = [
        ("incoming_health", "campaign/qa_audit/incoming_health.gd", "INCOMING_HEALTH_FAILURES []"),
        ("save_continue", "campaign/qa_audit/save_draft.gd", "SAVE_FAILURES []"),
        ("journal", "campaign/qa_audit/ui_dependencies.gd", "UI_DEPENDENCY_FAILURES []"),
    ]
    for hz in PACKED_TEST_RATES:
        for name, relative, marker in fixtures:
            packed_check(f"packed_{name}_{hz}", frozen_fixture(relative), marker, hz=hz)
        for name, relative, prefix in RECEIPT_FIXTURES:
            receipt_path = external_receipts / f"{name}_{hz}.json" if name.startswith("audio_") else None
            packed_check(f"packed_{name}_{hz}", frozen_fixture(relative), prefix, hz=hz, result_prefix=prefix, report_output=receipt_path)
    # Store fixture deliberately requires /tmp. Each case also gets independent
    # HOME/XDG roots via packed_check; no fixture history enters delivery trees.
    with tempfile.TemporaryDirectory(prefix="moksha-packed-reactive-", dir="/tmp") as temporary:
        for hz in PACKED_TEST_RATES:
            for name, relative, prefix, needs_root in REACTIVE_RECEIPT_FIXTURES:
                fixture_root = Path(temporary) / f"{name}_{hz}" if needs_root else None
                packed_check(f"packed_{name}_{hz}", frozen_fixture(relative), prefix,
                             hz=hz, result_prefix=prefix, fixture_root=fixture_root)
    # New milestone fixtures remain outside the PCK and never share user data.
    for name, relative, needs_root in HEARING_RECEIPT_FIXTURES:
        fixture_root = external_receipts / (name + "-store") if needs_root else None
        packed_check("packed_" + name, frozen_fixture(relative), None,
                     result_prefix="", fixture_root=fixture_root)
    camera_adapter = externalize_camera_contract(
        frozen_fixture("campaign/quality/nov12_fall_framing/contract.gd"),
        frozen_fixture("campaign/quality/nov12_fall_framing/baseline.gd"),
        external_fixtures / "camera-adapted")
    packed_check("packed_fall_framing", Path(camera_adapter["script"]), None,
                 result_prefix="FALL_FRAMING_RESULT ")
    focus_prefix = "NOV6_INDEPENDENT_FOCUS_UPGRADE "
    packed_check("packed_focus_upgrade", frozen_fixture("campaign/quality/nov6_independent_focus_upgrade.gd"), focus_prefix, result_prefix=focus_prefix)
    # Composition/resource/lifetime gate for the original Memory Loom district.
    # It is not a route, native-pixel or Windows-hardware acceptance claim.
    memory_prefix = "MEMORY_LOOM_CONTRACT "
    packed_check("packed_memory_loom", frozen_fixture("campaign/quality/memory_loom_candidate/contract.gd"),
                 memory_prefix, result_prefix=memory_prefix)
    require(all(sha(frozen / name) == digest for name, digest in source_hashes.items()), "Frozen source drift during verification")
    prior_extracted = output / "prior-runtime"
    extract_zip(prior, prior_extracted)
    old = prior_extracted / "MOKSHA-Windows"
    require(sha(old / "MOKSHA.exe") == EXPECTED_WINDOWS_EXE_SHA256, "Windows runtime hash mismatch")
    base_report = {
        "source_commit": commit, "runtime_commit": runtime_commit,
        "runtime_matches_freeze": True, "engine": version, "pck_sha256": sha(pack),
        "source_files": len(source_hashes), "runtime_source_files": len(production),
        "linux_engine_sha256": sha(engine), "windows_runtime_sha256": sha(old / "MOKSHA.exe"),
        "prior_windows_archive_sha256": sha(prior), "windows_executed": False,
        "complete_campaign_playthrough": False, "human_duration_validated": False,
        "physical_controller_hardware_tested": False,
        "external_fixture_sha256": fixture_hashes,
        "prepared_native_review": native_review,
        "camera_external_adapter": camera_adapter,
        "hearing_fixture_cadence": "Authored default physics cadence; camera internally integrates 60/120 trajectories",
        "checks": reports, "rehearsal": args.rehearsal,
    }
    if args.rehearsal:
        write_json(output / "REHEARSAL_REPORT.json", base_report)
        print(json.dumps({"rehearsal_passed": True, "report": str(output / "REHEARSAL_REPORT.json"), "pck_sha256": sha(pack)}))
        return 0

    dist = output / "distribution"
    dist.mkdir()
    windows = dist / "MOKSHA-Windows"
    windows.mkdir()
    shutil.copy2(old / "MOKSHA.exe", windows / "MOKSHA.exe")
    shutil.copy2(pack, windows / "MOKSHA.pck")
    shutil.copytree(old / "licenses", windows / "licenses")
    # Keep current project notices, not just those in the older distribution.
    for path in frozen.rglob("*"):
        if path.is_file() and path.name.upper().startswith(("LICENSE", "COPYING", "NOTICE")):
            target = windows / "licenses/project" / path.relative_to(frozen)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    shutil.copy2(old / "template-verification.json", windows / "template-verification.json")
    base_report["player_guides"] = copy_player_guides(frozen, windows)
    base_report["player_guide_sha256"] = {name: row["delivered_sha256"] for name, row in base_report["player_guides"].items()}
    (windows / "START_HERE.txt").write_text(readme("Windows", commit, version), encoding="utf-8")
    (windows / "Run-MOKSHA.cmd").write_bytes(b'@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\nif not exist "MOKSHA.pck" (\r\n  echo Extract the complete ZIP first. MOKSHA.pck is missing.\r\n  pause\r\n  exit /b 1\r\n)\r\nstart "MOKSHA" /D "%~dp0" "%~dp0MOKSHA.exe" --rendering-method gl_compatibility\r\n')
    write_json(windows / "BUILD_REPORT.json", portable_build_report(
            base_report, build=output, source=frozen, godot=engine, receipts=external_receipts))
    shutil.copy2(stage / "BUILD_PROVENANCE.json", windows / "BUILD_PROVENANCE.json")
    checksums(windows)
    archives = {"windows": archive_tree(windows, output / f"MOKSHA-Windows-x64-{commit[:7]}.zip")}
    fresh = output / "fresh-extraction"
    extract_zip(Path(archives["windows"]["path"]), fresh)
    fresh_pack = fresh / "MOKSHA-Windows/MOKSHA.pck"
    require(sha(fresh_pack) == sha(pack), "Extracted delivery PCK differs from tested pack")
    packed_check("fresh_windows_zip_pck", audit, "PACK_AUDIT_PASS", pck=fresh_pack)

    if args.with_linux:
        linux = dist / "MOKSHA-Linux"
        linux.mkdir()
        shutil.copy2(engine, linux / "MOKSHA")
        (linux / "MOKSHA").chmod(0o755)
        shutil.copy2(pack, linux / "MOKSHA.pck")
        shutil.copytree(windows / "licenses", linux / "licenses")
        shutil.copytree(windows / "docs", linux / "docs")
        (linux / "Start-MOKSHA.sh").write_text('#!/bin/sh\nset -eu\nHERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\ncd "$HERE"\nexec "$HERE/MOKSHA" --path "$HERE" --main-pack "$HERE/MOKSHA.pck" --rendering-method gl_compatibility "$@"\n', encoding="utf-8")
        (linux / "Start-MOKSHA.sh").chmod(0o755)
        (linux / "START_HERE.txt").write_text(readme("Linux", commit, version), encoding="utf-8")
        packed_check("relocated_linux_binary", audit, "PACK_AUDIT_PASS", pck=linux / "MOKSHA.pck", binary=linux / "MOKSHA")
        reports.append(command_check("linux_launcher", [str(linux / "Start-MOKSHA.sh"), "--headless", "--quit-after", "10"], test_root,
                                     isolated_environment(output / "isolated", "linux_launcher"), logs))
        write_json(linux / "BUILD_REPORT.json", portable_build_report(
            base_report, build=output, source=frozen, godot=engine, receipts=external_receipts))
        shutil.copy2(stage / "BUILD_PROVENANCE.json", linux / "BUILD_PROVENANCE.json")
        checksums(linux)
        archives["linux"] = archive_tree(linux, output / f"MOKSHA-Linux-x64-{commit[:7]}.zip")

    bundle = output / "MOKSHA-source-history.bundle"
    require(not bundle.exists(), "Refusing to overwrite historical source bundle")
    subprocess.run(["git", "bundle", "create", str(bundle), "--all"], cwd=ROOT, check=True, capture_output=True)
    subprocess.run(["git", "bundle", "verify", str(bundle)], cwd=ROOT, check=True, capture_output=True)
    history_verification = verify_full_history(bundle, commit, source_hashes, output / "history-verification.git")
    archives.update(package_source_variants(frozen, source_hashes, commit, runtime_commit, bundle, sha(pack), dist, output))
    final = dict(base_report, archives=archives, checks=reports, history_verification=history_verification,
                 passed=all(row["passed"] for row in reports))
    write_json(output / "DELIVERY_REPORT.json", final)
    print(json.dumps({"passed": final["passed"], "source_commit": commit, "report": str(output / "DELIVERY_REPORT.json"),
                      "archives": {key: {k: v for k, v in row.items() if k != "members"} for key, row in archives.items()}}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
