extends SceneTree

var failures: Array[String] = []
var jumps_passed := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func physics_steps(count: int) -> void:
	for _i in range(count):
		await physics_frame
		await process_frame

func upward_player_check(player: CharacterBody2D, platform: StaticBody2D, floor_y: float, double_jump: bool) -> void:
	Input.action_release("left")
	Input.action_release("right")
	Input.action_release("jump")
	player.position = Vector2(platform.position.x+platform.width*0.5,floor_y)
	player.velocity = Vector2.ZERO
	player.jumps = 0
	await physics_steps(4)
	Input.action_press("jump")
	var minimum_y := player.position.y
	var landed := false
	for frame in range(150):
		await physics_steps(1)
		minimum_y = minf(minimum_y,player.position.y)
		if double_jump and frame == 35: Input.action_release("jump")
		if double_jump and frame == 36: Input.action_press("jump")
		if frame > 45 and player.is_on_floor() and absf(player.position.y-platform.position.y)<2:
			landed = true
			break
	Input.action_release("jump")
	check(minimum_y < platform.position.y-1,"Player must travel upward through %s" % platform.name)
	check(landed,"Player must land on one-way %s after upward traversal" % platform.name)
	print("UPWARD PLAYER ",platform.name," min feet y=",minimum_y," landed=",landed)

func upward_prop_check(level: Node2D, platform: StaticBody2D, floor_y: float) -> void:
	var prop = load("res://scenes/props/crate.tscn").instantiate()
	prop.position = Vector2(platform.position.x+platform.width-50,floor_y-15)
	prop.lock_rotation = true
	level.add_child(prop)
	await physics_steps(4)
	prop.linear_velocity = Vector2(0,-530)
	var minimum_bottom: float = prop.position.y+14
	for _frame in range(360):
		await physics_steps(1)
		minimum_bottom = minf(minimum_bottom,prop.position.y+14)
	check(minimum_bottom < platform.position.y-5,"Rigid prop must travel upward through %s" % platform.name)
	check(absf(prop.position.y+14-platform.position.y)<3,"Rigid prop must settle on one-way %s after descent; bottom=%s" % [platform.name,prop.position.y+14])
	print("UPWARD PROP ",platform.name," min bottom y=",minimum_bottom," resting bottom=",prop.position.y+14)
	prop.free()

