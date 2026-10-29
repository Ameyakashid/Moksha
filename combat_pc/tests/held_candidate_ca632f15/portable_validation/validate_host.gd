extends SceneTree
var actor: Node
var starts: Array = []
var charge_events: Array = []
func _initialize(): call_deferred("run_check")
func step(frame: Dictionary = {}):
 await physics_frame
 actor.physics_tick(1.0/120,frame)
func reset_case(input_profile):
 actor.reset_actor(Vector2(40,270))
 actor.melee_chain=load("res://combat_pc/resources/light_chain.tres")
 actor.melee_input_profile=input_profile
 await step()
 starts.clear()
 charge_events.clear()
func run_check():
 var host=load("res://combat_pc/minimal_host.tscn").instantiate()
 root.add_child(host)
 for i in 4: await physics_frame
 actor=host.get_node("Player")
 assert(get_nodes_in_group("combat_pc").size()==1,"isolated host must have exactly one PC")
 assert(actor.grounded and actor.allow_wall_run,"ordinary terrain and host gates must work")
 assert(root.get_child_count()==1 and root.get_node_or_null("NoiseBus")==null,"PC must run without old-game autoloads")
 actor.set_physics_process(false)
 actor.movement_event.connect(func(kind,data):
  if kind==&"attack_started":starts.append(data.duplicate(true))
  if str(kind).begins_with("charge_"):charge_events.append({"event":kind,"data":data.duplicate(true)}))
 await reset_case(null)
 for i in 160: await step({"attack":i in [0,25,50],"attack_pressed":i in [0,25,50]})
 assert(starts.map(func(row):return int(row.step_index))==[0,1,2],"fresh chain changed in isolated host")
 var fresh_count=starts.size()
 await reset_case(load("res://combat_pc/resources/held_repeat.tres"))
 for i in 240: await step({"attack":true})
 assert(starts.size()>3,"held repeat must cross one full chain boundary")
 assert(starts.slice(0,3).map(func(row):return int(row.step_index))==[0,1,2],"repeat must retain ordered chain")
 assert(starts[0].request_kind=="fresh" and starts[1].request_kind=="held_repeat","request ownership must remain explicit")
 var repeat_count=starts.size()
 for i in 120: await step()
 assert(starts.size()==repeat_count,"released repeat must not start a latent step")
 await reset_case(load("res://combat_pc/resources/held_charge.tres"))
 for i in 180: await step({"attack":true})
 assert(starts.map(func(row):return str(row.charge_role))==["starter","charged"],"charge must commit exactly starter then thrust")
 assert(actor.telemetry().attack_rearm_required,"held charge cannot silently rearm")
 var charge_count=starts.size()
 await reset_case(load("res://combat_pc/resources/held_charge.tres"))
 for i in 45: await step({"attack":true})
 assert(actor.telemetry().weapon_phase=="charge","fixture must release during actual loading")
 for i in 120: await step()
 assert(starts.size()==1,"early release must produce no additional strike")
 assert(charge_events.any(func(row):return row.event=="charge_cancelled"),"release cancellation must be observed")
 for i in 32: await step({"shield":true})
 assert(actor.telemetry().shield_phase=="hold","shield must remain usable after charge release")
 print("ISOLATED_PC_INPUT_MODES_OK ",JSON.stringify({"controller_sha256":actor.get_script().get_source_code().sha256_text(),"fresh_steps":fresh_count,"repeat_steps":repeat_count,"charged_steps":charge_count,"released_charge_steps":starts.size(),"without_old_game_autoloads":true}))
 quit()
