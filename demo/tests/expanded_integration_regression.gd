extends SceneTree
const CampaignIdentity=preload("res://demo/tests/campaign_identity.gd")
## Independent production-host integration fixture. Real PC strike/cargo solver;
## explicit direct-state checkpoint, interaction and provenance boundary probes.
const Geometry=preload("res://scripts/sensory/sonar_geometry.gd")
var host
var hz:=120
var checks:Array[Dictionary]=[]
var failures:Array[String]=[]
var events:Array[Dictionary]=[]
var backups:Dictionary={}
var source_hashes:Dictionary={}
var freight_index:=-1
var works_index:=-1
var exchange_index:=-1
const OLD_SAVE="user://first_ascent_checkpoint.json"
const NEW_SAVE="user://first_ascent_expanded_checkpoint.json"
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func check(ok:bool,label:String,detail:String="")->void:
	checks.append({"label":label,"passed":ok,"detail":detail})
	if not ok:
		failures.append(label+": "+detail)
		push_error(label+": "+detail)
func frames(n:int)->void:
	for i in n:
		await physics_frame
		await process_frame
func until(test:Callable,seconds:float)->bool:
	for i in ceili(seconds*hz):
		await frames(1)
		if test.call(): return true
	return false
func key(code:int)->void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	host._unhandled_key_input(event)
func make_host()->void:
	host=load("res://demo/mission.tscn").instantiate()
	root.add_child(host)
	host.input_override={}
func stop_enemy_decisions()->void:
	for enemy in host.enemies: enemy.ai_enabled=false
func has_body(id:int,live_only:=false)->bool:
	for g in host.sonar.geometry:
		if g.body_id==id and (not live_only or Geometry.is_live(g)): return true
	return false
func has_cache()->bool:
	for g in host.sonar.geometry:
		var body=g.body.get_ref()
		if is_instance_valid(body) and body.name=="CacheContour": return true
	return false
func noise(origin:Vector2,kind:StringName,loudness:float,source:Node)->void:
	events.append({"origin":str(origin),"kind":String(kind),"loudness":loudness,"source_id":source.get_instance_id() if is_instance_valid(source) else 0})
func old_save_preserved(sentinel:String)->bool:
	return FileAccess.get_file_as_string(OLD_SAVE)==sentinel
