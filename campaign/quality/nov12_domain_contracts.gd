extends SceneTree
## Pure-policy fixtures: no campaign scene, live actor, file I/O or save directory.
const BuildRules=preload("res://campaign/logic/build_rules.gd")
const CampaignCheckpoint=preload("res://campaign/logic/checkpoint_codec.gd")
const Progress=preload("res://demo/components/checkpoint_codec.gd")
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:
	var lenses={"neutral":[1.0,1.0,60.0],"agility":[1.12,1.0,50.0],"strength":[0.94,1.4,75.0]}
	var builds:=0
	for lens in lenses:
		for mask in 8:
			var rewards:Dictionary={}
			for index in 3:
				if mask & (1<<index):rewards["district/"+str(index)]=BuildRules.AUGMENTS[index]
			# Every ordered combination of 0..4 level upgrades, plus all reward subsets.
			for count in 5:
				for combination in int(pow(3,count)):
					var upgrades:Array=[]
					var code:=combination
					for index in count:upgrades.append(BuildRules.AUGMENTS[code%3]);code/=3
					var before:=[rewards.duplicate(true),upgrades.duplicate()]
					var actual:Dictionary=BuildRules.evaluate(lens,rewards,upgrades)
					var base:Array=lenses[lens]
					var expected:={"speed":base[0]+rewards.values().count("agility")*0.03+upgrades.count("agility")*0.1,"force":base[1]+rewards.values().count("force")*0.08+upgrades.count("force")*0.25,"capacity":base[2]+rewards.values().count("vitality")*5+upgrades.count("vitality")*15}
					check(is_equal_approx(actual.speed,expected.speed) and is_equal_approx(actual.force,expected.force) and is_equal_approx(actual.capacity,expected.capacity),"build values "+str(builds))
					check(before==[rewards,upgrades],"build inputs remain unchanged "+str(builds))
					actual.speed=-100
					check(is_equal_approx(BuildRules.evaluate(lens,rewards,upgrades).speed,expected.speed),"returned snapshot is independent "+str(builds))
					builds+=1
	var areas:Array=[{"id":"first"},{"id":"second"}]
	var encoded:Dictionary=Progress.encode({"sector":1,"caches":[0],"metrics":[{"sector":0,"seconds":2.5}],"seconds":12.5},areas)
	var valid:Dictionary={"campaign_version":1,"progress":encoded.data,"lens":"strength","upgrades":["force","vitality"],"rewards":{"first/a":"agility"},"level_seconds":{"1":12.5},"level_receipts":[{"level":1,"active_seconds":12.5,"completed_district":"first"}]}
	var before:Dictionary=valid.duplicate(true)
	var result:Dictionary=CampaignCheckpoint.decode(valid,areas)
	check(result.ok and result.sector==1 and result.caches==[0] and result.campaign==valid,"campaign envelope delegates stable-ID progress decoding")
	check(valid==before,"decode does not mutate the supplied envelope")
	var optional:Dictionary=valid.duplicate(true);optional.erase("level_seconds");optional.erase("level_receipts")
	check(CampaignCheckpoint.decode(optional,areas).ok,"historical optional fields remain optional")
	var integral_version:Dictionary=valid.duplicate(true);integral_version.campaign_version=1.0
	check(CampaignCheckpoint.decode(integral_version,areas).ok,"integral JSON numeric version remains accepted")
	for value in [null,false,[],"not an envelope"]:check(not CampaignCheckpoint.decode(value,areas).get("ok",false),"reject non-object envelope")
	var mutations={"campaign_version":[null,"1",1.5,0,2],"progress":[null,[],{}],"lens":[null,"wizard",1],"upgrades":[null,{},["unknown"],["force","force","force","force","force"]],"rewards":[null,[],{"a":"unknown"}],"level_seconds":[null,[],{"1":-1},{"1":"2"}],"level_receipts":[null,{},[null],[{"level":0,"active_seconds":0}],[{"level":6,"active_seconds":0}],[{"level":1,"active_seconds":-1}]]}
	for field in mutations:
		for value in mutations[field]:
			var invalid:Dictionary=valid.duplicate(true);invalid[field]=value
			check(not CampaignCheckpoint.decode(invalid,areas).get("ok",false),"reject malformed "+field)
	check(not CampaignCheckpoint.decode(valid,[{"id":"unknown"}]).ok,"save identity requires the injected layout")
	check(CampaignCheckpoint.VERSION==4,"current sensory campaign envelope explicitly versioned 4")
	var v2:Dictionary=valid.duplicate(true)
	v2.campaign_version=2;v2.run_id="0123456789abcdef0123456789abcdef";v2.run_status="active";v2.run_origin="new"
	check(CampaignCheckpoint.decode(v2,areas).ok,"separately valid v2 identity accepted")
	var v3:Dictionary=v2.duplicate(true);v3.campaign_version=3;v3.senses={"version":1,"sight":"retained","hearing":"traded"}
	check(CampaignCheckpoint.decode(v3,areas).ok,"explicit legacy v3/sense1 accepted")
	var v4:Dictionary=v2.duplicate(true);v4.campaign_version=4;v4.senses={"version":2,"sight":"retained","hearing":"traded","smell":"traded"}
	check(CampaignCheckpoint.decode(v4,areas).ok,"explicit current v4/sense2 accepted")
	for field in ["run_id","run_status","run_origin"]:
		var missing:Dictionary=v2.duplicate(true);missing.erase(field)
		check(not CampaignCheckpoint.decode(missing,areas).ok,"v2 requires "+field)
	print("NOV12_DOMAIN_CONTRACT_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"build_combinations":builds,"failures":failures,"scope":"Scene-independent build arithmetic and save-envelope policies; not gameplay or filesystem acceptance."}))
	quit(0 if failures.is_empty() else 1)
