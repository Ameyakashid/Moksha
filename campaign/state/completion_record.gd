extends RefCounted
## Pure immutable completion-envelope validation. No filesystem/live-node access.
const VERSION:=1
const LENSES:=["neutral","strength","agility"]
const AUGMENTS:=["force","agility","vitality"]

static func valid_id(value:Variant)->bool:
	if not value is String or value.length()!=32:return false
	for character in value:
		if not character in "0123456789abcdef":return false
	return true

static func number(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0

static func whole(value:Variant)->bool:
	return number(value) and float(value)==floor(float(value)) and float(value)<=9007199254740991.0

static func json_value(value:Variant,depth:=0)->bool:
	# Also rejects cycles and pathological nesting before serialization.
	if depth>48:return false
	if value==null or value is bool or value is String:return true
	if value is int or value is float:return is_finite(float(value))
	if value is Array:
		for item in value:
			if not json_value(item,depth+1):return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not json_value(value[key],depth+1):return false
		return true
	return false

static func valid(raw:Variant)->bool:
	if not raw is Dictionary or not json_value(raw):return false
	if not whole(raw.get("schema_version")) or int(raw.schema_version)!=VERSION:return false
	if not valid_id(raw.get("run_id")) or raw.get("ending") not in ["public_record","local_custody"]:return false
	if not number(raw.get("completed_at")):return false
	var result:Variant=raw.get("result")
	if not result is Dictionary:return false
	if not number(result.get("active_seconds")) or result.get("lens") not in LENSES:return false
	if not whole(result.get("deaths")) or not whole(result.get("kills")):return false
	if not result.get("upgrades") is Array or result.upgrades.size()>4:return false
	for upgrade in result.upgrades:
		if upgrade not in AUGMENTS:return false
	if not result.get("levels") is Array or not result.get("districts") is Array:return false
	for row in result.levels:
		if not row is Dictionary or not whole(row.get("level")) or int(row.level)<1 or int(row.level)>5:return false
		if not number(row.get("active_seconds")) or not row.get("completed_district") is String or row.completed_district.is_empty():return false
	for row in result.districts:
		if not row is Dictionary or not number(row.get("seconds")):return false
		if row.has("area_id"):
			if not row.area_id is String or row.area_id.is_empty():return false
		elif not whole(row.get("sector")):return false
		if row.has("blind") and not row.blind is bool:return false
		if row.has("health") and not number(row.health):return false
	var snapshot:Variant=raw.get("snapshot")
	if not snapshot is Dictionary or not whole(snapshot.get("campaign_version")) or int(snapshot.campaign_version)!=2:return false
	if snapshot.get("run_id")!=raw.run_id or snapshot.get("run_status")!="completed":return false
	# Complete checkpoint schema/content validation remains the checkpoint codec's job.
	return true

static func canonical(raw:Dictionary)->String:
	# Round-trip once normalizes JSON integer/float representation for idempotent reads.
	return JSON.stringify(JSON.parse_string(JSON.stringify(raw,"",true,true)),"",true,true)
