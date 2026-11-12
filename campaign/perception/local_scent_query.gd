extends RefCounted
## Pure original quantizer. Exact source facts never cross its output boundary.
const MAX_SOURCES:=64
const MAX_MARKS:=6
const LIFE_RANGE:=420.0
const SUPPLY_RANGE:=300.0
const NEAR_RANGE:=140.0
const HERE_RANGE:=32.0
static func sample(sources:Array)->Array[Dictionary]:
	var groups:Dictionary={}
	for source in sources.slice(0,MAX_SOURCES):
		if not source is Dictionary or not source.get("offset") is Vector2:continue
		var offset:Vector2=source.offset
		if not offset.is_finite():continue
		var kind:String=str(source.get("kind",""))
		if kind not in ["life","supply"]:continue
		var distance:=offset.length()
		if distance>(LIFE_RANGE if kind=="life" else SUPPLY_RANGE):continue
		var bearing:=-1 if distance<=HERE_RANGE else posmod(int(round(offset.angle()/(PI/4.0))),8)
		var band:="near" if distance<=NEAR_RANGE else "faint"
		var key:=kind+":"+str(bearing)+":"+band
		var wound:bool=kind=="life" and source.get("wounded",false)==true
		if groups.has(key):groups[key].wounded=groups[key].wounded or wound
		else:groups[key]={"bearing":bearing,"band":band,"kind":kind,"wounded":wound}
	var marks:Array[Dictionary]=[]
	for value in groups.values():marks.append(value)
	marks.sort_custom(func(a,b):
		if a.band!=b.band:return a.band=="near"
		if a.kind!=b.kind:return a.kind=="supply"
		return a.bearing<b.bearing)
	return marks.slice(0,MAX_MARKS)
static func valid_mark(mark:Dictionary)->bool:
	return mark.size()==4 and mark.get("bearing") is int and mark.bearing>=-1 and mark.bearing<8 and mark.get("band") in ["near","faint"] and mark.get("kind") in ["life","supply"] and mark.get("wounded") is bool and (mark.kind=="life" or not mark.wounded) and (mark.bearing!=-1 or mark.band=="near")
