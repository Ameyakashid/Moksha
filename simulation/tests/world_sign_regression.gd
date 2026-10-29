extends SceneTree
const Sign = preload("res://simulation/world/world_sign.tscn")
const Appearance = preload("res://demo/views/sign_appearance.gd")
const Support = preload("res://simulation/tests/world_sign_support.gd")
var hz := 60
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func signs(node: Node) -> Array:
	var result: Array=[]
	for child in node.get_children():
		if child.get_script()==preload("res://simulation/world/world_sign.gd"): result.append(child)
	return result
func _run() -> void:
	var legacy:=Support.legacy_room_script()
	var count:=0
	for data in preload("res://demo/mission_data.gd").sectors():
		var world:=Node2D.new();root.add_child(world)
		var old=legacy.new();var fresh=preload("res://demo/components/mission_room.gd").new()
		world.add_child(old);world.add_child(fresh);old.build(data);fresh.build(data)
		check(Support.topology(old,[])==Support.topology(fresh,[]),"exact ordered physical topology")
		check(Support.contours(old)==Support.contours(fresh),"exact ordered collision-derived sonar contours")
		var instances:=signs(fresh);var authored: Array=data.get("signs",[])
		check(instances.size()==authored.size(),"one instance per authored sign")
		for i in instances.size():
			var sign_view=instances[i];count+=1
			check(sign_view.position==authored[i][0] and sign_view.text==authored[i][1] and sign_view.baseline_offset==Vector2.ZERO and sign_view.raster_reference==authored[i][0],"authored placement/text preserved")
			check(sign_view.show_behind_parent and sign_view.appearance.font==null and sign_view.appearance.font_size==9 and sign_view.appearance.font_color==Color("89b2b6") and sign_view.appearance.width==-1 and sign_view.appearance.alignment==HORIZONTAL_ALIGNMENT_LEFT,"original rendering defaults/order")
			check(Support.topology(sign_view,[]).is_empty() and Support.contours(sign_view).is_empty(),"decorative signs add no physics or contours")
		world.free()
	check(count==14,"all fourteen production signs extracted")
	var world:=Node2D.new();root.add_child(world)
	var a=Sign.instantiate();var b=Sign.instantiate();world.add_child(a);world.add_child(b)
	check(a.get_child_count()==0 and not a is CollisionObject2D,"standalone sign has no host or physics")
	check(a.appearance!=b.appearance,"default appearance resource isolated")
	a.raster_reference=Vector2(-20.75,-0.25)
	a.text="CUSTOM";a.baseline_offset=Vector2(-7.75,12.25);a.appearance.font_size=17;a.appearance.font_color=Color.RED
	a.appearance.alignment=HORIZONTAL_ALIGNMENT_CENTER;a.appearance.width=180
	var font:=preload("res://fonts/DejaVuSansMono.ttf").duplicate(true);a.appearance.font=font
	check(b.raster_reference==Vector2.ZERO and b.text=="WORLD SIGN" and b.baseline_offset==Vector2.ZERO and b.appearance.font_size==9 and b.appearance.font_color==Color("89b2b6") and b.appearance.font==null,"configuration edits do not leak")
	check(font.changed.is_connected(a.appearance._font_changed),"custom font live-change subscription")
	var prior=a.appearance;var replacement=Appearance.new();a.appearance=replacement
	check(not prior.changed.is_connected(a.queue_redraw) and replacement.changed.is_connected(a.queue_redraw),"appearance replacement disconnects retired redraw")
	a.appearance=prior
	prior.font=null
	check(not font.changed.is_connected(prior._font_changed),"font replacement disconnects retired font")
	prior.font=font
	b.appearance=prior;prior.font_size=19
	check(b.appearance.font_size==19,"explicit resource sharing supported")
	b.appearance=prior.duplicate(true);prior.font_size=21
	check(b.appearance.font_size==19 and b.appearance.font!=a.appearance.font,"deep duplication isolates style and custom font")
	a.raster_reference=Vector2(NAN,0);a.baseline_offset=Vector2(INF,0);prior.font_size=0;prior.width=-2;prior.width=INF;prior.alignment=-1
	check(a.raster_reference==Vector2(-20.75,-0.25) and a.baseline_offset==Vector2(-7.75,12.25) and prior.font_size==21 and prior.width==180 and prior.alignment==HORIZONTAL_ALIGNMENT_CENTER,"invalid configuration retains last valid values")
	var parent:=Node2D.new();parent.position=Vector2(30,-50);parent.rotation=0.3;parent.scale=Vector2(1.3,0.8);world.add_child(parent)
	a.reparent(parent);a.position=Vector2(12.5,-4.75);a.rotation=-0.2;a.scale=Vector2(0.8,1.2)
	check(a.raster_reference==Vector2(-20.75,-0.25),"reference remains fixed across reparenting and root transforms")
	check(a.to_global(a.baseline_offset).is_equal_approx((parent.global_transform*a.transform)*a.baseline_offset),"nested local anchor follows native transforms")
	a.hide();check(not a.is_visible_in_tree(),"visibility supported");a.show();parent.hide();check(not a.is_visible_in_tree(),"ancestor visibility supported");parent.show()
	var pack:=PackedScene.new();check(pack.pack(a)==OK,"configured sign packs")
	check(ResourceSaver.save(pack,"user://world_sign_roundtrip.tscn")==OK,"configured sign saves")
	var restored=load("user://world_sign_roundtrip.tscn").instantiate();world.add_child(restored)
	check(restored.raster_reference==a.raster_reference and restored.text==a.text and restored.baseline_offset==a.baseline_offset and restored.transform==a.transform and restored.appearance.font_size==21 and restored.appearance.font_color==Color.RED and restored.appearance.alignment==HORIZONTAL_ALIGNMENT_CENTER and restored.appearance.width==180 and restored.appearance.font!=null,"all exports survive save/reload")
	a.appearance=null;a.text="NO PAINT";a.baseline_offset=Vector2.ONE
	check(Support.topology(a,[]).is_empty() and Support.contours(a).is_empty(),"null paint is still nonphysical")
	a.free();var c=Sign.instantiate();parent.add_child(c)
	check(c.appearance.font_size==9 and c.text=="WORLD SIGN","replacement has fresh defaults")
	world.free()
	var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"production_signs":count}
	FileAccess.open("res://simulation/evidence/world_sign_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WORLD SIGN ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
