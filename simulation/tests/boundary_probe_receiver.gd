extends "res://simulation/components/boundary_receiver.gd"
## Read-only instrumentation immediately before genuine admission.
var samples: Array[Dictionary] = []
func receive_boundary(packet: Dictionary) -> Dictionary:
	var host := get_host()
	if _current(packet) and is_instance_valid(host):
		var state: Dictionary=host.hurt_response_snapshot()
		samples.append({"point":packet.point,"shield":host.shield_phase,"roll_invulnerable":host.is_roll_invulnerable(),
			"weapon":host.weapon_phase,"protected":state.protected,"action":host.main_action})
	return super.receive_boundary(packet)
