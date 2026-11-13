#!/usr/bin/env python3
"""No engine. Literal content/geometry/ownership checks, NOT actor passage proof."""
import argparse
import ast
from collections import Counter
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
BASE = "891f781894e33b66ab1f9935e2acab5030393777"
# Keep geometry/authority comparisons against the original runtime, but do not
# misclassify already-published release documentation/QA as new Loom ownership.
INTEGRATION_BASE = "5febc6179a6ba5bd09f7f26dc1ba5cac96a6b9fd"
LAYOUT = "campaign/layouts/level_04.gd"
HABITAT = "campaign/presentation/memory_loom_habitat.gd"
SCENERY = "campaign/presentation/campaign_scenery.gd"
ALLOWED = {LAYOUT, HABITAT, SCENERY, "campaign/quality/irritant/encounter_contract.gd",
           "README.md", "campaign/docs/CURRENT_PLAYABLE_STATE.md",
           "campaign/docs/PC_QUICKSTART.md",
           "campaign/docs/MEMORY_LOOM_COMMONS_CANDIDATE.md",
           "campaign/docs/MEMORY_LOOM_FRONTAGE_ATLAS.md",
           "campaign/docs/MEMORY_LOOM_NOV13_ACCEPTANCE.md",
           "campaign/docs/SOURCE_ASSET_BUDGET_CORRECTION.md",
           "campaign/assets/memory/archive_frontage_original.png",
           "campaign/assets/memory/archive_frontage_original.png.import",
           "campaign/assets/memory/ARCHIVE_FRONTAGE_PROMPT.txt",
           "campaign/assets/memory/ARCHIVE_FRONTAGE_PROVENANCE.txt",
           "campaign/quality/assets_budgets.json",
           "campaign/quality/assets_audit.py",
           "campaign/quality/assets_audit_test.py",
           "campaign/quality/nov12_market_habitat/contract.gd",
           "tools/package_nov6.py", "tools/package_nov6_tests.py"}
PREFIX = "campaign/quality/memory_loom_candidate/"
ATLAS = "campaign/assets/memory/archive_frontage_original.png"
ATLAS_SHA256 = "549e2293fd3e1be5aaad49ad3544a93fe0a7ee968b22036586da8760075b0c18"
PANORAMA = "campaign/assets/memory/memory_works_original.png"

def allowed_change(path):
    return path in ALLOWED or path.startswith(PREFIX) or path == HABITAT + ".uid"

def material_valid(habitat, atlas_bytes):
    return ('archive_frontage_original.png' in habitat and
            'draw_texture_rect_region' in habitat and
            hashlib.sha256(atlas_bytes).hexdigest() == ATLAS_SHA256)

def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True)

def function(source):
    return source.split("static func _loom()", 1)[1].split("static func _evacuation()", 1)[0]

def literal(node):
    if isinstance(node, ast.Constant):
        return node.value
    if isinstance(node, (ast.List, ast.Tuple)):
        return [literal(n) for n in node.elts]
    if isinstance(node, ast.Dict):
        return {literal(k): literal(v) for k, v in zip(node.keys, node.values)}
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        return -literal(node.operand)
    if isinstance(node, ast.Name) and node.id in ("true", "false"):
        return node.id == "true"
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in ("Vector2", "Rect2"):
        assert len(node.args) == (2 if node.func.id == "Vector2" else 4) and not node.keywords
        return [literal(n) for n in node.args]
    raise ValueError(f"Unsupported authored literal: {ast.dump(node)}")

def parse(source):
    return literal(ast.parse(function(source).split("\n\treturn ", 1)[1].strip(), mode="eval").body)

def signature(goal):
    return {key: goal.get(key, default) for key, default in
            [("id", None), ("label", None), ("kind", None), ("requires", []), ("optional", False), ("reward", "")]}

def intersects(a, b):
    return a[0] < b[0]+b[2] and a[0]+a[2] > b[0] and a[1] < b[1]+b[3] and a[1]+a[3] > b[1]

def body(at):
    return [at[0]-8, at[1]-34, 16, 34]

