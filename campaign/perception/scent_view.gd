extends Node2D
## Receives coarse marks only. Anchor is the operator, never a source position.
const Query=preload("res://campaign/perception/local_scent_query.gd")
var marks:Array[Dictionary]=[]
var allowed:Callable
var arrival:Dictionary={}
func _process(dt:float)->void:
	for key in arrival:arrival[key]=minf(.15,float(arrival[key])+dt)
	queue_redraw()
func mark_key(mark:Dictionary)->String:
	return "%s:%s:%s:%s"%[mark.kind,mark.bearing,mark.band,mark.wounded]
func present(snapshot:Array[Dictionary],anchor:Vector2)->void:
	marks.clear()
	for mark in snapshot.slice(0,Query.MAX_MARKS):
		if Query.valid_mark(mark):marks.append(mark.duplicate(true))
	var live:Dictionary={}
	for mark in marks:
		var key:=mark_key(mark);live[key]=arrival.get(key,0.0)
	arrival=live
	position=anchor;queue_redraw()
func clear()->void:
	marks.clear();arrival.clear();queue_redraw()
func _draw()->void:
	if not allowed.is_valid() or not allowed.call():return
	for mark in marks:
		var angle:float=mark.bearing*PI/4.0
		var radius:=48.0 if mark.band=="near" else 70.0
		var center:=Vector2.from_angle(angle)*radius
		# Keep the combat pose and the upper/bottom HUD clear at small resolution.
		if not Rect2(12,118,616,192).has_point(position+center):continue
		var color:=Color(.48,.77,.69,.25 if mark.band=="near" else .15)
		var fade:float=float(arrival.get(mark_key(mark),0.0))/.15
		color.a*=fade
		if mark.kind=="supply":
			color=Color(.85,.73,.48,(.40 if mark.band=="near" else .24)*fade)
			for size in [8.0,12.0]:
				var points:=PackedVector2Array([center+Vector2(0,-size),center+Vector2(size,0),center+Vector2(0,size),center+Vector2(-size,0),center+Vector2(0,-size)])
				draw_polyline(points,color,1.0,true)
		else:
			if mark.wounded:color=Color(.85,.55,.62,color.a)
			# Local diffuse patches, not a radar circle or enemy-shaped silhouette.
			for side in ([-1.0,1.0] if mark.wounded else [0.0]):
				var patch:=center+Vector2(side*8,-2)
				for spread in [14.0,10.0,6.0]:
					draw_circle(patch,spread,Color(color.r,color.g,color.b,color.a*.22))
				for stripe in [-5.0,2.0]:
					draw_arc(patch+Vector2(0,stripe),8.0,.25,2.65,10,color,1.0,true)
