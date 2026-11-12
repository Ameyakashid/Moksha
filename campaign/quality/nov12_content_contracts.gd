extends SceneTree
const Data=preload("res://campaign/logic/campaign_data.gd")
const Catalog=preload("res://campaign/content/campaign_catalog.gd")
const Snapshot=preload("res://campaign/state/run_snapshot.gd")
const Codec=preload("res://campaign/logic/checkpoint_codec.gd")
const Progress=preload("res://demo/components/checkpoint_codec.gd")
class MissingCampaign:
	extends "res://campaign/logic/campaign.gd"
	func _load_catalog()->Dictionary:
		return preload("res://campaign/logic/campaign_data.gd").load_catalog(["res://campaign/layouts/not_installed.gd"])

var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	var catalog:=Data.load_catalog()
	check(catalog.ok,"authored catalog accepted")
	if not catalog.ok:print(catalog);quit(1);return
	check(catalog.sectors.size()==32,"32 districts")
	var originals:Array=[]
	var expected:Array=[]
	for level in range(1,6):
		var entries:Array=load("res://campaign/layouts/level_%02d.gd"%level).sectors()
		originals.append(entries)
		for entry in entries:
			var copy:Dictionary=entry.duplicate(true);copy.level=level;expected.append(copy)
	# Resources loaded twice can have identity-sensitive values; compare serialized values.
	check(equivalent(catalog.sectors,expected),"every content value unchanged")
	var result:=Catalog.validate(originals)
	result.sectors[0].title="changed"
	check(originals[0][0].title!="changed","catalog output detached")
	var missing:=Data.load_catalog(["res://campaign/layouts/not_installed.gd"])
	check(not missing.ok and not missing.error.is_empty() and missing.sectors.is_empty(),"missing file fails with diagnostic and no partial campaign")
	check(not Catalog.validate([]).ok,"missing levels rejected")
	var duplicate:Array=originals.duplicate(true);duplicate[1][0].id=duplicate[0][0].id
	check(not Catalog.validate(duplicate).ok,"duplicate stable ID rejected")
	var bad:Array=originals.duplicate(true);bad[0][0].objectives=[{"id":"a","requires":["unknown"]}]
	check(not Catalog.validate(bad).ok,"unknown objective dependency rejected")
	var short:Array=originals.duplicate(true);short[0].pop_back()
	check(not Catalog.validate(short).ok,"missing district rejected")
	var extra:Array=originals.duplicate(true);var added:Dictionary=extra[0][0].duplicate(true);added.id="unexpected_district";extra[0].append(added)
	check(not Catalog.validate(extra).ok,"extra district requires explicit manifest change")
	for graph in [[{"id":"a","requires":["a"]}],[{"id":"a","requires":["b"]},{"id":"b","requires":["a"]}],[{"id":"open"},{"id":"a","requires":["b"]},{"id":"b","requires":["a"]}]]:
		var cyclic:Array=originals.duplicate(true);cyclic[0][0].objectives=graph
		check(not Catalog.validate(cyclic).ok,"cyclic/self objective dependencies rejected")
	var dag:Array=originals.duplicate(true);dag[0][0].objectives=[{"id":"last","requires":["left","right"]},{"id":"left","requires":["first"]},{"id":"right","requires":["first"]},{"id":"first"}]
	check(Catalog.validate(dag).ok,"out-of-order branching acyclic dependencies accepted")
	var state:={"lens":"neutral","upgrades":["force"],"rewards":{"x":"agility"},"level_seconds":{"1":2.0},"level_receipts":[{"level":1,"active_seconds":2.0}]}
	var snapshot:=Snapshot.capture(state);snapshot.level_receipts[0].active_seconds=99
	check(state.level_receipts[0].active_seconds==2.0,"run snapshot nested values detached")
	var progress:=Progress.encode({"sector":0},catalog.sectors)
	var raw:={"campaign_version":1,"progress":progress.data};raw.merge(Snapshot.capture(state))
	var decoded:=Codec.decode(raw,catalog.sectors)
	check(decoded.ok,"v1 envelope accepted")
	decoded.campaign.rewards.x="vitality"
	check(raw.rewards.x=="agility","restore result detached from source envelope")
	var roundtrip:=Codec.decode(JSON.parse_string(JSON.stringify(raw)),catalog.sectors)
	check(roundtrip.ok and roundtrip.campaign.lens==state.lens,"v1 JSON roundtrip")
	var before:=raw.duplicate(true)
	check(not Codec.decode(raw,[{"id":"foreign"}]).ok and raw==before,"foreign restore rejected without mutation")
	var malformed:=raw.duplicate(true);malformed.upgrades=["unknown"]
	before=malformed.duplicate(true)
	check(not Codec.decode(malformed,catalog.sectors).ok and malformed==before,"malformed restore rejected without mutation")
	call_deferred("check_error_panel")
func check_error_panel()->void:
	var host=MissingCampaign.new()
	var save_path:String=host.CAMPAIGN_SAVE
	var existed:=FileAccess.file_exists(save_path)
	var digest:=FileAccess.get_sha256(save_path) if existed else ""
	root.add_child(host)
	check(FileAccess.file_exists(save_path)==existed and (not existed or FileAccess.get_sha256(save_path)==digest),"failed startup leaves checkpoint untouched")
	check(host.get_child_count()==1 and not host.is_processing() and not host.is_physics_processing(),"content error disables gameplay and creates visible layer")
	var label=host.get_child(0).get_child(0).get_child(0)
	check(label.text.contains("CAMPAIGN CONTENT ERROR") and label.text.contains("not_installed.gd"),"error panel contains actionable diagnostic")
	host.free()
	print("NOV12_CONTENT_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func equivalent(a:Variant,b:Variant)->bool:
	if typeof(a)!=typeof(b):return false
	if a is Resource:return a.resource_path==b.resource_path
	if a is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]):return false
		return true
	if a is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not equivalent(a[i],b[i]):return false
		return true
	return a==b
