extends Node2D
## Only a current small touched fragment. No target IDs or whole-ladder bounds.
var reader:Callable
func _draw()->void:
	if not reader.is_valid():return
	var contact:Dictionary=reader.call()
	if contact.is_empty():return
	var segments:PackedVector2Array=contact.segments
	var color:=Color(.76,.85,.83,.72 if contact.held else .48)
	for i in range(0,mini(segments.size(),10),2):
		draw_line(segments[i],segments[i+1],Color(.04,.08,.09,.75),3.0,true)
		draw_line(segments[i],segments[i+1],color,1.2,true)
