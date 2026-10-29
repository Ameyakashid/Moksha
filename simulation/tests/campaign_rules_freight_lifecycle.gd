extends "res://simulation/tests/campaign_rules_rainline_contract.gd"
var heard:Array=[]
func run():
 label="Freight lifecycle"
 var m=load("res://demo/mission.tscn").instantiate();root.add_child(m);m.save_enabled=false;m.start_new(true)
 for blind in [false,true]:
  m.blind=blind;m.load_sector(3);m.input_override={};await frames(4)
  for enemy in m.enemies:enemy.process_mode=Node.PROCESS_MODE_DISABLED
  var cradle=m.room.freight_cradle;var receiver=m.room.freight_receiver;var point:Vector2=m.sectors[3].freight.cradle
  var listener=load("res://demo/components/shared_sentinel.tscn").instantiate();listener.kind="listener";listener.position=point+Vector2(-120,0);m.room.add_child(listener);listener.configure(m.player,m.bus);listener.get_node("IntentDriver").set_physics_process(false);listener.set_physics_process(false)
  listener.get_node("HearingSensor").heard.connect(func(receipt):heard.append(receipt.duplicate(true)))
  m.player.reset_actor(point+Vector2(-36,0),1);await frames(8)
  var cargo=cradle.cargo;var cargo_id:int=cargo.get_instance_id()
  m.input_override={"attack":true};await frames(1);m.input_override={}
  for i in hz:
   await frames(1)
   if is_instance_valid(cargo) and cargo.hit_count>0:break
  check(is_instance_valid(cargo) and cargo.hit_count>0 and cargo.charge>0,"real raw strike charges designated cargo")
  var heard_cargo:=false
  for receipt in heard:
   if receipt.source_id==cargo_id and receipt.kind in [&"prop_launch",&"prop_impact"]:heard_cargo=true
  check(heard_cargo,"live listener hearing receipt names actual designated cargo source")
  await key(KEY_ESCAPE)
  var charge:float=cargo.charge;var pos:Vector2=cargo.global_position;var velocity:Vector2=cargo.linear_velocity
  await frames(hz/3)
  check(cargo.charge==charge and cargo.global_position==pos and cargo.linear_velocity==velocity,"pause freezes real cargo charge and momentum")
  await key(KEY_ESCAPE)
  m.player.reset_actor(point+Vector2(-36,0),1);await frames(3)
  var health:float=m.health.current_health;var count:int=m.enemies.size();var old=weakref(cargo)
  await key(KEY_E)
  check(old.get_ref()==null and cradle.cargo.get_instance_id()!=cargo_id,"real local E retires moving original and creates fresh identity")
  check(m.health.current_health==health and m.enemies.size()==count,"local replacement does not heal or reset enemies")
  check(not receiver.is_latched and not m.room.gate_open,"replacement cannot satisfy delivery")
  cargo=cradle.cargo
  # Labelled initial pose below actual hazard; never force destruction outcome.
  cargo.invalidate_pending_contacts();cargo.global_position=Vector2(point.x,500);cargo.sleeping=false
  await frames(8)
  check(not is_instance_valid(cargo) and receiver.status=="missing","actual boundary retires lost cargo")
  var replacements:int=cradle.replacement_count
  m.player.reset_actor(point+Vector2(350,0),1);await frames(3);await key(KEY_E)
  check(cradle.replacement_count==replacements and not is_instance_valid(cradle.cargo),"E on transfer deck cannot remotely replace lost cargo")
  m.player.reset_actor(point+Vector2(-36,0),1);await frames(3);await key(KEY_E)
  check(is_instance_valid(cradle.cargo) and receiver.cargo==cradle.cargo,"local E replaces physically lost cargo")
  check(cradle.replacement_count==replacements+1,"return-to-original-cradle placement permits exactly one replacement")
  var before=weakref(cradle.cargo);await key(KEY_R);await frames(3)
  check(before.get_ref()==null and not m.room.freight_receiver.is_latched and not m.room.gate_open,"retry resets and retires former freight lifecycle")
  check(m.blind==blind and get_nodes_in_group("freight_cargo").size()==1,"retry retains sight mode with exactly one designated cargo")
 m.queue_free();await frames(3)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Labelled cradle placements; actual raw strike and Escape/E/R events. Actual listener hearing adapter with locomotion disabled; exact cargo source receipt. Actual boundary cargo retirement from labelled initial pose. Sight mode is explicit initial state, not station choice route. No route/distance proof."}
 FileAccess.open("res://simulation/evidence/campaign_rules_freight_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("FREIGHT RULES ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
