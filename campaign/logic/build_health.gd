extends "res://combat_pc/components/health_component.gd"
## Optional campaign capacity adapter, leaving the approved health source intact.
## Capacity upgrades keep current hit points; checkpoints explicitly refill.
func set_capacity(value:float, refill:=false)->void:
	if not is_finite(value) or value<1:return
	_guarded_debits.clear()
	_change_generation+=1
	maximum_health=value
	_capacity=value
	_current=value if refill else minf(_current,value)
	health_changed.emit(_current,_capacity)
