extends SceneTree
## Deterministic geometry export for a labelled reference sheet, not native UI QA.
const Lithe = preload("res://combat_pc/visuals/lithe_pose.gd")
const Baseline = preload("res://combat_pc/visuals/wireframe_pose.gd")

func _initialize() -> void:
	var rows: Array = []
	for mode in ["idle", "run", "jump", "jump_apex", "fall", "roll_start", "roll_travel", "roll_recovery", "attack_slash_active"]:
		for index in 8:
			var phase := float(index)/8.0
			var inputs := {"velocity": Vector2(260, 0), "facing": 1, "grounded": mode not in ["jump", "jump_apex", "fall"], "gait_phase": phase}
			for variant in ["baseline", "lithe"]:
				var pose := Baseline.evaluate(mode, phase, inputs) if variant == "baseline" else Lithe.evaluate(mode, phase, inputs)
				rows.append({"mode": mode, "phase": phase, "variant": variant, "pose": safe(pose)})
	FileAccess.open("res://combat_pc/tests/lithe_pose_samples.json", FileAccess.WRITE).store_string(JSON.stringify(rows)+"\n")
	quit()

func safe(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = safe(value[key])
		return result
	if value is Array:
		var result := []
		for item in value:
			result.append(safe(item))
		return result
	return value
