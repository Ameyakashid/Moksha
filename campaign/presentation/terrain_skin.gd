extends Node2D
## Exact visual overlays for existing collider rectangles. No guessed surfaces.
var surfaces: Array[Rect2] = []
var theme: Resource
var pavement := preload("res://assets/environment/pavement_segment.tres")
var ledge := preload("res://assets/environment/raised_ledge.tres")
func _draw() -> void:
	if theme == null: return
	for r in surfaces:
		if r.size.x <= 0 or r.size.y <= 0: continue
		var thin := r.size.y <= 18.0
		# Bounds are never extended above the authoritative top or into a floor gap.
		draw_rect(r,theme.panel.darkened(.3))
		var image: Texture2D = ledge if thin else pavement
		var tile_width := 96.0 if thin else 128.0
		var cursor := 0.0
		while cursor < r.size.x:
			var width: float = minf(tile_width,r.size.x-cursor)
			# Crop final piece instead of distorting it or drawing beyond the support.
			var texture_size := image.get_size()
			var source := Rect2(0,0,texture_size.x*width/tile_width,texture_size.y)
			draw_texture_rect_region(image,Rect2(r.position+Vector2(cursor,0),Vector2(width,minf(18,r.size.y))),source,Color(.82,.87,.9,1))
			cursor += width
		if not thin:
			for x in range(int(r.position.x)+12,int(r.end.x),64):
				draw_line(Vector2(x,r.position.y+23),Vector2(x,minf(r.end.y,r.position.y+69)),theme.edge.darkened(.6),1)
		# Quiet top edge is exact; brighter than scenery but below active telegraphs.
		draw_line(r.position,Vector2(r.end.x,r.position.y),theme.edge.lightened(.12),1)
