extends RefCounted
## Pure campaign build policy. No actor, scene, input or filesystem dependencies.
## The host applies this snapshot to fresh base resources; this never mutates them.
const LENSES := ["neutral", "strength", "agility"]
const AUGMENTS := ["force", "agility", "vitality"]

static func evaluate(lens:String, rewards:Dictionary, upgrades:Array)->Dictionary:
	var speed:=1.0;var force:=1.0;var capacity:=60.0
	if lens=="agility":speed=1.12;capacity=50
	elif lens=="strength":speed=0.94;force=1.4;capacity=75
	for value in rewards.values():
		if value=="vitality":capacity+=5
		elif value=="force":force+=0.08
		elif value=="agility":speed+=0.03
	for value in upgrades:
		if value=="vitality":capacity+=15
		elif value=="force":force+=0.25
		elif value=="agility":speed+=0.1
	return {"speed":speed,"force":force,"capacity":capacity}