func run() -> void:
	var city = load("res://scenes/levels/city_prologue.tscn").instantiate()
	root.add_child(city)
	for actor in get_nodes_in_group("actors"):
		actor.simulation_enabled = false
	check(city.get_node("Actors/Enemies").get_child_count() == 3, "City must have three placed guards")
	check(city.get_node("Actors/Props").get_child_count() >= 12, "City needs physical props for impact combat")
	check(city.next_level_path == "res://scenes/levels/arcology_one.tscn", "City must lead into arcology")
	check(not city.sensory_required, "City must start without a sensory requirement")
	check(city.get_node("Actors/Player").scene_file_path == "res://scenes/actors/player.tscn", "Player must be a saved scene instance")
	check(city.get_node("GateAnchor").position.distance_to(Vector2(2110,337)) < 1, "City gate must be reachable on entry landing")
	await physics_steps(2)
	for surface in city.get_node("Terrain").get_children():
		check(surface is StaticBody2D, "City platforms must be physical")
		check(surface.get_node("CollisionShape2D").shape.size == Vector2(surface.width,surface.depth), "City collider must match Inspector dimensions")
		var should_pass_up: bool = surface.name in ["LoadingDeck","RelayDeck","MaintenanceDeck","CheckpointDeck"]
		check(surface.one_way_collision == should_pass_up,"Only thin city decks should be one-way: %s" % surface.name)
		check(surface.get_node("CollisionShape2D").one_way_collision == should_pass_up,"City collider must apply its one-way Inspector value")
	var street = city.get_node("Terrain/Street")
	street.one_way_collision = true
	check(street.get_node("CollisionShape2D").one_way_collision,"Inspector one-way changes must reach the actual collider")
	street.one_way_collision = false
	check(not street.get_node("CollisionShape2D").one_way_collision,"Inspector changes must restore solid collision")
	# Required street obstacles and the optional elevated route use real jump input.
	var street_player = city.get_node("Actors/Player")
	street_player.simulation_enabled = true
	var street_jumps := [
		[Vector2(350,400),Vector2(456,344),false],
		[Vector2(680,344),Vector2(818,300),true],
		[Vector2(1202,400),Vector2(1306,348),false],
		[Vector2(1516,400),Vector2(1606,342),true],
		[Vector2(1868,400),Vector2(1930,376),false],
		[Vector2(1936,376),Vector2(2000,352),false],
	]
	for route in street_jumps:
		Input.action_release("right")
		Input.action_release("jump")
		street_player.position = route[0]
		street_player.velocity = Vector2.ZERO
		street_player.jumps = 0
		await physics_steps(4)
		Input.action_press("right")
		Input.action_press("jump")
		var successful := false
		for frame in range(180):
			await physics_steps(1)
			if route[2] and frame == 35: Input.action_release("jump")
			if route[2] and frame == 36: Input.action_press("jump")
			if street_player.position.x >= route[1].x: Input.action_release("right")
			if frame > 25 and street_player.is_on_floor() and street_player.position.distance_to(route[1]) < 8:
				successful = true
				print("CITY JUMP PASS ",route[0]," to ",street_player.position)
				break
		check(successful,"City jump failed from %s to %s; ended %s" % [route[0],route[1],street_player.position])
	Input.action_release("right")
	Input.action_release("jump")
	await upward_player_check(street_player,city.get_node("Terrain/LoadingDeck"),400,false)
	street_player.simulation_enabled = false
	await upward_prop_check(city,city.get_node("Terrain/LoadingDeck"),400)
	street_player.simulation_enabled = true
	# A solid floor also blocks ascent from below, unlike the raised decks.
	street_player.position = Vector2(190,550)
	street_player.velocity = Vector2.ZERO
	street_player.jumps = 0
	await physics_steps(4)
	Input.action_press("jump")
	var solid_minimum := 550.0
	for _frame in range(80):
		await physics_steps(1)
		solid_minimum = minf(solid_minimum,street_player.position.y)
	Input.action_release("jump")
	check(solid_minimum >= 519,"Solid street floor must block upward traversal from beneath it")
	print("SOLID FLOOR UNDERSIDE min feet y=",solid_minimum)
	city.free()

	var shaft = load("res://scenes/levels/arcology_one.tscn").instantiate()
	root.add_child(shaft)
	var player = shaft.get_node("Actors/Player")
	player.speed_multiplier = 1.25
	for actor in get_nodes_in_group("actors"):
		if actor != player: actor.simulation_enabled = false
		if actor is RigidBody2D: actor.freeze = true
	check(shaft.sensory_required, "Arcology must require sensory trade")
	check(shaft.get_node("Actors/Enemies").get_child_count() == 4, "Arcology must have four placed guards")
	check(shaft.get_node("Actors/Props").get_child_count() >= 8, "Arcology needs physical props")
	check(shaft.next_level_path.is_empty(), "Arcology must be the last level")
	check(shaft.get_node("GateBarrier").height >= 1000, "Trade barrier must prevent jumping around it")
	check(shaft.get_node("SacrificeAnchor").position.x < shaft.get_node("GateBarrier").position.x, "Station must be reachable before opening barrier")
	await physics_steps(2)
	check(not shaft.get_node("GateBarrier/CollisionShape2D").disabled, "Trade barrier must initially collide")
	shaft.get_node("GateBarrier").set_open(true)
	await physics_steps(2)
	check(shaft.get_node("GateBarrier/CollisionShape2D").disabled, "Trade must remove physical barrier")
	for surface in shaft.get_node("Terrain").get_children():
		var should_pass_up: bool = str(surface.name).begins_with("Ascent") or surface.name == "ExitLanding"
		check(surface.one_way_collision == should_pass_up,"Only ascent ledges should be one-way: %s" % surface.name)
		check(surface.get_node("CollisionShape2D").one_way_collision == should_pass_up,"Arcology collider must apply its one-way Inspector value")
	check(not shaft.get_node("GateBarrier/CollisionShape2D").one_way_collision,"Trade barrier must remain two-way solid")
	await upward_player_check(player,shaft.get_node("Terrain/Ascent01"),1000,true)
	player.simulation_enabled = false
	await upward_prop_check(shaft,shaft.get_node("Terrain/Ascent01"),1000)
	player.simulation_enabled = true
	var source_y := 1000.0
	for number in range(1,10):
		var target = shaft.get_node("Terrain/Ascent%02d" % number) if number < 9 else shaft.get_node("Terrain/ExitLanding")
		check(is_equal_approx(source_y-target.position.y,96.0), "Ascent rises must be 96px")
		check(target.get_node("CollisionShape2D").shape.size == Vector2(target.width,target.depth), "Ascent collider must match Inspector dimensions")
		var start_x := 350.0 if number == 1 else (740.0 if number % 2 == 0 else 830.0)
		var landing_x := 443.0 if number == 1 else (834.0 if number % 2 == 0 else 736.0)
		var action := "right" if landing_x > start_x else "left"
		Input.action_release("left")
		Input.action_release("right")
		Input.action_release("jump")
		player.position = Vector2(start_x,source_y)
		player.velocity = Vector2.ZERO
		player.jumps = 0
		await physics_steps(4)
		check(player.is_on_floor(), "Jump %d must start on a real platform" % number)
		Input.action_press(action)
		Input.action_press("jump")
		var second_jump := false
		var released := false
		var landed := false
		for frame in range(150):
			await physics_steps(1)
			if not released and frame >= 35:
				Input.action_release("jump")
				released = true
			elif released and not second_jump:
				Input.action_press("jump")
				second_jump = true
			if (action == "right" and player.position.x >= landing_x) or (action == "left" and player.position.x <= landing_x):
				Input.action_release(action)
			if second_jump and player.is_on_floor() and absf(player.position.y-target.position.y)<2 and player.position.x >= target.position.x+12 and player.position.x <= target.position.x+target.width-12:
				Input.action_release(action)
				await physics_steps(12)
				landed = player.is_on_floor() and absf(player.position.y-target.position.y)<2
				print("JUMP ",number," PASS from y",source_y," to ",player.position)
				jumps_passed += 1
				break
		check(landed, "Actual player physics failed ascent jump %d; ended at %s" % [number,player.position])
		source_y = target.position.y
	Input.action_release("left")
	Input.action_release("right")
	Input.action_release("jump")
	shaft.free()
	print("LEVEL VALIDATION: ",jumps_passed," / 9 actual double jumps; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
