extends SceneTree
## Direct-state integration fixtures, not route play or duration evidence.
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var host=load("res://demo/tests/relay_works_review.tscn").instantiate()
	root.add_child(host)
	host.input_override={}
	for i in 60:await physics_frame
	check(host.player.position.distance_to(Vector2(host.sectors[0].get("spawn",Vector2(100,300))))<2,"unobstructed actual spawn settles without ejection")
	check(host.player.grounded,"spawn supported by real floor")
	check(host.room.shutters.size()==3,"three distinct physical circuits")
	check(host._cache_total()==1,"isolated archive total truthful")
	check(not host.room.gate_open,"exit needs all circuits")
	for gate in host.room.shutters:
		check(not gate.is_open and not gate.collision_shape.disabled,"initial shutter actually solid")
	host.interact()
	check(host.state=="choice","spawn station presents real sight choice")
	host.choose_sight(false)
	check(not host.blind and host.state=="playing","retained sight viable")
	host.interact()
	host.choose_sight(true)
	check(host.blind and host.sonar.blind,"sacrificed sight uses actual blackout")
	for i in 3:
		host.player.reset_actor(host._relay_points()[i],1)
		host.interact()
		await process_frame
		await process_frame
		var gate=host.room.shutters[i]
		check(gate.is_open and gate.collision_shape.disabled,"relay opens corresponding actual shutter")
		check(host.relay_states.has(i),"relay activation stored once")
		host.sonar.refresh_geometry()
		var ghost:=false
		for contour in host.sonar.geometry:
			if contour.anchor.get_ref()==gate.collision_shape:ghost=true
		check(not ghost,"open shutter does not leave sonar ghost")
		check(host.room.gate_open==(i==2),"exit opens only after final circuit")
	host.load_sector(0)
	await process_frame
	check(host.blind,"retry retains sight trade")
	check(host.relay_states.is_empty() and not host.room.gate_open,"retry resets circuit objectives")
	for gate in host.room.shutters:check(not gate.is_open,"retry rebuilds solid shutter")
	check(host.player.position.distance_to(Vector2(host.sectors[0].get("spawn",Vector2(100,300))))<2,"retry returns to safe hub spawn")
	paused=true
	var before:Vector2=host.player.position
	for i in 10:await physics_frame
	check(host.player.position==before,"pause freezes actual actor")
	paused=false
	host.queue_free()
	await process_frame
	var f=FileAccess.open("res://demo/evidence/relay_works_contracts.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Direct-state integration only, not route or duration evidence"},"\t"))
	print("RELAY WORKS CONTRACTS ",checks," failures ",failures)
	quit(0 if failures.is_empty() else 1)
