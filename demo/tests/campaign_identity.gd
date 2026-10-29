extends RefCounted
## Active campaign contract; historical v3 ordering belongs exclusively to checkpoint_codec.
const ORDER=["rainline","quarantine_intake","exchange","freight_lock","cistern","upper_residential_crossing","relay_works","lift_warden","above_the_rain"]
static func index(areas:Array,id:String)->int:
 for i in areas.size():
  if str(areas[i].get("id",""))==id:return i
 assert(false,"Missing required campaign identity: "+id)
 return -1
static func ordered(areas:Array)->bool:
 return areas.map(func(area):return str(area.get("id","")))==ORDER
