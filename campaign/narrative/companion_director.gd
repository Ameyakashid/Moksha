extends RefCounted
const Lines=preload("res://campaign/narrative/companion_lines.gd")
var seen:Dictionary={}
var active:Dictionary={}
var left:=0.0
var cooldown:=0.0
var room_key:=""
var enabled:=true
func reset()->void:
	seen.clear();retire();room_key="";cooldown=0
func retire()->void:
	active.clear();left=0
func tick(dt:float,room:String,events:Array[String],safe:bool)->void:
	if room!=room_key:retire();room_key=room;cooldown=maxf(cooldown,2)
	if not enabled:retire();return
	# Hidden/preempted lines are retired; already presented lines never spam again.
	if not safe:
		if not active.is_empty() and seen.has(active.id):cooldown=8
		retire();return
	cooldown=maxf(0,cooldown-dt)
	if not active.is_empty():
		if not events.has(active.event):retire();cooldown=8;return
		if not seen.has(active.id):return
		left-=dt
		if left<=0:retire();cooldown=8
		return
	if cooldown>0:return
	var best:Dictionary={}
	for entry in Lines.entries():
		if seen.has(entry.id) or not events.has(entry.event):continue
		if best.is_empty() or entry.priority>best.priority:best=entry
	if not best.is_empty():active=best.duplicate(true);left=5
func acknowledge()->void:
	if not active.is_empty():
		seen[active.id]=true
		# The opening lane observation is exclusive, even if the player later changes lanes.
		if active.id in ["rain_roof","rain_street"]:seen.rain_roof=true;seen.rain_street=true
func text()->String:
	return str(active.get("text",""))
