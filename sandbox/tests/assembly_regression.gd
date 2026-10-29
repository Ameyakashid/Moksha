extends SceneTree
var hz:=60
var checks:Array=[]
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks.append({"label":label,"passed":ok})
	if not ok:failures.append(label)
func frames(n:int)->void:
	for i in ceili(float(n)*hz/60):await physics_frame;await process_frame
func press(code:int,down:bool)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down;Input.parse_input_event(event)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz;run.call_deferred()
func run()->void:
	var traversal=preload("res://sandbox/stations/traversal.tscn").instantiate()
	# Labeled fixture placement on moving platform; subsequent carry is real physics.
	traversal.get_node("Player").position=Vector2(240,293)
	root.add_child(traversal);await frames(10)
	var player=traversal.get_node("Player");var lift=traversal.get_node("Lift")
	var start_y:float=player.position.y;var lift_y:float=lift.position.y
	await frames(60)
	check(lift.position.y<lift_y-10,"lift motor moves actual platform")
	check(player.position.y<start_y-10 and player.grounded,"shared PC carried by actual lift support")
	check(not traversal.get_node("Ladder").climb_geometry().is_empty(),"editor ladder exposes actual climb geometry")
	check(traversal.get_node("Ladder").get_node("SonarRails").collision_layer==0,"ladder contour remains nonblocking")
	check(traversal.get_node("Cargo").collision_mask==43,"placed cargo retains production mask")
	traversal.queue_free();await frames(3)
	var combat=preload("res://sandbox/stations/combat.tscn").instantiate();root.add_child(combat);await frames(5)
	var pc=combat.get_node("Player");var npc=combat.get_node("NPC");var x:float=npc.position.x
	check(pc.get_script()==npc.get_script(),"PC and NPC use identical movement/combat script")
	check(pc.get_node("IntentDriver").get_script()==npc.get_node("IntentDriver").get_script(),"PC and NPC share intent scheduler")
	await frames(180)
	check(npc.position.x<x-20,"live NPC policy approaches through actual shared controller")
	check(pc.get_node("Health").current_health<=30 and npc.get_node("Health").current_health<=30,"shared Health components active")
	combat.queue_free();await frames(3)
	var freight=preload("res://sandbox/stations/freight.tscn").instantiate();root.add_child(freight);await frames(10)
	var cradle=freight.get_node("Cradle");var receiver=freight.get_node("Receiver");var shutter=freight.get_node("Shutter")
	check(is_instance_valid(cradle.cargo) and cradle.receiver==receiver,"cradle spawns real bound cargo")
	check(not receiver.is_latched and not shutter.is_open,"freight begins unsolved and closed")
	var old:int=cradle.cargo.get_instance_id()
	press(KEY_E,true);await frames(1);press(KEY_E,false);await frames(4)
	check(is_instance_valid(cradle.cargo) and cradle.cargo.get_instance_id()!=old,"real E dispatch replaces nearby designated cargo")
	# One genuine input attack; record physical outcome without forcing latch.
	press(KEY_J,true);await frames(1);press(KEY_J,false);await frames(180)
	check(cradle.cargo.position.x!=cradle.cargo_offset.x,"real J contact launches cargo")
	check(receiver.is_latched and shutter.is_open,"real launched cargo settles and opens shutter through signal")
	var observed={"receiver_latched":receiver.is_latched,"shutter_open":shutter.is_open,"cargo_position":str(cradle.cargo.global_position)}
	freight.queue_free();await frames(3)
	FileAccess.open("res://sandbox/evidence/assembly_regression_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"freight_observed":observed,"scope":"Editor scene composition with actual support carry, live AI and dispatched E/J; initial lift placement is explicit test setup."},"\t"))
	print("ASSEMBLY ",checks.size()," checks; failures ",failures)
	quit(0 if failures.is_empty() else 1)