def centered(at, size):
    return [at[0]-size[0]/2, at[1]-size[1]/2, *size]

def supported(point, data):
    x, y = point
    return (y == 300 and 8 <= x <= data["width"]-8) or any(
        y == r[1] and r[0]+8 <= x <= r[0]+r[2]-8 for r in data["platforms"])

def validate(data, original):
    checks = []
    def check(ok, label):
        checks.append({"check": label, "passed": bool(ok)})
    goals = {g["id"]: g for g in data["objectives"]}
    check(data["id"] == original["id"] == "works_memory_loom", "stable district ID")
    check([signature(g) for g in data["objectives"]] == [signature(g) for g in original["objectives"]], "all objective IDs/labels/kinds/dependencies/reward semantics preserved")
    if not {"first_account", "other_account", "preserve", "index"}.issubset(goals):
        return checks
    check(data["width"] == 3900 and data["width"] < original["width"], "compact footprint, not padding")
    check(data.get("spawn") == [1900,300] and data.get("station") == [1800,300], "central stable-ID entry and existing station")
    check(not any(data.get(k) for k in ["gaps", "hazards", "lifts", "captains", "captain_required"]), "no pits/electric damage/lift reliance/captain gate")
    check(Counter(e[1] for e in data["enemies"]) == Counter(e[1] for e in original["enemies"]), "same seven enemies and archetype mix")
    check(data["ladders"] == [[460,300,220],[1160,300,220],[1640,300,220],[2160,300,220],[2560,300,220],[3440,300,220]], "six fixed routes, including independent optional alcove")
    for index, at in enumerate(data["route"] + [g["at"] for g in data["objectives"]] + [data["spawn"],data["station"]]):
        check(supported(at, data), f"waypoint/objective/entry support {index}")
        check(not any(intersects(body(at), r) for r in data["platforms"] if r[3] > 18), f"body not embedded in solid at declared point {index}")
    for index, (x, bottom, height) in enumerate(data["ladders"]):
        check(supported([x,bottom], data) and supported([x,bottom-height], data), f"ladder endpoints supported {index}")
        sweep = [x-8,bottom-height-34,16,height+34]
        check(not any(intersects(sweep, r) for r in data["platforms"] if r[3] > 18), f"ladder does not pass through solid ceiling {index}")
        check(all(abs(e[0]-x) >= 100 or e[2] not in (bottom,bottom-height) for e in data["enemies"]), f"no authored guard within 100px of ladder endpoint {index}")
    for index, enemy in enumerate(data["enemies"]):
        check(supported([enemy[0],enemy[2]],data), f"enemy support {index}")
    for index, prop in enumerate(data["props"]):
        check(supported(prop,data), f"physical prop support {index}")
        check(all(abs(prop[0]-g["at"][0]) >= 60 or abs(prop[1]-g["at"][1]) > 40 for g in data["objectives"]), f"no initial objective/prop overlap {index}")
    expected_doors = [([1440,205],[28,190],["first_account"]),([2360,205],[28,190],["other_account"]),([3690,160],[28,280],["preserve"])]
    check([(d["at"],d["size"],d["requires"]) for d in data["objective_doors"]] == expected_doors, "independent return doors and preserved final requirement")
    for index, x in enumerate((1440,2360)):
        door = data["objective_doors"][index]
        rectangle = centered(door["at"], door["size"])
        check(intersects(body([x,300]),rectangle), f"closed door intersects ground body {index}")
        check(not intersects(body([x,80]),rectangle), f"upper route clears closed door {index}")
        check(any(r[3] > 18 and r[1]+r[3] == rectangle[1] and r[0] <= rectangle[0] and r[0]+r[2] >= rectangle[0]+rectangle[2] for r in data["platforms"]), f"return door meets real solid ceiling {index}")
        # Sample the fixed ground corridor with only the return blocker removed.
        check(not any(intersects(body([sample,300]),r) for sample in range(x-140,x+141,4) for r in data["platforms"] if r[3] > 18), f"open return represented as unobstructed 34px standing-body corridor {index}")
    check(all(not goals[key].get("requires",[]) for key in ("first_account","other_account")), "either branch objective available first")
    check(goals["preserve"]["at"] == [3550,300], "isolation desk at east dispatch, before unchanged final seal")
    check(data["route"][-6:] == [[3360,80],[3440,80],[3440,300],[3550,300],[3690,300],[3855,300]], "west-first authored finish does not force a commons detour")
    check(goals["index"].get("optional") and goals["index"]["kind"] == "recover" and goals["index"].get("reward") == "vitality", "index matches actual existing scent supply eligibility")
    check([460,300,220] in data["ladders"] and goals["index"]["at"] == [560,80], "nonsmell index access has permanent fixed ladder")
    check(any("OPTIONAL SERVICE INDEX" in sign[1] for sign in data["signs"]), "nonsmell index sign")
    check(data.get("irritants") == [{"at":[2880,268]}], "one existing default irritant, no custom mechanics")
    field = centered(data["irritants"][0]["at"], [120,64])
    check(all(not intersects(body([x,80]),field) for x in range(2488,3493,4)), "continuous upper gallery outside default exposure rectangle")
    check(any(intersects(body([x,300]),field) for x in range(2560,3441,4)), "ground alternative actually crosses exposure rectangle")
    check(all([x,35,28,45] in data["platforms"] for x in (2650,3260)), "real 45px cover, below nominal 60px unmodified jump apex")
    check(all(any(intersects([x-1,55,2,4],r) for r in data["platforms"] if r[3] > 18) for x in (2664,3274)), "cover blocks representative horizontal sentry sightline")
    check(abs(goals["index"]["at"][0]-goals["first_account"]["at"][0])**2+220**2 < 300**2, "reward within existing supply-query range from west account (not exact beacon)")
    return checks

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    source = (ROOT/LAYOUT).read_text()
    original_source = git("show", f"{BASE}:{LAYOUT}")
    original, data = parse(original_source), parse(source)
    checks = validate(data, original)
    def check(ok, label):
        checks.append({"check":label,"passed":bool(ok)})
    check(source.replace(function(source), "<LOOM>") == original_source.replace(function(original_source), "<LOOM>"), "every other level04 function byte unchanged")
    changed = set(git("diff", "--name-only", INTEGRATION_BASE).splitlines()) | set(git("ls-files", "--others", "--exclude-standard").splitlines())
    check(all(allowed_change(path) for path in changed), "no changes outside bounded candidate and reviewed QA/documentation ownership")
    for path in ["campaign/perception/scent_observer.gd","campaign/perception/local_scent_query.gd","campaign/logic/campaign.gd","campaign/logic/objective.gd","campaign/logic/objective_door.gd","campaign/logic/irritant_disperser.gd","campaign/content/campaign_catalog.gd","campaign/logic/checkpoint_codec.gd","campaign/state/run_snapshot.gd","campaign/presentation/memory_atmosphere.gd"]:
        check((ROOT/path).read_bytes() == subprocess.check_output(["git","-C",str(ROOT),"show",f"{BASE}:{path}"]), f"authority/background byte protected: {path}")
    habitat = (ROOT/HABITAT).read_text()
    check('const MAX_RESIDENTS := 8' in habitat and 'Rect2(1680,138,460,162)' in habitat, "bounded original central scenery cluster")
    check('func cluster_indices_in_view()' in habitat and 'view.intersects(CLUSTERS[index])' in habitat, "explicit view culling")
    forbidden = ["_process(","_physics_process(","CollisionShape","StaticBody","Area2D","Input.","get_tree(","FileAccess","randomize(","randi(","host.","goal_done("]
    check(not any(token in habitat for token in forbidden), "presentation owns no ticks/game state/collision/input/saves/RNG")
    atlas_bytes = (ROOT/ATLAS).read_bytes()
    check(material_valid(habitat, atlas_bytes), "exact reviewed original frontage atlas, not rejected panorama crops")
    check((ROOT/PANORAMA).read_bytes() == subprocess.check_output(["git", "-C", str(ROOT), "show", f"{BASE}:{PANORAMA}"]), "original panoramic asset bytes unchanged")
    source_scenery = (ROOT/SCENERY).read_text()
    check('backdrop.add_child(memory_loom_habitat)' in source_scenery and 'MemoryLoomHabitat.DISTRICT_ID' in source_scenery and 'memory_loom_habitat = null' in source_scenery, "district-local parent lifetime and reconfiguration")
    routes = json.loads((ROOT/PREFIX/"acceptance_routes.json").read_text())
    check(routes["district_id"] == data["id"] and routes["stable_goals"] == [g["id"] for g in data["objectives"]], "acceptance routes use exact stable IDs")
    check(routes["stable_reward_id"] == "works_memory_loom/index" and routes["next_district_id"] == "works_service_refuge", "acceptance reward/progression targets preserved")
    geometry = json.loads((ROOT/PREFIX/"geometry_diff.json").read_text())
    check(geometry["candidate_layout_sha256"] == hashlib.sha256(source.encode()).hexdigest(), "review geometry bound to current layout bytes")
    check(routes["status"] == "PREPARED_NOT_EXECUTED", "prepared routes do not claim execution")
    negatives = []
    def negative(name, mutate):
        copy = deepcopy(data); mutate(copy)
        failed = [c["check"] for c in validate(copy, original) if not c["passed"]]
        negatives.append({"mutation":name,"rejected":bool(failed),"failures":failed})
    negative("renamed_stable_objective", lambda d: d["objectives"][3].update(id="new_index"))
    negative("dependent_second_branch", lambda d: d["objectives"][1].update(requires=["first_account"]))
    negative("preopened_west_return", lambda d: d["objective_doors"][0].update(requires=[]))
    negative("fake_open_return_solid", lambda d: d["platforms"].append([1390,230,100,70]))
    negative("old_commons_isolation_position", lambda d: d["objectives"][2].update(at=[1960,300]))
    negative("unsupported_witness", lambda d: d["objectives"][1].update(at=[3600,80]))
    negative("extra_enemy", lambda d: d["enemies"].append([1900,"listener",300]))
    negative("upper_gas_leak", lambda d: d["irritants"][0].update(at=[2880,60]))
    negative("lost_supply_eligibility", lambda d: d["objectives"][3].update(reward=""))
    negative("ladder_endpoint_ambush", lambda d: d["enemies"][0].__setitem__(0,1160))
    for path in ("campaign/logic/campaign.gd", "campaign/assets/memory/unreviewed.png", "tools/unreviewed.py"):
        negatives.append({"mutation": "unowned_change:" + path, "rejected": not allowed_change(path), "failures": ["bounded ownership"]})
    negatives.append({"mutation": "changed_original_atlas_bytes", "rejected": not material_valid(habitat, atlas_bytes + b"changed"), "failures": ["exact atlas hash"]})
    negatives.append({"mutation": "rejected_panorama_crop_reference", "rejected": not material_valid(habitat.replace("archive_frontage_original.png", "memory_works_original.png"), atlas_bytes), "failures": ["dedicated local atlas reference"]})
    hashes = {path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in sorted(changed) if (ROOT/path).is_file() and (args.report is None or (ROOT/path).resolve() != args.report.resolve())}
    report = {"base_commit":BASE,"passed":all(c["passed"] for c in checks) and all(n["rejected"] for n in negatives),"scope":"Engine-free literal/source and geometric representation checks. No Godot parser/import, real physics passage, live combat, native readability or pacing acceptance.","engine_run":False,"native_run":False,"checks":checks,"negative_controls":negatives,"candidate_source_sha256":hashes,"geometry_before":original,"geometry_candidate":data,"runtime_acceptance":"PENDING: see MEMORY_LOOM_COMMONS_CANDIDATE.md and acceptance_routes.json"}
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        with args.report.open("x") as stream:json.dump(report,stream,indent=2);stream.write("\n")
    print(json.dumps({"passed":report["passed"],"checks":len(checks),"negative_controls":len(negatives),"failures":[c["check"] for c in checks if not c["passed"]],"scope":report["scope"]},indent=2))
    return 0 if report["passed"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
