extends SceneTree
## Black-box-input full route probe. Bot reads layout/AI to plan, but measured
## play sends only PC raw button frames and proximity-limited host interactions.
## It never changes player positions, enemy health, damage, AI, or collision.
class InputDispatch extends Node:
	signal applied
	var pending: Array[Callable] = []
	func _process(_dt: float) -> void:
		if pending.is_empty(): return
		var work=pending.duplicate()
		pending.clear()
		for action in work: action.call()
		applied.emit()

var input_dispatch: InputDispatch
var host: Node
var scene_path := "res://demo/tests/relay_works_review.tscn"
var closed_shutters: Array[Rect2] = []
var shutter_signature := ""
var hz := 60
var sacrifice := false
var frame := 0
var sector_seen := -1
var waypoints: Array = []
var waypoint_index := 0
var jump_age := -1.0
var jump_released := false
var attack_clock := 0.0
var trace: Array[Dictionary] = []
var events: Array[Dictionary] = []
var failures: Array[String] = []
var retries := 0
var sector_start := 0
var last_x := 0.0
var stagnant := 0.0
var choice_done := false
var pause_done := false
var samples := {}
var report_path := ""
var source_hashes := {}
var inputs_count := {"attack":0,"jump":0,"shield":0,"roll":0,"tap":0}
var roll_exercised := false
var platforms: Array[Rect2] = []
var links: Array = []
var support := 0
var nav_trace := {}
var probe_sector := -1
var damage_receipts: Array[Dictionary] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): scene_path=arg.trim_prefix("--scene=")
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
		if arg == "--sacrifice": sacrifice = true
		if arg.begins_with("--probe-sector="): probe_sector=int(arg.trim_prefix("--probe-sector="))
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	await dispatch_ui(func(): host._unhandled_key_input(event))

func dispatch_ui(action: Callable) -> void:
	input_dispatch.pending.append(action)
	await input_dispatch.applied

