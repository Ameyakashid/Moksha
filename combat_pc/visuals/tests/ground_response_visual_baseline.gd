extends "res://combat_pc/visuals/tests/visual_regression.gd"
## Calls original baseline checks without overwriting accepted result/sample files.
func _run() -> void:
	_geometry(); _mirrors(); _key_timing(); _foot_plants(); _ledge_grips()
	_motion_readability(); _support_motion(); _observer_contract()
	await _draw_lifecycle()
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"source_sha256":FileAccess.get_sha256("res://combat_pc/visuals/wireframe.gd"),"scope":"Unmodified baseline visual regression methods, optional presentation unset; original result and sample files untouched"}
	FileAccess.open("res://combat_pc/visuals/tests/ground_response_visual_baseline_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
