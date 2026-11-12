extends SceneTree
const Atmosphere=preload("res://campaign/presentation/arcology_atmosphere.gd")
const Scenery=preload("res://campaign/presentation/campaign_scenery.gd")
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:push_error(label);quit(1)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=Atmosphere.new()
	root.add_child(a)
	seed(312)
	var expected=randi()
	seed(312)
	a.configure({"id":"rainline","width":4800})
	check(randi()==expected,"Must not consume global RNG")
	check(a.citizens.size()==144,"Bounded population")
	check(a.get_child_count()==0,"No per-citizen nodes")
	var original=a.citizens.duplicate(true)
	a.configure({"id":"rainline","width":4800})
	check(a.citizens==original,"Deterministic district profile")
	a.configure({"id":"other","width":4800})
	check(a.citizens!=original,"District variation")
	a.hide()
	var t=a.visual_time
	a._process(1.0)
	check(a.visual_time==t,"Hidden presentation freezes")
	a.show()
	a._process(.5)
	check(a.visual_time>t,"Visible presentation animates")
	a.free()
	var s=Scenery.new()
	s.z_index=-5
	root.add_child(s)
	for level in range(1,6):
		s.configure({"id":"rainline","width":4800,"level":level})
		check(s.get_child_count()==2,"Stable scenery host shape")
		check(s.backdrop.drawing_enabled==(level not in [1,2,3,4]),"No hidden duplicate backdrop drawing")
		check(is_instance_valid(s.atmosphere)==(level in [1,2,3,4]),"Only explicit rich background profiles")
		if level==1:
			check(s.atmosphere.get_script()==Atmosphere,"Level1 retains original arcology renderer")
			check(s.atmosphere.citizens.size()==144,"Level1 population remains144")
		if level==2:
			check(s.atmosphere.get_script()==preload("res://campaign/presentation/foundry_atmosphere.gd"),"Level2 explicitly selects foundry renderer")
			check(s.atmosphere.MAX_VISIBLE_WORKERS==9,"Level2 exact sparse worker bound")
		if level==3:
			check(s.atmosphere.get_script()==preload("res://campaign/presentation/cistern_atmosphere.gd"),"Level3 explicitly selects waterworks renderer")
			check(s.atmosphere.MAX_DRIPS==6,"Level3 bounded atmospheric motion")
		if level==4:
			check(s.atmosphere.get_script()==preload("res://campaign/presentation/memory_atmosphere.gd"),"Level4 explicitly selects memory renderer")
			check(not s.atmosphere.is_processing(),"Level4 static view never ticks")
		if is_instance_valid(s.atmosphere):
			check(s.atmosphere.get_parent()==s.backdrop,"District ownership")
			check(s.z_index+s.backdrop.z_index+s.atmosphere.z_index<0,"Behind gameplay actors")
			s.update_view(Vector2(500,100),Vector2(640,360))
			check(s.atmosphere.camera_center==Vector2(500,100),"Explicit camera")
			s.set_sight_enabled(false)
			check(not s.atmosphere.is_visible_in_tree(),"Sight trade hides entire subtree")
			s.set_sight_enabled(true)
		await process_frame
	s.queue_free()
	await process_frame
	print("NOV12_ATMOSPHERE_PASS: %d checks; 144 specs, zero per-citizen nodes, deterministic RNG-isolated, district-owned, behind actors, blind-safe"%checks)
	quit()
