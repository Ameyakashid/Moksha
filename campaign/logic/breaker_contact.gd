extends Area2D
## Passive strike receiver. Approved ContactAdapter/StrikeHealth authenticate hits.
signal struck(payload:Dictionary)
func receive_strike(payload:Dictionary)->void:struck.emit(payload)
