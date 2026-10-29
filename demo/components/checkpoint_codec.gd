extends RefCounted
## Save identity boundary only. Runtime sector sequencing remains positional.
const VERSION := 4
# Immutable schema3 campaign order. NEVER derive migration from current ordering.
const V3_IDS := ["rainline", "quarantine_intake", "exchange", "freight_lock", "cistern", "relay_works", "lift_warden", "above_the_rain"]
static func parse(text:String)->Variant:
 var parser=JSON.new()
 return parser.data if parser.parse(text)==OK else null
static func failure(reason:String)->Dictionary:return {"ok":false,"error":reason}
static func whole(value:Variant)->bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=0 and float(value)<=9007199254740991.0
static func number(value:Variant)->bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)>=0
static func layout(areas:Array)->Dictionary:
 var ids:Array[String]=[]
 for area in areas:
  if not area is Dictionary or not area.get("id") is String or str(area.id).is_empty():return failure("Campaign area has no stable ID.")
  if ids.has(area.id):return failure("Campaign contains duplicate area IDs.")
  ids.append(area.id)
 if ids.is_empty():return failure("Campaign has no areas.")
 return {"ok":true,"ids":ids}
static func legacy_id(index:Variant)->String:
 return V3_IDS[int(index)] if whole(index) and float(index)<V3_IDS.size() else ""
static func decode(value:Variant,areas:Array)->Dictionary:
 var config=layout(areas)
 if not config.ok:return config
 if not value is Dictionary:return failure("Checkpoint is not a valid object.")
 var version=value.get("version")
 if not whole(version) or int(version) not in [3,VERSION]:return failure("Unsupported checkpoint version.")
 var ids:Array=config.ids
 var id:Variant=legacy_id(value.get("sector")) if version==3 else value.get("sector_id")
 if not id is String or not ids.has(id):return failure("Checkpoint area is unknown to this campaign.")
 var cache_values:Variant=value.get("caches",[]) if version==3 else value.get("cache_ids",[])
 if not cache_values is Array:return failure("Checkpoint archives are malformed.")
 var caches:Array[int]=[]
 for entry in cache_values:
  var cache_id:Variant=legacy_id(entry) if version==3 else entry
  if not cache_id is String or not ids.has(cache_id):return failure("Checkpoint archive area is unknown.")
  var index:int=ids.find(cache_id)
  if caches.has(index):return failure("Checkpoint archives contain duplicate IDs.")
  caches.append(index)
 var rows:Variant=value.get("metrics",[])
 if not rows is Array:return failure("Checkpoint history is malformed.")
 var metrics:Array[Dictionary]=[]
 for entry in rows:
  if not entry is Dictionary or not number(entry.get("seconds")):return failure("Checkpoint history row is malformed.")
  var row_id:Variant=legacy_id(entry.get("sector")) if version==3 else entry.get("area_id")
  if not row_id is String or not ids.has(row_id):return failure("Checkpoint history area is unknown.")
  if entry.has("blind") and not entry.blind is bool:return failure("Checkpoint history sight state is malformed.")
  if entry.has("health") and not number(entry.health):return failure("Checkpoint history health is malformed.")
  var row:Dictionary=entry.duplicate(true);row.erase("area_id");row.sector=ids.find(row_id);metrics.append(row)
 if not value.get("blind",false) is bool or not whole(value.get("kills",0)) or not whole(value.get("deaths",0)) or not number(value.get("seconds",0)):
  return failure("Checkpoint progress values are malformed.")
 return {"ok":true,"source_version":int(version),"sector":ids.find(id),"caches":caches,"metrics":metrics,"blind":value.get("blind",false),"kills":int(value.get("kills",0)),"deaths":int(value.get("deaths",0)),"seconds":float(value.get("seconds",0))}
static func encode(state:Dictionary,areas:Array)->Dictionary:
 var config=layout(areas)
 if not config.ok:return config
 var ids:Array=config.ids
 if not whole(state.get("sector")) or float(state.sector)>=ids.size():return failure("Current checkpoint area is invalid.")
 var cache_ids:Array[String]=[]
 for index in state.get("caches",[]):
  if not whole(index) or float(index)>=ids.size():return failure("Current archive area is invalid.")
  cache_ids.append(ids[int(index)])
 var rows:Array[Dictionary]=[]
 for entry in state.get("metrics",[]):
  if not entry is Dictionary or not whole(entry.get("sector")) or float(entry.sector)>=ids.size():return failure("Current history area is invalid.")
  var row:Dictionary=entry.duplicate(true);row.area_id=ids[int(row.sector)];row.erase("sector");rows.append(row)
 var data={"version":VERSION,"sector_id":ids[int(state.sector)],"cache_ids":cache_ids,"metrics":rows,"blind":state.get("blind",false),"kills":state.get("kills",0),"deaths":state.get("deaths",0),"seconds":state.get("seconds",0)}
 var validated=decode(data,areas)
 return {"ok":true,"data":data} if validated.ok else validated
