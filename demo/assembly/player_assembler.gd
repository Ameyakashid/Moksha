extends RefCounted
## Detached game-layer composition only. The caller owns creation and activation.
## No tree, host, room, bus, save state, binding or simulation steps belong here.
const DefeatScene = preload("res://combat_pc/components/defeat_response.tscn")
const RelayScene = preload("res://combat_pc/components/noise_relay.tscn")

static func configure_actor(player: CharacterBody2D) -> void:
	assert(not player.is_inside_tree(), "Configure the actor before activation")
	player.name = "Player"
	player.automatic_physics = false
	player.profile = preload("res://combat_pc/resources/air_response_agile.tres").duplicate(true)
	player.combat_profile = preload("res://combat_pc/resources/combat_profile.tres").duplicate(true)
	player.melee_chain = preload("res://combat_pc/resources/responsive_chain.tres")
	# View remains optional and can be swapped without affecting any contact.
	var lithe = load("res://combat_pc/visuals/lithe_wireframe.gd") if ResourceLoader.exists("res://combat_pc/visuals/lithe_wireframe.gd") else null
	if lithe != null:
		player.get_node("Visual").set_script(lithe)
	player.get_node("Visual").ground_presentation = preload("res://combat_pc/resources/ground_presentation_agile.tres")

static func attach_components(player: CharacterBody2D, health: Node) -> void:
	assert(not player.is_inside_tree(), "Attach components before activation")
	assert(health.get_parent() == null, "Health must be detached")
	health.name = "Health"
	health.maximum_health = 60.0
	player.add_child(health)
	var defeat = DefeatScene.instantiate()
	defeat.name = "DefeatResponse"
	player.add_child(defeat)
	var relay = RelayScene.instantiate()
	relay.name = "NoiseRelay"
	relay.set_script(preload("res://demo/components/mission_noise_relay.gd"))
	player.add_child(relay)
	var incoming = preload("res://simulation/components/incoming_strike_receiver.tscn").instantiate()
	incoming.counterable = true
	player.get_node("BodyShape").add_child(incoming)
	var contact_config := Node.new()
	contact_config.name = "ContactConfig"
	contact_config.set_script(preload("res://simulation/components/actor_contact_config.gd"))
	contact_config.profile = preload("res://demo/resources/player_contact.tres")
	player.add_child(contact_config)
	var impact = preload("res://simulation/components/physical_impact_receiver.tscn").instantiate()
	player.add_child(impact)
	player.add_child(preload("res://simulation/components/boundary_receiver.tscn").instantiate())
	var projectile_receiver := Node.new()
	projectile_receiver.name = "ProjectileReceiver"
	projectile_receiver.set_script(preload("res://simulation/components/projectile_receiver.gd"))
	projectile_receiver.accepted_source_layers = 32
	player.add_child(projectile_receiver)
