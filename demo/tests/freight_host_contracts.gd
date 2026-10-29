extends SceneTree
## Integration fixture: player positioned at cradle, then real raw J contact.
## Not a navigation playthrough or duration measurement.
var failures:Array[String]=[]
var checks:=0
var hz:=60
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	var host=load("res://demo/tests/freight_lock_review.tscn").instantiate()
	root.add_child(host)
	host.input_override={}
	for enemy in host.enemies:enemy.process_mode=Node.PROCESS_MODE_DISABLED
	for i in 10:await physics_frame
	check(not host.room.gate_open,"freight exit initially sealed")
	check(not host.room.freight_shutter.is_open,"actual freight barrier initially solid")
	host.player.reset_actor(Vector2(1214,240),1)
	for i in 10:await physics_frame
	host.interact()
	for i in 5:await physics_frame
	check(not host.room.freight_receiver.is_latched,"E replacement cannot complete physical delivery")
	check(not host.room.gate_open,"E alone cannot open exit")
	host.health._current=36 # Fixture precondition: replacement must not heal.
	var old=host.room.freight_cradle.cargo
	host.interact()
	for i in 5:await physics_frame
	check(not is_instance_valid(old) or not old.is_in_group("props"),"replacement removes previous live prop")
	check(host.health.current_health==36,"replacement leaves health unchanged")
	host.input_override={"attack":true}
	await physics_frame
	host.input_override={}
	for i in hz*10:
		await physics_frame
		if host.room.freight_receiver.is_latched:break
	check(host.room.freight_receiver.is_latched,"real raw J strike launches and seats original crate")
	await process_frame
	await process_frame
	check(host.room.freight_shutter.is_open,"seated cargo opens actual barrier")
	check(host.room.gate_open,"seated cargo opens onward objective")
	var seated=host.room.freight_cradle.cargo
	host.interact()
	await process_frame
	check(host.room.freight_cradle.cargo==seated,"success disables replacement")
	host.load_sector(0)
	await process_frame
	check(not host.room.freight_receiver.is_latched and not host.room.gate_open,"retry resets physical objective")
	check(host.health.current_health==60,"retry restores health")
	paused=false
	host.queue_free()
	await process_frame
	var f=FileAccess.open("res://demo/evidence/freight_host_contracts_%dhz.json"%hz,FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Direct-position host fixture with real raw J launch, not route/pacing"},"\t"))
	print("FREIGHT HOST CONTRACTS ",checks," failures ",failures)
	quit(0 if failures.is_empty() else 1)
