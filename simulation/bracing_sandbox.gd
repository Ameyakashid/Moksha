extends Node2D
## Presentation reads the committed capability; only inputs/contacts drive actors.
var braced_counts := {}
func _ready() -> void:
	for actor in [$Player,$NPC]:
		actor.get_node("BodyShape/IncomingStrikeReceiver").counterable=true
		actor.get_node("ShieldCounterReceiver").response_stun_seconds=0.78
		braced_counts[actor.get_instance_id()]=0
		actor.get_node("Health").damage_processed.connect(func(receipt):
			if receipt.get("braced",0)==1 and float(receipt.applied)>0.0: braced_counts[receipt.actor_id]+=1)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_F12: get_viewport().get_texture().get_image().save_png("res://simulation/evidence/native_bracing.png")
		KEY_ESCAPE: get_tree().change_scene_to_file("res://simulation/gym.tscn")
		KEY_R: get_tree().reload_current_scene()
func _process(_dt: float) -> void:
	$HUD/Status.text="PLAYER  Health %.2f | %s / %s | braced hits %d | counters %d\nNPC  Health %.2f | %s / %s | braced hits %d | counters %d\nGold = protected commitment. Every confirmed hit still costs full Health." % [
		$Player/Health.current_health,$Player.main_action,$Player.weapon_phase,braced_counts.get($Player.get_instance_id(),0),$Player/ShieldContactAdapter.confirmed_counters,
		$NPC/Health.current_health,$NPC.main_action,$NPC.weapon_phase,braced_counts.get($NPC.get_instance_id(),0),$NPC/ShieldContactAdapter.confirmed_counters]
	queue_redraw()
func _draw() -> void:
	for actor in [get_node_or_null("Player"),get_node_or_null("NPC")]:
		if actor==null or not actor.hurt_response_snapshot().protected: continue
		var at: Vector2=actor.position
		draw_polyline(PackedVector2Array([at+Vector2(-13,-23),at+Vector2(-9,-30),at+Vector2(9,-30),at+Vector2(13,-23)]),Color(1.0,0.82,0.3),2.0)
		draw_line(at+Vector2(-12,-1),at+Vector2(12,-1),Color(1.0,0.82,0.3),2.0)
