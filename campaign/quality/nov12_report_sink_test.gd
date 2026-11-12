extends SceneTree
func _initialize()->void:
	var sink=preload("res://campaign/quality/nov12_report_sink.gd")
	var bad:Array[String]=["","res://new-receipt.json","relative.json","/nonexistent-moksha-parent/report.json","/tmp/../tmp/report.json"]
	var failures:Array=[]
	for path in bad:
		if sink.validate(path).is_empty():failures.append(path)
	var path:="user://sink-proof.json"
	if not sink.write_report(path,{"passed":true}).is_empty():failures.append("fresh write")
	if sink.write_report(path,{"passed":false}).is_empty():failures.append("overwrite accepted")
	if JSON.parse_string(FileAccess.get_file_as_string(path))!={"passed":true}:failures.append("original changed")
	print("REPORT_SINK_TEST ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
