extends RefCounted
const Lines=preload("res://campaign/narrative/companion_lines.gd")
var seen:Dictionary={}
var active:Dictionary={}
var left:=0.0
var cooldown:=0.0
var room_key:=""
var enabled:=true
var catalog:Array[Dictionary]=[]
var catalog_errors:Array[String]=[]
func _init(authored:Variant=null)->void:
	var source:Variant=Lines.entries() if authored==null else authored
	catalog_errors=validate_catalog(source)
	if catalog_errors.is_empty():
		for entry in source:catalog.append(entry.duplicate(true))
static func validate_catalog(source:Variant)->Array[String]:
	var errors:Array[String]=[]
	if not source is Array or source.is_empty():return ["Expected nonempty authored array"]
	var ids:Dictionary={}
	for entry in source:
		if not entry is Dictionary:errors.append("Expected line record");continue
		if entry.keys().size()!=4:errors.append("Unexpected record shape")
		for key in ["id","event","text"]:
			if not entry.get(key) is String or str(entry.get(key,"")).strip_edges().is_empty():errors.append("Invalid "+key)
		if not entry.get("priority") is int or int(entry.get("priority",-1))<0 or int(entry.get("priority",-1))>100:errors.append("Invalid priority")
		var id:=str(entry.get("id",""))
		if ids.has(id):errors.append("Duplicate line ID")
		ids[id]=true
	return errors
func reset()->void:
	seen.clear();retire();room_key="";cooldown=0
func retire()->void:
	active.clear();left=0
func preempt()->void:
	if not active.is_empty() and seen.has(active.id):cooldown=maxf(cooldown,8)
	retire()
func tick(dt:float,room:String,events:Array[String],safe:bool)->void:
	if room!=room_key:retire();room_key=room;cooldown=maxf(cooldown,2)
	if not enabled:retire();return
	# Hidden/preempted lines are retired; already presented lines never spam again.
	if not safe:preempt();return
	cooldown=maxf(0,cooldown-dt)
	if not active.is_empty():
		if not events.has(active.event):retire();cooldown=8;return
		if not seen.has(active.id):return
		left-=dt
		if left<=0:retire();cooldown=8
		return
	if cooldown>0:return
	var best:Dictionary={}
	for entry in catalog:
		if seen.has(entry.id) or not events.has(entry.event):continue
		if best.is_empty() or entry.priority>best.priority:best=entry
	if not best.is_empty():active=best.duplicate(true);left=5
func acknowledge()->void:
	if not active.is_empty():
		seen[active.id]=true
func text()->String:
	return str(active.get("text",""))
