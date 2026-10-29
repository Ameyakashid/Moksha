@tool
extends Node2D
## Center-origin paint, usable with no physics or mission host.
## Authored reference retains legacy int/truncation phase independently of placement.
const Appearance = preload("res://demo/views/floor_appearance.gd")
@export var segment_size := Vector2(320,80):
	set(value):
		if not value.is_finite() or value.x <= 0.0 or value.y <= 0.0: return
		segment_size = value
		queue_redraw()
@export var hatch_reference_x := 0.0:
	set(value):
		if not is_finite(value): return
		hatch_reference_x = value
		queue_redraw()
@export var appearance: Appearance:
	set(value):
		if appearance != null and appearance.changed.is_connected(queue_redraw): appearance.changed.disconnect(queue_redraw)
		appearance = value
		if appearance != null and not appearance.changed.is_connected(queue_redraw): appearance.changed.connect(queue_redraw)
		queue_redraw()
func _draw() -> void:
	if appearance == null: return
	var r := Rect2(-segment_size*0.5,segment_size)
	draw_rect(r,appearance.fill)
	draw_line(r.position,Vector2(r.end.x,r.position.y),appearance.outline,1.2)
	for x in range(int(hatch_reference_x)+10,int(hatch_reference_x+segment_size.x),40):
		var local_x := float(x)-hatch_reference_x+r.position.x
		draw_line(Vector2(local_x,r.position.y+4),Vector2(local_x-9,r.position.y+15),appearance.hatch,1)
