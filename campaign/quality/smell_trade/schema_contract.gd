extends SceneTree
const Sense=preload("res://campaign/state/sense_state.gd")
const Codec=preload("res://campaign/logic/checkpoint_codec.gd")
const Progress=preload("res://demo/components/checkpoint_codec.gd")
const Data=preload("res://campaign/logic/campaign_data.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var sectors:Array=Data.sectors()
	var encoded:Dictionary=Progress.encode({"sector":0,"metrics":[],"blind":false},sectors)
	var raw:Dictionary={"campaign_version":4,"run_id":"0123456789abcdef0123456789abcdef","run_status":"active","run_origin":"new","progress":encoded.data,"lens":"neutral","upgrades":[],"rewards":{},"level_seconds":{},"level_receipts":[],"senses":Sense.create()}
	for sight in [false,true]:
		for hearing in [false,true]:
			for smell in [false,true]:
				var state:=Sense.create(sight,hearing,smell);var caps:=Sense.capabilities(state)
				check(Sense.valid(state) and caps.scent==smell and caps.irritant_susceptible==smell and caps.hearing==hearing and caps.sight==(not sight),"orthogonal sensory facts")
	for version in [1,2,3,4]:
		var copy:Dictionary=raw.duplicate(true);copy.campaign_version=version
		if version<3:copy.erase("senses")
		elif version==3:copy.senses={"version":1,"sight":"retained","hearing":"traded"}
		check(Codec.decode(copy,sectors).ok,"explicit legacy envelope supported")
		if version==3:
			var upgraded:=Sense.upgrade_legacy(copy.senses,false)
			check(upgraded.ok and upgraded.state.hearing=="traded" and upgraded.state.smell=="retained","migration retains hearing loss")
	for envelope in [3,4]:
		var wrong:Dictionary=raw.duplicate(true);wrong.campaign_version=envelope
		wrong.senses={"version":1,"sight":"retained","hearing":"retained"} if envelope==4 else Sense.create()
		check(not Codec.decode(wrong,sectors).ok,"schema pair mismatch rejected")
	for bad in [null,{}, {"version":2,"sight":"retained","hearing":"retained","smell":"missing"},{"version":2,"sight":"retained","hearing":"retained","smell":"retained","extra":true}]:
		check(not Sense.decode(bad,false).ok,"invalid senses fail closed")
	var legacy:Dictionary={"version":1,"sight":"retained","hearing":"traded"};var before:=legacy.duplicate(true);Sense.upgrade_legacy(legacy,false)
	check(legacy==before,"legacy normalization never mutates source")
	print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Pure schema/capability fixtures"}));quit(1 if failures.size() else 0)
