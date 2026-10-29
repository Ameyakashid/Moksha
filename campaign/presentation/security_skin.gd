extends Node2D
## Fill-only underlay. Existing enemy root still paints every outline/telegraph.
var actor: Node2D
func _process(_dt: float) -> void:queue_redraw()
func sample_geometry(milliseconds: float) -> Dictionary:
	if not is_instance_valid(actor):return {}
	return geometry(float(actor.facing),actor.velocity,actor.ai_state,milliseconds)
static func geometry(f: float, velocity: Vector2, state: StringName, milliseconds: float) -> Dictionary:
	var sway := sin(milliseconds*.018)*minf(absf(velocity.x)*.025,2.0)
	var lean := clampf(velocity.x/95.0,-1,1)*2.0
	var hand := Vector2(f*10,-20)
	if state == &"windup":hand=Vector2(-f*9,-27)
	if state == &"active":hand=Vector2(f*18,-22)
	return {"head":Vector2(lean,-31),"left_foot":Vector2(-5-sway,0),"right_foot":Vector2(5+sway,0),"hand":hand,"shoulder":Vector2(f*4,-24)}
func _draw() -> void:
	if not is_instance_valid(actor) or actor.blind_mode:return
	var fill := Color("536771")
	var plate := Color("91a7ad")
	if actor.kind == "listener":plate=Color("a08db5")
	elif actor.kind in ["warden","captain_lancer"]:plate=Color("b89972")
	elif actor.kind == "captain_keeper":plate=Color("80b09b")
	if actor.dead:
		var alpha := clampf(1.0-actor._death_elapsed/.9,0,1)
		draw_line(Vector2(-12,-3),Vector2(10,-3),Color(fill,alpha),5,true)
		draw_circle(Vector2(13,-5),4,Color(plate,alpha),true,-1,true)
		return
	if actor.get("_damage_flash") != null and actor._damage_flash>0:
		fill=Color(1,.97,.86);plate=fill
	var g := sample_geometry(float(Time.get_ticks_msec()))
	draw_line(Vector2(-3,-13),g.left_foot,fill,5.5,true)
	draw_line(Vector2(3,-13),g.right_foot,fill,5.5,true)
	# Broad layered shoulder/vest armor makes the body visibly solid beneath
	# the untouched original outline/telegraph view; no warning is overpainted.
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-25),Vector2(7,-25),Vector2(6,-14),Vector2(4,-10),Vector2(-4,-10),Vector2(-6,-14)]),fill)
	draw_circle(Vector2(-5,-24),3.0,plate.darkened(.12),true,-1,true)
	draw_circle(Vector2(5,-24),3.0,plate.darkened(.12),true,-1,true)
	draw_line(Vector2(-6,-14),Vector2(6,-14),Color("24363e"),2.3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-4,-24),Vector2(4,-24),Vector2(3,-18),Vector2(-3,-18)]),plate)
	draw_line(g.shoulder,g.hand,plate,5.0,true)
	draw_circle(g.hand,1.8,Color("223139"),true,-1,true)
	draw_circle(g.head,5.1,plate,true,-1,true)
	draw_line(g.head+Vector2(-3,-1),g.head+Vector2(3,-1),Color("17242d"),2.5,true)
	if actor.kind=="warden":draw_line(Vector2(-7,-26),Vector2(7,-26),plate,4,true)
