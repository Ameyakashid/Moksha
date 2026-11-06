extends Area2D
## Passive strike receiver. Approved ContactAdapter/StrikeHealth authenticate hits.
signal struck(payload:Dictionary)
var objective:Node
func receive_strike(payload:Dictionary)->void:
	if not is_instance_valid(objective) or not objective.physical_available():return
	struck.emit(payload)
