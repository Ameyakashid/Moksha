extends "res://campaign/tests/full_campaign_route.gd"
## Observer-only wrapper. Historical route source/reports remain untouched.
## Inherits every route specialization; only releases controls after a menu.
const ModalRouteInput=preload("res://campaign/quality/nov6_modal_route_input.gd")
func key(code:int)->void:
	var previous_state:String=host.state
	await super.key(code)
	await ModalRouteInput.release_after_resume(host,previous_state,events,frame)
