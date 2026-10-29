extends "res://simulation/tests/sentry_regression.gd"
## Production sentry emits normally; a real timed PC reflection physically hits
## the production Warden. Initial target placement/input source are labelled setup.
const WARDEN = preload("res://demo/components/shared_warden.tscn")
class RawSource extends Node:
	var raw := {}
	func sample_raw(_actor: Node,_dt: float) -> Dictionary: return raw.duplicate(true)
	func reset_intent() -> void: raw.clear()
func run() -> void:
	root.get_node("NoiseBus").noise_emitted.connect(noise)
	for phase in ["windup","active","recovery","lethal"]:
		await begin("genuine production reflected return / "+phase,20.0 if phase=="lethal" else 12.0,20.0,100.0,300.0 if phase in ["windup","lethal"] else 500.0)
		await launch(); npc.ai_enabled=false
		var threshold := 175.0 if phase in ["windup","lethal"] else (225.0 if phase=="active" else 280.0)
		check(await until(func():return is_instance_valid(first_shot()) and first_shot().position.x<threshold),"outbound carrier physically passes future intervening position")
		var other := WARDEN.instantiate(); other.position=Vector2(220,200) if phase in ["windup","lethal"] else Vector2(300,200); other.initial_facing=-1; other.ai_enabled=false
		var old: Node=other.get_node("InputSource"); other.remove_child(old); old.free()
		var raw := RawSource.new(); raw.name="InputSource"; other.add_child(raw)
		world.add_child(other); other.configure(pc,root.get_node("NoiseBus"))
		var health_facts: Array[Dictionary]=[]
		other.get_node("Health").damage_processed.connect(func(receipt):health_facts.append(receipt.merged({"phase_at_health":other.weapon_phase,"elapsed_at_health":other._phase_elapsed})))
		await frames(3); raw.raw={"attack":true}
		check(await until(func():return other.weapon_phase==&"windup"),"ordinary shared input commits actual Warden warning")
		raw.raw={}
		await until(func():return is_instance_valid(first_shot()) and first_shot().position.x-pc.position.x<38)
		driver.frame={"shield":true}
		check(await until(func():return not health_facts.is_empty()),"actual PC-owned reflected sweep reaches registered Warden body")
		check(contacts.size()==2 and contacts[0].get("reflection_confirmed",false) and contacts[1].get("reflected",false),"independent genuine reflection and returned contact receipts")
		var lethal: bool = phase=="lethal"
		check(other.health==(0.0 if lethal else 4.0) and health_facts.size()==1 and health_facts[0].applied==(16.0 if lethal else 12.0),"full canonical returned damage with actual lethal clamp")
		if not lethal:
			var braced: bool = phase!="recovery"
			check(bool(health_facts[0].braced)==braced and bool(health_facts[0].applied_recoil)!=braced,"return stun0.5 follows actual phase-qualified threshold0.7")
			check(other.weapon_phase==StringName(phase) if braced else other.main_action==&"hurt","real committed phase survives only braced returned response actual="+String(other.weapon_phase)+" elapsed="+str(other._phase_elapsed))
			check(other.pressure_phase and other.braced_contacts==(1 if braced else 0),"real Health drives one phase and truthful brace count")
			if braced: check(other._recovery==.64 and other.hitpause_remaining>0,"same pending cut recovery accelerates with shared hitpause")
		else: check(other.dead and other.weapon_phase==&"idle" and not other.pressure_phase,"lethal brace retires action without spurious phase2")
		check(pc.get_node("Health").current_health==60 and npc.health==20,"reflector and original shooter remain untouched behind physical interception")
		await finish()
	print("WARDEN PROJECTILE %d Hz: %d scenarios, %d checks, %d failures" % [hz,scenarios.size(),checks.size(),failures.size()])
	for failure in failures: printerr(failure)
	FileAccess.open("res://simulation/evidence/warden_projectile_%d.json" % hz,FileAccess.WRITE).store_string(JSON.stringify({"hz":hz,"scenarios":scenarios,"checks":checks,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