func run() -> void:
	input_dispatch=InputDispatch.new()
	input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS
	root.add_child(input_dispatch)
	for path in ["res://demo/mission.gd","res://demo/mission_data.gd","res://demo/components/enemy.gd","res://combat_pc/player.gd","res://demo/tests/relay_works_route_bot.gd","res://demo/areas/relay_works.gd","res://demo/tests/relay_works_review.gd",scene_path]:
		source_hashes[path]=FileAccess.get_sha256(path)
	for directory in ["res://demo","res://demo/components"]:
		for filename in DirAccess.get_files_at(directory):
			if filename.ends_with(".gd") or filename.ends_with(".tscn"):
				var path=directory+"/"+filename
				source_hashes[path]=FileAccess.get_sha256(path)
	host = load(scene_path).instantiate()
	print("ROUTE INIT before host add")
	root.add_child(host)
	print("ROUTE INIT after host add")
	host.save_enabled = false
	if host.state != "playing": host.start_new(true)
	if probe_sector>=0:
		host.load_sector(probe_sector)
		events.append({"event":"explicit_sector_start_fixture","sector":probe_sector+1,"excluded_from_full_route_evidence":true})
	for tick in range(hz*1500):
		frame = tick
		if host.state == "complete" or (probe_sector>=0 and host.sector!=probe_sector): break
		if host.state == "dead":
			events.append({"event":"death", "sector":host.sector+1, "frame":frame,"position":str(host.player.position)})
			retries += 1
			if retries >= 12:
				failures.append("Twelve input-driven deaths; route aborted")
				break
			await key(KEY_R)
			sector_seen = -1
			host.input_override = {}
		elif host.state == "archive":
			await key(KEY_E)
			events.append({"event":"archive_read_and_close","sector":host.sector+1})
		elif host.state == "choice":
			print("ROUTE CHOICE resume frame=",frame)
			await dispatch_ui(func(): host.choose_sight(sacrifice))
			choice_done = true
			events.append({"event":"sight_choice", "sacrificed":sacrifice, "position":str(host.player.position)})
		else:
			if host.sector != sector_seen: begin_sector()
			if tick-sector_start==2: events.append({"event":"spawn_physics_acceptance","position":str(host.player.position),"grounded":host.player.grounded,"health":host.health.current_health})
			if tick == hz*2 and not pause_done:
				var before: Vector2 = host.player.position
				var elapsed_before: float = host.elapsed
				print("ROUTE PAUSE toggle frame=",frame)
				await key(KEY_ESCAPE)
				for _i in hz/2:
					await physics_frame
					await process_frame
				if host.state != "paused" or host.player.position != before or host.elapsed != elapsed_before:
					failures.append("Pause did not freeze player and active timer")
				print("ROUTE PAUSE toggle frame=",frame)
				await key(KEY_ESCAPE)
				pause_done = true
				events.append({"event":"pause_resume", "passed":host.state=="playing"})
			host.input_override = decide()
			for button in ["attack","jump","shield","roll"]:
				if host.input_override.get(button,false): inputs_count[button]+=1
			if frame % (hz/2) == 0:
				trace.append(snapshot())
				if trace.size() > 200: trace.pop_front()
			if frame % (hz*10) == 0: print("ROUTE ", snapshot())
			if frame-sector_start > hz*240:
				failures.append("Sector %d exceeded 240 simulated seconds at %s" % [host.sector+1,host.player.position])
				break
		await physics_frame
		await process_frame
	if probe_sector<0:
		if host.state != "complete": failures.append("Full route did not reach ending")
		if not choice_done: failures.append("Sight choice interaction not exercised")
		if host.metrics.size()!=host.sectors.size(): failures.append("Expected %d sector completion metrics, got %d" % [host.sectors.size(),host.metrics.size()])
	elif host.sector==probe_sector and host.state!="complete": failures.append("Explicit sector-start probe did not reach next sector")
	var changed_sources:=[]
	for path in source_hashes:
		if FileAccess.get_sha256(path)!=source_hashes[path]: changed_sources.append(path)
	if not changed_sources.is_empty(): failures.append("Production/test source changed during run: %s"%[changed_sources])
	var report := {"suite":"input-driven Relay Works isolated route", "scene":scene_path, "validation_phase":"Isolated Relay Works route with live shutter-aware navigation" if probe_sector<0 else "Explicit sector-start diagnostic fixture; not full-route evidence", "probe_sector":probe_sector, "hz":hz, "sacrificed_sight":sacrifice, "completed":host.state=="complete", "simulated_active_seconds":host.elapsed, "human_duration_validated":false, "deaths":host.deaths, "retry_count":retries,"kills":host.kills,"caches":host.caches.size(), "sectors":host.metrics, "events":events,"source_hashes":source_hashes,"sources_changed_during_run":changed_sources,"damage_receipts":damage_receipts,"input_held_frames":inputs_count,"failures":failures,"last_trace":trace,"ui_dispatch":"Choice and raw key handlers run from an ordinary PROCESS_ALWAYS callback; never unpause directly from a physics_frame await.","method":"Actual production physics driven by raw player button dictionaries and proximity interactions; layout/AI-aware deterministic bot; no measured gameplay teleports, health writes, forced kills, gate writes, or AI disabling. Timing is simulated active time, not a human playthrough."}
	report_path = "res://demo/evidence/relay_works_route_%dhz_%s.json" % [hz,"sacrificed" if sacrifice else "retained"]
	if probe_sector>=0: report_path=report_path.trim_suffix(".json")+"_probe%d.json"%(probe_sector+1)
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("RELAY WORKS ROUTE RESULT ",report_path," complete=",report.completed," active_seconds=",report.simulated_active_seconds," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func begin_sector() -> void:
	sector_seen = host.sector
	sector_start = frame
	waypoint_index = 0
	jump_age = -1
	jump_released = false
	stagnant = 0
	last_x = host.player.position.x
	waypoints = []
	shutter_signature=""
	refresh_shutters(host.sectors[host.sector],true)
	events.append({"event":"sector_enter", "sector":host.sector+1, "active_seconds":host.elapsed,"health":host.health.current_health,"enemy_tuning":host.enemies.map(func(enemy): return {"kind":enemy.kind,"health":enemy.health,"damage":enemy._damage})})
	host.player.damage_resolved.connect(func(receipt):
		var entry: Dictionary=receipt.duplicate()
		entry.merge({"sector":host.sector+1,"frame":frame,"position":str(host.player.position)})
		damage_receipts.append(entry))
	host.player.movement_event.connect(func(kind,payload):
		if (str(kind).begins_with("climb_") or "ledge" in str(kind) or "pullup" in str(kind)) and str(kind) not in ["climb_phase_changed","climb_step"]:
			events.append({"event":str(kind),"frame":frame,"sector":host.sector+1,"position":str(host.player.position),"payload":str(payload)})
			print("CLIMB ",kind," ",payload," at ",host.player.position))
	print("ENTER SECTOR ",host.sector+1," blind=",host.blind)

func snapshot() -> Dictionary:
	var p = host.player
	var alive := []
	for enemy in host.enemies:
		if is_instance_valid(enemy) and not enemy.dead: alive.append({"position":str(enemy.position),"health":enemy.health,"state":enemy.ai_state})
	return {"frame":frame,"sector":host.sector+1,"position":str(p.position),"velocity":str(p.velocity),"grounded":p.grounded,"action":p.main_action,"action_phase":p.action_phase,"raw_input":host.input_override,"weapon":p.weapon_phase,"health":host.health.current_health,"climb_needs_neutral":p._climb_needs_neutral,"closed_shutters":closed_shutters.map(func(rect): return str(rect)),"active_relays":host.relay_states.duplicate(),"waypoint":waypoint_index,"navigation":nav_trace,"enemies":alive}

func decide() -> Dictionary:
	var p = host.player
	var pos: Vector2 = p.position
	var dt := 1.0/hz
	var d: Dictionary = host.sectors[host.sector]
	var raw := {}
	refresh_shutters(d)
	attack_clock += dt
	if absf(pos.x-last_x)<0.3: stagnant += dt
	else: stagnant = 0
	last_x = pos.x
	if frame % maxi(1,hz/3)==0:
		host.tap_weapon()
		inputs_count.tap+=1
	if host.sector==0 and frame<hz/2: return {"shield":true}
	if d.get("ending",false) and not roll_exercised and p.grounded and pos.x>120:
		roll_exercised=true
		return {"right":1.0,"roll":true}
	if d.has("station") and not choice_done and host._near(d.station):
		host.interact()
		return {}
	var relay_points: Array = host._relay_points()
	for index in relay_points.size():
		if not host.relay_states.has(index) and host._near(relay_points[index]): host.interact()
	if d.has("cache") and not host.caches.has(host.sector) and host._near(d.cache): host.interact()
	var gate := Vector2(float(d.width)-45,float(d.get("gate_y",300)))
	if host._near(gate,65) and host.room.gate_open:
		events.append({"event":"sector_exit","area_id":str(d.get("id","")),"sector":host.sector+1,"active_seconds":host.elapsed,"remaining_enemies":host.remaining_enemies(),"kills_so_far":host.kills,"caches_so_far":host.caches.size(),"health":host.health.current_health,"activated_relays":host.relay_states.size(),"closed_shutters":closed_shutters.size()})
		host.interact()
		return {}
	var target := gate
	var objective := "gate"
	for index in relay_points.size():
		if not host.relay_states.has(index):
			target=relay_points[index]
			objective="relay %d"%index
			break
	if d.has("station") and not choice_done:
		target=d.station
		objective="station"
	var enemy_target: Node2D = null
	var nearest := INF
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var distance: float = pos.distance_to(enemy.position)
		if distance<nearest and (distance<115 or (d.get("lock",false) and objective=="gate")):
			nearest=distance
			enemy_target=enemy
	var in_combat := false
	if enemy_target != null:
		in_combat=absf(pos.x-enemy_target.position.x)<90 and absf(pos.y-enemy_target.position.y)<40 and enemy_target._terrain_visible(pos+Vector2(0,-20))
		if in_combat or (d.get("lock",false) and objective=="gate"):
			target=enemy_target.position
			objective="enemy"
	var nav := navigate(target,d)
	var steering: Vector2 = nav.target
	var direction := signf(steering.x-pos.x)
	if absf(steering.x-pos.x)<8: direction=0
	if in_combat:
		direction=signf(enemy_target.position.x-pos.x)
		if absf(enemy_target.position.x-pos.x)<32: direction=0
		if p.facing!=int(signf(enemy_target.position.x-pos.x)): direction=signf(enemy_target.position.x-pos.x)
		var danger: bool=absf(enemy_target.position.x-pos.x)<70 and (enemy_target.ai_state==&"active" or (enemy_target.ai_state==&"windup" and enemy_target._phase_elapsed>enemy_target._windup-0.16))
		if danger: raw.shield=true
		elif absf(enemy_target.position.x-pos.x)<54 and attack_clock>0.15:
			raw.attack=true
			attack_clock=0
	if direction>0: raw.right=1.0
	elif direction<0: raw.left=1.0
	if nav.up and absf(steering.x-pos.x)<12:
		raw.erase("attack")
		raw.erase("shield")
		raw.erase("right")
		raw.erase("left")
		if not p._climb_needs_neutral or p.main_action==&"climb": raw.up=1.0
	var jump_needed: bool=nav.jump and not in_combat
	if not in_combat and direction!=0:
		for rect in d.platforms:
			if rect.size.y<=18: continue
			var edge: float=rect.position.x if direction>0 else rect.end.x
			if (edge-pos.x)*direction>=-8 and (edge-pos.x)*direction<60 and pos.y>rect.position.y+8: jump_needed=true
		for gap in d.get("gaps",[]):
			var edge: float=gap.x if direction>0 else gap.y
			if (edge-pos.x)*direction>=-5 and (edge-pos.x)*direction<45: jump_needed=true
	if p.grounded:
		jump_age=-1
		jump_released=false
		if stagnant>0.45 and direction!=0 and not in_combat and not nav.up: jump_needed=true
		if jump_needed and not p._last_jump_held:
			jump_age=0
			raw.jump=true
	elif jump_age>=0:
		jump_age+=dt
		if jump_age<0.29: raw.jump=true
		elif not jump_released: jump_released=true
		elif jump_age<0.62: raw.jump=true
	elif pos.y>315 and p.air_jumps_left>0:
		raw.jump=true
		jump_age=0.3
		jump_released=true
	nav_trace.merge({"objective":objective,"goal":str(target),"steering":str(steering)},true)
	return raw

func refresh_shutters(d: Dictionary, force := false) -> void:
	var signature := ""
	var bounds: Array[Rect2] = []
	for shutter in host.room.shutters:
		signature += "%d:%s;"%[shutter.relay_index,str(shutter.is_open)]
		if not shutter.is_open and not shutter.collision_shape.disabled:
			# Query the actual live collider, not just authored shutter rectangles.
			var shape = shutter.collision_shape
			bounds.append(Rect2(shape.global_position-shape.shape.size*0.5,shape.shape.size))
	if not force and signature==shutter_signature: return
	closed_shutters=bounds
	shutter_signature=signature
	events.append({"event":"shutter_navigation_rebuild","frame":frame,"sector":host.sector+1,"states":signature,"closed_rectangles":bounds.map(func(rect): return str(rect))})
	build_navigation(d)

func append_surface(rect: Rect2) -> void:
	var pieces: Array[Rect2] = [rect]
	for wall in closed_shutters:
		if rect.position.y<=wall.position.y+1 or rect.position.y-36>=wall.end.y: continue
		var remaining: Array[Rect2] = []
		for piece in pieces:
			if piece.end.x<=wall.position.x or piece.position.x>=wall.end.x:
				remaining.append(piece)
				continue
			if wall.position.x-piece.position.x>=1:
				remaining.append(Rect2(piece.position,Vector2(wall.position.x-piece.position.x,piece.size.y)))
			if piece.end.x-wall.end.x>=1:
				remaining.append(Rect2(wall.end.x,piece.position.y,piece.end.x-wall.end.x,piece.size.y))
		pieces=remaining
	platforms.append_array(pieces)

func edge_crosses_closed_shutter(from: Rect2, to: Rect2) -> bool:
	for wall in closed_shutters:
		var crossing: bool=(from.end.x<=wall.position.x+1 and to.position.x>=wall.end.x-1) or (to.end.x<=wall.position.x+1 and from.position.x>=wall.end.x-1)
		# Route via the real shutter top instead of treating a tall wall as an
		# invisible floor link. Actual physics remains the final reachability test.
		if crossing and minf(from.position.y,to.position.y)>wall.position.y+1: return true
	return false

func build_navigation(d: Dictionary) -> void:
	platforms=[]
	links=[]
	var cursor:=0.0
	for gap in d.get("gaps",[]):
		append_surface(Rect2(cursor,300,gap.x-cursor,80))
		cursor=gap.y
	append_surface(Rect2(cursor,300,float(d.width)-cursor,80))
	for rect in d.platforms: append_surface(rect)
	for wall in closed_shutters: platforms.append(wall)
	for _i in platforms.size(): links.append([])
	for a in platforms.size():
		for b in platforms.size():
			if a==b: continue
			var from: Rect2=platforms[a]
			var to: Rect2=platforms[b]
			var rise:=from.position.y-to.position.y
			var gap:=maxf(0,maxf(to.position.x-from.end.x,from.position.x-to.end.x))
			var reach:=155.0 if rise>35 else 185.0
			if rise<0: reach=235
			if rise<=112 and gap<=reach and not edge_crosses_closed_shutter(from,to):
				links[a].append({"to":b,"ladder":false})
			for ladder in d.get("ladders",[]):
				var x:=float(ladder[0])
				var bottom:=float(ladder[1])
				var top:=bottom-float(ladder[2])
				if absf(from.position.y-bottom)<5 and absf(to.position.y-top)<5 and x>=from.position.x-12 and x<=from.end.x+12 and x>=to.position.x-12 and x<=to.end.x+12:
					links[a].append({"to":b,"ladder":true,"x":x})
	support=closest_surface(host.player.position)

func closest_surface(point: Vector2) -> int:
	var selected:=0
	var score:=INF
	for i in platforms.size():
		var rect: Rect2=platforms[i]
		var dx:=maxf(0,maxf(rect.position.x-point.x,point.x-rect.end.x))
		var dy:=absf(point.y-rect.position.y)
		var distance:=dy+dx*1.5
		if distance<score:
			score=distance
			selected=i
	return selected

func navigate(target: Vector2,d: Dictionary) -> Dictionary:
	var p=host.player
	var pos: Vector2=p.position
	if p.grounded: support=closest_surface(pos)
	var goal:=closest_surface(target)
	var result:={"target":target,"jump":false,"up":false}
	if support==goal:
		if target.y>pos.y+35 and absf(target.x-pos.x)<40: result.target.x+=60
		nav_trace={"support":support,"goal_surface":goal,"next":goal}
		return result
	var queue: Array[int]=[support]
	var previous:={support:-1}
	var used:={}
	while not queue.is_empty():
		var here: int=queue.pop_front()
		if here==goal: break
		for edge in links[here]:
			var next: int=edge.to
			if previous.has(next): continue
			previous[next]=here
			used[next]=edge
			queue.append(next)
	if not previous.has(goal):
		nav_trace={"support":support,"goal_surface":goal,"unreachable":true}
		result.jump=target.y<pos.y-30 and absf(target.x-pos.x)<170
		return result
	var next:=goal
	while previous[next]!=support and previous[next]!=-1: next=previous[next]
	var edge: Dictionary=used[next]
	var destination: Rect2=platforms[next]
	var from: Rect2=platforms[support]
	var direction:=1.0 if (target.x if next==goal else destination.get_center().x)>pos.x else -1.0
	if destination.position.y>from.position.y+35 and destination.position.x<=from.end.x and destination.end.x>=from.position.x:
		direction=1.0 if target.x>pos.x else -1.0
	var inset:=minf(28,destination.size.x*0.35)
	var landing:=clampf(pos.x,destination.position.x+inset,destination.end.x-inset)
	if edge.ladder:
		result.target=Vector2(edge.x,destination.position.y)
		result.up=true
	else:
		result.target=Vector2(landing,destination.position.y)
		var rise:=from.position.y-destination.position.y
		var boundary:=from.end.x if direction>0 else from.position.x
		var start_distance:=40.0 if rise<=0 else 60.0
		var horizontal_gap:=maxf(0,maxf(destination.position.x-from.end.x,from.position.x-destination.end.x))
		# For an overlapping target jump below its edge; for a separated landing,
		# walk to the departure lip before consuming the first jump.
		if horizontal_gap<1:
			result.jump=rise>10 and absf(landing-pos.x)<90
		else:
			result.jump=(boundary-pos.x)*direction<start_distance
			if not result.jump: result.target.x=boundary-direction*15
		if rise< -35 and absf(result.target.x-pos.x)<12:
			result.target.x=(from.end.x+25) if direction>0 else (from.position.x-25)
	nav_trace={"support":support,"goal_surface":goal,"next":next,"ladder":bool(edge.ladder)}
	return result
