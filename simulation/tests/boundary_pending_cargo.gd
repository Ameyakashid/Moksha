extends "res://demo/components/mission_prop.gd"
## Test-only delivery hold of genuine solver-captured packets. Motion is untouched.
var held_impacts: Array[Dictionary] = []
var held_charges: Array[Dictionary] = []
func _deliver(target_ref: WeakRef, receiver_ref: WeakRef, packet: Dictionary) -> void:
	held_impacts.append({"target":target_ref,"receiver":receiver_ref,"packet":packet})
func _deliver_charge(target_ref: WeakRef, packet: Dictionary) -> void:
	held_charges.append({"target":target_ref,"packet":packet})
func release_held() -> void:
	for item in held_impacts: super._deliver(item.target,item.receiver,item.packet)
	for item in held_charges: super._deliver_charge(item.target,item.packet)
