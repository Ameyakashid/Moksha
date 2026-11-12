extends Node2D
## Receives coarse marks only. Anchor is the operator, never a source position.
const Query=preload("res://campaign/perception/local_scent_query.gd")
var marks:Array[Dictionary]=[]
var allowed:Callable
var safe_bounds:Callable
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
		var fade:float=float(arrival.get(mark_key(mark),0.0))/.15
		var color:=Color(.48,.77,.69,(.25 if mark.band=="near" else .15)*fade)
		if mark.kind=="supply":color=Color(.85,.73,.48,(.40 if mark.band=="near" else .24)*fade)
		elif mark.wounded:color=Color(.85,.55,.62,color.a)
		if mark.bearing==-1:color.a*=.6
		var safe:Rect2=safe_bounds.call() if safe_bounds.is_valid() else Rect2()
		for center in place_centers(mark,position,safe):draw_mark(center,mark,color)

static func place_centers(mark:Dictionary,anchor:Vector2,safe:Rect2)->Array[Vector2]:
	var result:Array[Vector2]=[]
	if not Query.valid_mark(mark) or not anchor.is_finite() or safe.size.x<=0 or safe.size.y<=0:return result
	# Reserve full patch/diamond extent, not merely its center. No target position.
	var extent:=Vector2.ONE*(23.0 if mark.kind=="life" else 13.0)
	if mark.bearing==-1:
		var centers:Array[Vector2]=[Vector2(-28,-22),Vector2(28,-22),Vector2(-28,22),Vector2(28,22)]
		for center in centers:
			if not safe.encloses(Rect2(anchor+center-extent,extent*2)):return result
		return centers
	var direction:=Vector2.from_angle(mark.bearing*PI/4.0)
	var desired:=48 if mark.band=="near" else 70
	# Shrink toward the operator, never flip/slide a cue to a different bearing.
	# If even the inner24px contour cannot fit, omit it rather than cover UI.
	for radius in range(desired,23,-2):
		var center:=direction*radius
		if safe.encloses(Rect2(anchor+center-extent,extent*2)):
			result.append(center);return result
	return result

func draw_mark(center:Vector2,mark:Dictionary,color:Color)->void:
	if mark.kind=="supply":
		for size in [8.0,12.0]:
			var points:=PackedVector2Array([center+Vector2(0,-size),center+Vector2(size,0),center+Vector2(0,size),center+Vector2(-size,0),center+Vector2(0,-size)])
			draw_polyline(points,color,1.0,true)
	else:
		# Local diffuse patches, not a radar circle or enemy-shaped silhouette.
		for side in ([-1.0,1.0] if mark.wounded else [0.0]):
			var patch:=center+Vector2(side*8,-2)
			for spread in [14.0,10.0,6.0]:
				draw_circle(patch,spread,Color(color.r,color.g,color.b,color.a*.22))
			for stripe in [-5.0,2.0]:
				draw_arc(patch+Vector2(0,stripe),8.0,.25,2.65,10,color,1.0,true)
