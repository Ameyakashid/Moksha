extends RefCounted
## Pure sensory facts. Dual loss is representable; UI availability is not schema truth.
const VERSION := 1
static func create(blind := false, hearing_retained := true) -> Dictionary:
	return {"version":VERSION,"sight":"traded" if blind else "retained","hearing":"retained" if hearing_retained else "traded"}
static func valid(value: Variant) -> bool:
	return value is Dictionary and value.size()==3 and value.get("version") is int and value.version==VERSION and value.get("sight") in ["retained","traded"] and value.get("hearing") in ["retained","traded"]
static func decode(value: Variant, blind: bool) -> Dictionary:
	# JSON numeric versions may arrive as floats, but must be exact whole values.
	if not value is Dictionary:return {"ok":false}
	var normalized:Dictionary=value.duplicate(true)
	if not (normalized.get("version") is int or normalized.get("version") is float) or normalized.version!=VERSION:return {"ok":false}
	normalized.version=VERSION
	if not valid(normalized) or (normalized.sight=="traded")!=blind:return {"ok":false}
	return {"ok":true,"state":normalized}
static func capabilities(value: Dictionary) -> Dictionary:
	if not valid(value):return {}
	return {"sight":value.sight=="retained","hearing":value.hearing=="retained","sonar":value.hearing=="retained","focus":value.hearing=="traded" and value.sight=="retained","scent":true,"specialization":"FOCUS" if value.hearing=="traded" and value.sight=="retained" else ""}
