extends "res://campaign/tests/full_campaign_route.gd"
## Observer-only wrapper. Historical route source/reports remain untouched.
## Inherits every route specialization; only releases controls after a menu.
var _freight_route_input=preload("res://campaign/quality/nov6_freight_route_input.gd").new()
const ModalRouteInput=preload("res://campaign/quality/nov6_modal_route_input.gd")
func key(code:int)->void:
	var previous_state:String=host.state
	await super.key(code)
	await ModalRouteInput.release_after_resume(host,previous_state,events,frame)

func freight_45_plan(data:Dictionary)->Dictionary:
	return _freight_route_input.filter_plan(host,data,super.freight_45_plan(data),frame,hz,events)
