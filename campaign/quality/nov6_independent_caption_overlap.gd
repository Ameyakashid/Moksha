extends SceneTree
## Geometric diagnostic only, not a native visual acceptance check.
const Caption = preload("res://campaign/views/objective_caption.gd")
const Camera = preload("res://campaign/presentation/camera_follow.gd")

func boxes(spec: Dictionary, camera: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var transform := Transform2D(0, spec.at - camera + Vector2(320, 180))
	var description: Dictionary = Caption.describe(spec.kind, spec.label, false, spec.get("requires", []).is_empty(), -1, spec.get("target", 1), spec.get("optional", false))
	var lines: Array[String] = Caption._wrap(description.title, 10, 300)
	var details: Array[String] = Caption._wrap(description.detail, 9, 300)
	var height := lines.size() * 13 + details.size() * 12
	var at := Vector2(-60, (-78 if spec.kind == "rescue" else -55) - height + 13)
	var width := 0.0
	for line in lines: width = maxf(width, ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
	for line in details: width = maxf(width, ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x)
	var placed: Dictionary = Caption.place_block(at, Vector2(width + 6, height + 4), 10, transform, Rect2(0, 0, 640, 360))
	if not placed.draw: return result
	at = placed.at
	for line in lines:
		result.append(transform * Rect2(at - Vector2(3, 10), Vector2(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 6, 14)))
		at.y += 13
	for line in details:
		result.append(transform * Rect2(at - Vector2(3, 9), Vector2(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 6, 13)))
		at.y += 12
	return result

func _initialize() -> void:
	var collisions: Array[Dictionary] = []
	var rig := Camera.new()
	for district in preload("res://campaign/logic/campaign_data.gd").sectors():
		var goals: Array = district.get("objectives", [])
		for i in goals.size():
			for j in range(i + 1, goals.size()):
				var a: Dictionary = goals[i]
				var b: Dictionary = goals[j]
				if a.at.distance_to(b.at) > 450: continue
				for focus in [a.at, b.at, (a.at + b.at) * .5]:
					var camera: Vector2 = rig.reset(focus, district)
					var area := 0.0
					for one in boxes(a, camera):
						for two in boxes(b, camera): area += one.intersection(two).get_area()
					if area > 5:
						collisions.append({"district": district.id, "first": a.id, "second": b.id, "first_at": str(a.at), "second_at": str(b.at), "camera": str(camera), "overlap_area": area})
	print("NOV6_CAPTION_OVERLAP " + JSON.stringify(collisions))
	quit()
