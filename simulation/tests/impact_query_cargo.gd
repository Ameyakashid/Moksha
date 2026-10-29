extends "res://simulation/components/physical_cargo.gd"
## Explicit extension-query callback probe around real captured source scope.
var before_query: Callable
var query_count := 0
func physical_impact_is_current(packet: Dictionary, target: Node) -> bool:
	query_count += 1
	if before_query.is_valid(): before_query.call(packet,target,query_count)
	return super.physical_impact_is_current(packet,target)