func run()->void:
	for path in [OLD_SAVE,NEW_SAVE]:
		backups[path]=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var sentinel:="{\"version\":2,\"sector\":5,\"blind\":true,\"legacy_marker\":\"v27_preserve_bytes\"}"
	FileAccess.open(OLD_SAVE,FileAccess.WRITE).store_string(sentinel)
	FileAccess.open(NEW_SAVE,FileAccess.WRITE).store_string('{"version":2,"sector":3}')
	for path in ["res://combat_pc/player.gd","res://combat_pc/components/contact_adapter.gd","res://combat_pc/components/health_component.gd","res://combat_pc/components/noise_relay.gd","res://prop.gd","res://demo/mission.gd","res://demo/components/mission_room.gd","res://demo/components/freight_cradle.gd","res://demo/components/freight_receiver.gd","res://demo/components/relay_shutter.gd","res://demo/components/mission_sonar.gd","res://demo/mission_data.gd","res://demo/areas/freight_lock.gd","res://demo/areas/freight_journey.gd","res://demo/areas/relay_works.gd"]:
		source_hashes[path]=FileAccess.get_sha256(path)
	make_host()
	host.bus.noise_emitted.connect(noise)
	check(host.SAVE==NEW_SAVE,"expanded run uses a separate checkpoint filename")
	check(not host.continue_available and not host._valid_save(),"expanded host rejects legacy schema in expanded filename")
	host.start_new(true)
	check(CampaignIdentity.ordered(host.sectors),"production mission has exact nine stable identities in order")
	for i in host.sectors.size():
		if host.sectors[i].has("freight"): freight_index=i
		if str(host.sectors[i].id)=="relay_works": works_index=i
		if str(host.sectors[i].id)=="exchange": exchange_index=i
	check(freight_index==3 and works_index==6 and exchange_index==2,"expansion inserted at expected distinct sector identities")
	check(JSON.parse_string(FileAccess.get_file_as_string(NEW_SAVE)).version==4,"new checkpoint writes stable-ID schema four")
	check(old_save_preserved(sentinel),"new game does not overwrite v27 checkpoint bytes")
	if freight_index<0 or works_index<0 or exchange_index<0: await finish();return
	# Real host sight choice and archive interactions; position setup is explicit.
	host.load_sector(exchange_index)
	stop_enemy_decisions()
	host.player.reset_actor(host.sectors[exchange_index].station,1)
	host.interact()
	check(host.state=="choice" and paused,"exchange opens paused choice")
	host.choose_sight(true)
	check(host.blind and host.sonar.blind,"sight trade enabled on actual host")
	host.player.reset_actor(host.sectors[exchange_index].cache,1)
	host.interact()
	check(host.state=="archive" and paused and host.caches.has(exchange_index),"archive records and opens paused reader")
	check(not has_cache(),"archive interaction retires its sonar contour")
	key(KEY_E)
	check(host.state=="playing" and not paused,"archive closes through host input route")
	# Physical launch and replacement inside the production Freight Lock.
	host.load_sector(freight_index)
	stop_enemy_decisions()
	await frames(maxi(2,hz/3))
	var config:Dictionary=host.sectors[freight_index].freight
	var cradle=host.room.freight_cradle
	var receiver=host.room.freight_receiver
	var shutter=host.room.freight_shutter
	var cargo=cradle.cargo
	check(is_instance_valid(cargo) and receiver.cargo==cargo,"production room binds its designated cargo")
	check(not receiver.is_latched and not shutter.is_open and not host.room.gate_open,"freight begins with real receiver and passage closed")
	host.sonar.refresh_geometry()
	var old_id:int=cargo.get_instance_id()
	check(has_body(old_id),"intact designated cargo has real sonar contour")
	host.player.reset_actor(config.cradle-Vector2(40,0),1)
	# Damage API boundary, not a claim that this fixture damage came from an AI hit.
	var result:Dictionary=host.player.receive_attack({"amount":7.0,"impulse":Vector2.ZERO,"rollable":false})
	check(result.outcome==&"hurt" and is_equal_approx(host.health.current_health,53.0),"preserved PC damage API debits composed health")
	var hp:float=host.health.current_health
	var enemy_ids:Array=[]
	for enemy in host.enemies: enemy_ids.append(enemy.get_instance_id())
	host.interact()
	check(not cargo.alive and cargo.is_queued_for_deletion(),"replacement immediately retires previous cargo authority")
	check(not has_body(old_id),"replacement immediately removes old cargo sonar contour")
	var accepted:int=host.sonar.accepted_event_count
	host.bus.emit_noise(cargo.global_position,&"prop_impact",1.0,cargo)
	check(host.sonar.accepted_event_count==accepted,"queued retired cargo cannot emit a new reveal")
	await frames(3)
	cargo=cradle.cargo
	host.sonar.refresh_geometry()
	check(is_instance_valid(cargo) and cargo.get_instance_id()!=old_id and receiver.cargo==cargo,"deferred replacement supplies exactly the new bound cargo")
	check(has_body(cargo.get_instance_id()) and not has_body(old_id),"replacement contours contain only current designated cargo")
	check(is_equal_approx(host.health.current_health,hp),"cargo replacement does not heal player")
	var current_ids:Array=[]
	for enemy in host.enemies: current_ids.append(enemy.get_instance_id())
	check(current_ids==enemy_ids,"cargo replacement does not reset enemies")
	check(host.blind and host.caches.has(exchange_index),"cargo replacement retains global trade and archive")
	# Explicit direct-position integration fixture: the journey is intentionally
	# multi-strike. Real route observers separately prove intact full transport.
	# Here test the final physical strike/seating and existing authority boundaries.
	if config.receiver.x-config.cradle.x>400:
		cargo.global_position=Vector2(config.receiver.x-155,config.cradle.y-15)
		cargo.linear_velocity=Vector2.ZERO
		cargo.angular_velocity=0.0
		cargo.rotation=0.0
		cargo.sleeping=false
		host.player.reset_actor(Vector2(config.receiver.x-195,config.cradle.y),1)
		events.append({"kind":"explicit_final_launch_position_fixture","source_id":0,"origin":str(cargo.global_position),"player":str(host.player.position),"scope":"Not full transport proof"})
	await frames(maxi(2,hz/2))
	var contacts:int=host.player.get_node("ContactAdapter").confirmed_contacts
	host.input_override={"attack":true}
	await frames(1)
	host.input_override={}
	var latched:bool=await until(func():return receiver.is_latched,8.0)
	check(is_instance_valid(cargo) and cargo.hit_count>0 and host.player.get_node("ContactAdapter").confirmed_contacts>contacts,"ordinary PC active strike physically launches designated freight")
	check(latched,"physical final-launch fixture seats cargo in production basin",receiver.status)
	await frames(3)
	check(receiver.is_latched and shutter.is_open and shutter.collision_shape.disabled and host.room.gate_open,"real cargo seating opens physical shutter and onward gate")
	check(not has_body(shutter.get_instance_id(),true),"open freight shutter has no live ghost before refresh")
	host.sonar.refresh_geometry()
	check(not has_body(shutter.get_instance_id()),"open freight shutter removed from refreshed geometry")
	var delivery_event:=false
	for event in events:
		if event.source_id==receiver.get_instance_id() and event.kind=="prop_impact" and event.origin==str(receiver.global_position): delivery_event=true
	check(delivery_event,"receiver completion noise keeps actual receiver origin and provenance")
	var replacements:int=cradle.replacement_count
	# Restore local interaction range so this is not a trivial distant E refusal.
	host.player.reset_actor(config.cradle-Vector2(40,0),1)
	host.interact()
	await frames(2)
	check(cradle.replacement_count==replacements and receiver.is_latched,"interacting after delivery cannot replace latched freight")
	# Production retry input rebuilds local cargo while retaining global inventory.
	key(KEY_R)
	await frames(3)
	check(host.sector==freight_index and host.state=="playing","R uses production retry path in freight area")
	check(not host.room.freight_receiver.is_latched and not host.room.freight_shutter.is_open and not host.room.gate_open,"retry resets freight objective and physical shutter")
	check(is_instance_valid(host.room.freight_cradle.cargo) and host.room.freight_cradle.replacement_count==1,"retry has one fresh initial cargo")
	check(host.blind and host.caches.has(exchange_index) and is_equal_approx(host.health.current_health,60.0),"sector retry preserves trade/archive and restores checkpoint health")
	# Keep a source alive outside the retired room to exercise true foreign-source filtering.
	var stale:=Node2D.new()
	stale.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(stale)
	var stale_cargo=host.room.freight_cradle.cargo
	stale_cargo.freeze=true
	stale_cargo.reparent(stale)
	host.load_sector(works_index)
	stop_enemy_decisions()
	accepted=host.sonar.accepted_event_count
	var last_audio:Dictionary=host.audio.last_spatial_sound.duplicate(true)
	host.bus.emit_noise(host.player.global_position,&"prop_impact",2.0,stale_cargo)
	check(host.sonar.accepted_event_count==accepted and host.audio.last_spatial_sound==last_audio,"live old-room source cannot reveal or play audio in replacement room")
	check(host.sonar.event_history.is_empty(),"sector transition clears prior acoustic history")
	stale.queue_free()
	await frames(2)
	# Circuits open one matching shutter and never unlock exit early.
	check(host._relay_points().size()==3 and host.room.shutters.size()==3,"integrated Relay Works has three distinct physical circuits")
	for i in 3:
		host.player.reset_actor(host._relay_points()[i],1)
		host.interact()
		await frames(2)
		var gate=host.room.shutters[i]
		check(host.relay_states.has(i) and gate.is_open and gate.collision_shape.disabled,"relay %d opens matching live shutter"%i)
		check(not has_body(gate.get_instance_id(),true),"relay %d leaves no live acoustic shutter"%i)
		host.sonar.refresh_geometry()
		check(not has_body(gate.get_instance_id()),"relay %d shutter omitted after refresh"%i)
		check(host.room.gate_open==(i==2),"relay %d final-gate requirement exact"%i)
		host.interact()
		check(host.relay_states.count(i)==1,"relay %d repeated interaction idempotent"%i)
	host.player.reset_actor(host.sectors[works_index].cache,1)
	host.interact()
	check(host.caches.has(works_index) and not has_cache(),"expanded area archive stored without acoustic ghost")
	key(KEY_E)
	# Fresh host construction emulates app close/reopen, not just in-memory retry.
	host.metrics.append({"sector":2,"seconds":12.5,"blind":true,"health":53.0})
	host._on_defeat()
	host.show_title()
	var expected_deaths:int=host.deaths
	var expected_elapsed:float=host.elapsed
	var expected_metrics:Array=JSON.parse_string(JSON.stringify(host.metrics))
	check(old_save_preserved(sentinel),"all expanded checkpoint writes preserve v27 bytes")
	host.queue_free()
	await process_frame
	make_host()
	check(host.continue_available,"fresh host discovers expanded checkpoint")
	host.continue_run()
	stop_enemy_decisions()
	await frames(2)
	check(host.sector==works_index and host.blind and host.sonar.blind,"fresh-process Continue restores sector and sight choice")
	check(host.caches.has(exchange_index) and host.caches.has(works_index) and not has_cache(),"fresh-process Continue restores both archives without ghosts")
	check(host.deaths==expected_deaths and host.elapsed>=expected_elapsed and JSON.parse_string(JSON.stringify(host.metrics))==expected_metrics,"Continue preserves run totals and sector metric records",str({"deaths":[host.deaths,expected_deaths],"elapsed":[host.elapsed,expected_elapsed],"metrics":[host.metrics,expected_metrics]}))
	check(host.relay_states.is_empty() and not host.relay_on and not host.room.gate_open,"Continue resets local relay objectives")
	for gate in host.room.shutters: check(not gate.is_open and not gate.collision_shape.disabled,"Continue rebuilds each solid circuit shutter")
	check(is_equal_approx(host.health.current_health,60.0),"Continue restores checkpoint health")
	# Rapid retry before cargo deferred spawn may not leave an orphan from old room.
	host.load_sector(freight_index)
	host.load_sector(freight_index)
	await frames(3)
	var current_cargo=host.room.freight_cradle.cargo
	var live_designated:=0
	for node in get_nodes_in_group("freight_cargo"):
		if is_instance_valid(node) and not node.is_queued_for_deletion(): live_designated+=1
	check(live_designated==1 and is_instance_valid(current_cargo),"rapid reload fences deferred cargo creation")
	host.show_title()
	host.queue_free()
	await process_frame
	make_host()
	host.continue_run()
	await frames(3)
	check(host.sector==freight_index and not host.room.freight_receiver.is_latched and not host.room.freight_shutter.is_open,"fresh Continue rebuilds freight ready for delivery")
	check(is_instance_valid(host.room.freight_cradle.cargo) and host.room.freight_receiver.cargo==host.room.freight_cradle.cargo,"fresh Continue binds one usable freight cargo")
	check(host.blind and host.caches.has(works_index) and host.caches.has(exchange_index),"freight Continue retains global trade and archives")
	await finish()
func finish()->void:
	var changed:Array=[]
	for path in source_hashes:
		if source_hashes[path]!=FileAccess.get_sha256(path): changed.append(path)
	check(changed.is_empty(),"production and preserved sources unchanged during test",str(changed))
	paused=false
	if is_instance_valid(host): host.queue_free()
	await process_frame
	for path in backups:
		if backups[path]==null: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else: FileAccess.open(path,FileAccess.WRITE).store_buffer(backups[path])
	var report={"suite":"expanded production host integration","hz":hz,"checks":checks,"failures":failures,"events":events,"source_hashes":source_hashes,"sources_changed_during_run":changed,"scope":"Production mission host. Freight is delivered by an ordinary PC active strike and real rigid-body solver after explicit launch-position fixture setup. Checkpoint, archive/circuit interactions, damage API and stale-source boundaries use labeled direct probes. No full-route, human-duration, difficulty or visual usability claim."}
	FileAccess.open("res://demo/evidence/expanded_integration_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("EXPANDED INTEGRATION ",hz,"Hz ",checks.size()," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
