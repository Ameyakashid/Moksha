extends SceneTree
## Compile and instantiate the exact archive/runtime-generated scripts used by
## native captures. This is preflight only, never evidence of rendered parity.
const Support = preload("res://simulation/tests/relay_marker_support.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var records: Array=[]
	for pair in [["archived_room",Support.legacy_room_script()],["archived_marker",Support.legacy_marker_script()],["configured_style_marker",Support.style_marker_script()]]:
		var script: GDScript=pair[1]
		assert(script.can_instantiate())
		var instance=script.new()
		assert(instance!=null)
		instance.free()
		records.append({"oracle":pair[0],"compiled":true,"source_sha256":Support.bytes_sha(script.source_code.to_utf8_buffer())})
	var style_script:=Support.style_marker_script()
	for index in range(10):
		var reference=style_script.new()
		reference.style=preload("res://demo/views/relay_marker_appearance.gd").new()
		reference.style.font_size=8+index
		if index%2==1:reference.style.font=preload("res://fonts/DejaVuSansMono.ttf")
		reference.data={"relay":Vector2(-20.75+index*3.25,-0.25-index)}
		root.add_child(reference)
		await process_frame
		reference.free()
	var report={"passed":true,"oracles":records,"style_variants":10,"scope":"Compilation/instantiation of all generated native oracle scripts; no native pixel claim."}
	FileAccess.open("res://simulation/evidence/relay_marker_oracle_preflight.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RELAY ORACLE PREFLIGHT ",JSON.stringify(report));quit()
