extends RefCounted
## Persisted facts, independent of offer availability. Old history stays immutable.
const VERSION := 2
static func create(blind := false, hearing_retained := true, smell_retained := true) -> Dictionary:
	return {"version":VERSION,"sight":"traded" if blind else "retained","hearing":"retained" if hearing_retained else "traded","smell":"retained" if smell_retained else "traded"}
static func valid(value: Variant) -> bool:
	return _valid_version(value,VERSION)
static func _valid_version(value: Variant, version: int) -> bool:
	if version not in [1,2] or not value is Dictionary or value.size()!=(3 if version==1 else 4) or not value.get("version") is int or value.version!=version:return false
	if value.get("sight") not in ["retained","traded"] or value.get("hearing") not in ["retained","traded"]:return false
	return version==1 or value.get("smell") in ["retained","traded"]
static func decode(value: Variant, blind: bool, expected_version := VERSION) -> Dictionary:
	if not value is Dictionary:return {"ok":false}
	var normalized:Dictionary=value.duplicate(true)
	if not (normalized.get("version") is int or normalized.get("version") is float) or normalized.version!=expected_version:return {"ok":false}
	normalized.version=expected_version
	if not _valid_version(normalized,expected_version) or (normalized.sight=="traded")!=blind:return {"ok":false}
	return {"ok":true,"state":normalized}
static func upgrade_legacy(value: Variant, blind: bool) -> Dictionary:
	var legacy:=decode(value,blind,1)
	if not legacy.ok:return {"ok":false}
	return {"ok":true,"state":create(blind,legacy.state.hearing=="retained",true)}
static func capabilities(value: Dictionary) -> Dictionary:
	if not valid(value):return {}
	return {"sight":value.sight=="retained","hearing":value.hearing=="retained","sonar":value.hearing=="retained","focus":value.hearing=="traded" and value.sight=="retained","scent":value.smell=="retained","irritant_susceptible":value.smell=="retained","specialization":"FOCUS" if value.hearing=="traded" and value.sight=="retained" else ""}
