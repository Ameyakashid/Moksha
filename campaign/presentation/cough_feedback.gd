extends CanvasLayer
## Body-local proprioceptive event, not vision, hearing or field detection.
var host: Node
var ink: Node2D
class Ink extends Node2D:
	var reader: Callable
	func _draw() -> void:
		var cue: Dictionary = reader.call() if reader.is_valid() else {}
		if cue.is_empty(): return
		var p: Vector2 = cue.at
		draw_arc(p+Vector2(13,-24),10,-1.0,1.0,9,Color.WHITE,2,true)
		draw_string(ThemeDB.fallback_font,p+Vector2(-24,-48),"COUGH",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
func bind(owner: Node) -> void:
	host=owner;layer=24;process_mode=Node.PROCESS_MODE_ALWAYS
	ink=Ink.new();ink.reader=snapshot;add_child(ink)
func snapshot() -> Dictionary:
	if not is_instance_valid(host) or host.state!="playing" or host._loading_campaign or host._pending_sector>=0 or host._pending_retry or get_tree().paused: return {}
	var actor: Node2D=host.player
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree() or not actor.can_process() or actor.is_defeated() or not is_instance_valid(host.room) or host.room.is_queued_for_deletion() or not host.room.is_ancestor_of(actor): return {}
	var state: Dictionary=actor.irritant_snapshot()
	if not state.coughing: return {}
	return {"at":get_viewport().get_canvas_transform()*actor.global_position,"remaining":state.remaining}
func _process(_dt: float) -> void:
	if is_instance_valid(ink): ink.queue_redraw()
