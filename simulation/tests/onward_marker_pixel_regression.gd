extends Node2D
## Frozen presentation snapshots, not simulated gameplay or route evidence.
## Run this scene in the existing native Godot editor, not the dummy headless renderer.
const Support = preload("res://simulation/tests/onward_marker_support.gd")
const View = preload("res://simulation/world/onward_marker.tscn")
var records: Array = []
var reuse_checks: Array = []
var failures: Array[String] = []
var status: Label
var previews: Array[TextureRect] = []
var source_hashes: Dictionary = {}
var legacy: GDScript
var oracle: GDScript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	status = Label.new(); status.position = Vector2(12,12); status.add_theme_font_size_override("font_size",12); add_child(status)
	for i in range(2):
		var preview := TextureRect.new(); preview.position = Vector2(12+i*316,62); preview.size=Vector2(304,230)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(preview); previews.append(preview)
	_run.call_deferred()
func _scan(path: String = "res://") -> void:
	var directory := DirAccess.open(path)
	for file in directory.get_files():
		if file.get_extension() in ["gd","tscn","tres","py","godot"]: source_hashes[path.path_join(file)] = FileAccess.get_sha256(path.path_join(file))
	for child in directory.get_directories():
		if child not in [".godot","delivery"]: _scan(path.path_join(child))
func viewport_for(size: Vector2i, origin: Vector2) -> SubViewport:
	var viewport := SubViewport.new(); viewport.process_mode=Node.PROCESS_MODE_PAUSABLE; viewport.size=size; viewport.world_2d=World2D.new()
	viewport.transparent_bg=false; viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	# The canvas is registered during tree entry; only then submit its transform.
	viewport.canvas_transform=Transform2D(0,origin)
	return viewport
func image_sha(image: Image) -> String:
	return Support.bytes_sha(image.get_data())
func compare(label: String, a: SubViewport, b: SubViewport, require_blank := false, save := false) -> void:
	var clocks_before := Support.clocks(a,{})
	clocks_before.merge(Support.clocks(b,{}))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var clocks_after := Support.clocks(a,{})
	clocks_after.merge(Support.clocks(b,{}))
	if clocks_before != clocks_after: failures.append(label+"_clocks_advanced_while_frozen")
	var old := a.get_texture().get_image(); var fresh := b.get_texture().get_image()
	if old == null or fresh == null or old.is_empty() or fresh.is_empty() or old.get_size()!=a.size or fresh.get_size()!=b.size:
		failures.append(label+"_invalid_rendered_images"); return
	old.convert(Image.FORMAT_RGBA8); fresh.convert(Image.FORMAT_RGBA8)
	var x := old.get_data(); var y := fresh.get_data()
	var different := 0; var maximum := 0
	if x != y:
		for pixel in range(0,mini(x.size(),y.size()),4):
			var changed := false
			for channel in range(4):
				var delta := absi(int(x[pixel+channel])-int(y[pixel+channel]))
				maximum=maxi(maximum,delta); changed=changed or delta>0
			if changed: different+=1
		if x.size()!=y.size(): different+=1
	var blank := true
	if require_blank:
		for pixel in range(0,y.size(),4):
			if y[pixel] != 0 or y[pixel+1] != 0 or y[pixel+2] != 0: blank=false; break
	var content_valid := true
	if label.ends_with("_hidden"):
		content_valid = a.has_meta("clear_bytes") and y == a.get_meta("clear_bytes")
	elif label.ends_with("_blackout_pulse"):
		var black := Image.create(old.get_width(),old.get_height(),false,Image.FORMAT_RGBA8); black.fill(Color.BLACK)
		content_valid = y != black.get_data()
	elif not require_blank:
		var uniform := Image.create(old.get_width(),old.get_height(),false,Image.FORMAT_RGBA8); uniform.fill(fresh.get_pixel(0,0))
		content_valid = y != uniform.get_data()
	var ok := different==0 and (not require_blank or blank) and content_valid and clocks_before==clocks_after
	if not ok: failures.append(label)
	records.append({"label":label,"passed":ok,"width":old.get_width(),"height":old.get_height(),"different_pixels":different,"maximum_channel_error":maximum,"legacy_rgba_sha256":image_sha(old),"current_rgba_sha256":image_sha(fresh),"blackout_rgb_zero":blank if require_blank else null,"content_valid":content_valid,"clocks_frozen":clocks_before==clocks_after})
	if save or not ok:
		old.save_png("res://simulation/evidence/onward_marker_"+label+"_legacy.png")
		fresh.save_png("res://simulation/evidence/onward_marker_"+label+"_current.png")
	previews[0].texture=ImageTexture.create_from_image(old); previews[1].texture=ImageTexture.create_from_image(fresh)
	status.text="FROZEN PRESENTATION / archived room vs placeable onward markers\n%d exact comparisons · %d failures · %s" % [records.size(),failures.size(),label]
	print("ONWARD PIXELS ",label," differences=",different," max=",maximum," blank=",blank)
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		status.text="Native rendering required; headless pixels were not tested."
		print("ONWARD PIXELS NOT RUN: headless renderer"); get_tree().quit(); return
	_scan(); legacy=Support.legacy_room_script(); oracle=Support.legacy_marker_script()
	get_tree().paused=true
	var sectors: Array = preload("res://demo/mission_data.gd").sectors()
	for index in sectors.size():
		var data: Dictionary=sectors[index]; var top:=float(data.get("top",-100)); var width:=float(data.width)
		var extent:=maxf(width+40.0,float(int(width/90)*90+131))+2.0
		var size:=Vector2i(int(ceil(extent+42)),int(ceil(604-top)))
		var left:=viewport_for(size,Vector2(42,102-top)); var right:=viewport_for(size,Vector2(42,102-top))
		await get_tree().process_frame; await RenderingServer.frame_post_draw
		var clear := left.get_texture().get_image(); clear.convert(Image.FORMAT_RGBA8); left.set_meta("clear_bytes",clear.get_data())
		var a=legacy.new(); var b=preload("res://demo/components/mission_room.gd").new()
		left.add_child(a); right.add_child(b); a.build(data); b.build(data)
		await get_tree().process_frame
		for active in [false,true]:
			a.gate_open=active; b.gate_open=active; a.relay_on=active; b.relay_on=active
			a.set_cache_found(active); b.set_cache_found(active)
			var times: Array = [0.0,0.5,2.28,7.125]
			if data.theme=="city": times.append(width/38.0-0.001);times.append(width/38.0+0.001)
			for t in times:
				a.time=t; b.time=t; a._process(0.0); b._process(0.0)
				var label: String="room%02d_%s_t%s" % [index+1,"active" if active else "initial",str(t).replace(".","p")]
				await compare(label,left,right,false,t==0.0)
		# Standard ancestor visibility contract, using complete room composition.
		a.hide(); b.hide(); await compare("room%02d_hidden" % [index+1],left,right)
		a.show(); b.show()
		var sonar_a=preload("res://demo/components/mission_sonar.gd").new(); var sonar_b=preload("res://demo/components/mission_sonar.gd").new()
		left.add_child(sonar_a); right.add_child(sonar_b)
		sonar_a.tuning=preload("res://resources/sensory/sonar_default.tres").duplicate(true); sonar_b.tuning=sonar_a.tuning.duplicate(true)
		sonar_a.bind_level(a,null); sonar_b.bind_level(b,null); sonar_a.set_blind(true); sonar_b.set_blind(true)
		await compare("room%02d_blackout_quiet" % [index+1],left,right,true,index==0)
		# Same accepted production noise API/source point; freeze before rendering.
		get_tree().paused=false
		sonar_a._on_noise_emitted(Vector2(float(data.width)-105,float(data.get("gate_y",300))-38),&"weapon_tap",1.0,a); sonar_b._on_noise_emitted(Vector2(float(data.width)-105,float(data.get("gate_y",300))-38),&"weapon_tap",1.0,b)
		sonar_a.advance_simulation(0.6); sonar_b.advance_simulation(0.6)
		get_tree().paused=true
		if sonar_a.accepted_event_count!=1 or sonar_b.accepted_event_count!=1: failures.append("room%02d_noise_not_admitted" % [index+1])
		await compare("room%02d_blackout_pulse" % [index+1],left,right,false,index==0)
		if sonar_a.last_draw_segments <= 0 or sonar_b.last_draw_segments <= 0: failures.append("room%02d_no_visible_pulse_segments" % [index+1])
		left.free(); right.free()
	await standalone_pairs()
	await independent_instances()
	get_tree().paused=false
	var after: Dictionary={}
	for path in source_hashes: after[path]=FileAccess.get_sha256(path)
	if after!=source_hashes: failures.append("source_changed_during_native_comparison")
	var report: Dictionary={"scope":"Native frozen presentation snapshots; not gameplay, physics simulation or route evidence.","engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"baseline_sha256":Support.BASELINE_SHA,"records":records,"reuse_checks":reuse_checks,"failures":failures,"tested_source_sha256":source_hashes,"sources_unchanged":after==source_hashes}
	FileAccess.open("res://simulation/evidence/onward_marker_native_pixels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	status.text="FROZEN PRESENTATION COMPLETE\n%d comparisons · %d failures · F8 stops this review" % [records.size(),failures.size()]
	print("ONWARD PIXELS COMPLETE ",records.size()," failures=",failures.size())
func standalone_pairs() -> void:
	# Focused production crops prove the marker, including elevated and ending cases.
	var sectors: Array = preload("res://demo/mission_data.gd").sectors()
	for index in sectors.size():
		var data: Dictionary=sectors[index]
		var gate:=Vector2(float(data.width)-45,float(data.get("gate_y",300)))
		for state in [false,true]:
			var left:=viewport_for(Vector2i(180,180),Vector2(90,130)-gate);var right:=viewport_for(Vector2i(180,180),Vector2(90,130)-gate)
			var a=legacy.new();var b=preload("res://demo/components/mission_room.gd").new();left.add_child(a);right.add_child(b);a.build(data);b.build(data)
			a.gate_open=state;b.gate_open=state;a.time=0;b.time=0;a._process(0);b._process(0)
			await compare("focused_room%02d_%s"%[index+1,str(state)],left,right,false,true)
			left.free();right.free()
	# Full-layer overlap: marker must remain over all background/sign paint but
	# under station/relay/cache paint, just like the archived parent draw order.
	for theme in ["city","interior"]:
		for state in [false,true]:
			var data:Dictionary={"theme":theme,"width":350,"platforms":[Rect2(280,235,90,75)],"signs":[[Vector2(273,221),"ONWARD OVERLAP"]],"station":Vector2(305,300),"relay":Vector2(300,290),"cache":Vector2(310,285)}
			var left:=viewport_for(Vector2i(500,500),Vector2(40,100));var right:=viewport_for(Vector2i(500,500),Vector2(40,100))
			var a=legacy.new();var b=preload("res://demo/components/mission_room.gd").new();left.add_child(a);right.add_child(b);a.build(data);b.build(data)
			a.gate_open=state;b.gate_open=state;a.time=2.28;b.time=2.28;a._process(0);b._process(0)
			await compare("overlap_%s_%s"%[theme,str(state)],left,right,false,true)
			left.free();right.free()
	for index in range(8):
		var left:=viewport_for(Vector2i(500,300),Vector2(200,190));var right:=viewport_for(Vector2i(500,300),Vector2(200,190))
		var anchor: Vector2=[Vector2(-20.75,-0.25),Vector2(19.5,-14.75),Vector2(-0.25,10.5),Vector2(0.75,0.25),Vector2(-31.5,17.25),Vector2(52.75,-9.5),Vector2(-72.25,-25.75),Vector2(21.25,12.75)][index]
		var a=oracle.new();a.data={"width":anchor.x+45,"gate_y":anchor.y,"ending":index%2==1};a.gate_open=index%3==0
		var b=View.instantiate();b.position=anchor;b.raster_reference=anchor;b.ending=a.data.ending;b.is_open=a.gate_open
		var pa:=Node2D.new();var pb:=Node2D.new()
		if index>=2: pa.position=Vector2(10.75,-7.25);pa.rotation=0.13;pa.scale=Vector2(1.15,0.85)
		pb.transform=pa.transform;left.add_child(pa);right.add_child(pb);pa.add_child(a);pb.add_child(b)
		await compare("anchor_decomposition_%02d"%index,left,right,false,true)
		var motion:=Vector2(17.25,-3.75);a.position=motion;b.position+=motion
		await compare("anchor_moved_%02d"%index,left,right,false,true)
		b.rotation=-0.17;b.scale=Vector2(0.85,1.2);a.transform=b.transform*Transform2D(0,-anchor)
		await compare("anchor_root_transform_%02d"%index,left,right,false,true)
		if b.raster_reference!=anchor: failures.append("transform_changed_reference_%02d"%index)
		left.free();right.free()
	# Non-default styles use a direct-draw reference, not claimed archive artwork.
	var reference:=Support.style_marker_script()
	for index in range(10):
		var left:=viewport_for(Vector2i(500,260),Vector2(180,180));var right:=viewport_for(Vector2i(500,260),Vector2(180,180))
		var a=reference.new();var b=View.instantiate();b.position=Vector2(-20.75+index*3.25,-0.25-index);b.raster_reference=b.position;b.is_open=index%2==0;b.ending=index%3==0
		b.appearance.font_size=8+index;b.appearance.open_ink=Color(0.3,0.8,0.6,0.8);b.appearance.closed_ink=Color(0.9,0.6,0.4,0.9);b.appearance.fill=Color(0.05,0.08,0.1,0.7)
		b.appearance.onward_label="SERVICE EXIT";b.appearance.ending_label="ASCENT"
		if index%2==1: b.appearance.font=preload("res://fonts/DejaVuSansMono.ttf")
		a.data={"width":b.position.x+45,"gate_y":b.position.y,"ending":b.ending};a.gate_open=b.is_open;a.style=b.appearance.duplicate(true)
		left.add_child(a);right.add_child(b);await compare("style_reference_%02d"%index,left,right,false,true);left.free();right.free()
func reuse_check(ok: bool, label: String) -> void:
	reuse_checks.append({"label":label,"passed":ok})
	if not ok: failures.append(label)
func settle() -> void:
	await get_tree().process_frame;await RenderingServer.frame_post_draw
func independent_instances() -> void:
	var left:=viewport_for(Vector2i(400,300),Vector2(100,150));var right:=viewport_for(Vector2i(400,300),Vector2(100,150))
	await settle();var blank:=left.get_texture().get_image().get_data()
	var a=View.instantiate();var b=View.instantiate();left.add_child(a);right.add_child(b)
	await settle();var baseline:=left.get_texture().get_image().get_data();var peer:=right.get_texture().get_image().get_data()
	reuse_check(baseline==peer and baseline!=blank,"independent defaults render identical nonblank content")
	a.is_open=true;await settle();reuse_check(left.get_texture().get_image().get_data()!=baseline and right.get_texture().get_image().get_data()==peer,"open state isolates target paint")
	a.is_open=false;a.ending=true;await settle();reuse_check(left.get_texture().get_image().get_data()!=baseline and right.get_texture().get_image().get_data()==peer,"ending label isolates target paint")
	a.ending=false;a.appearance.closed_ink=Color.RED;await settle();reuse_check(left.get_texture().get_image().get_data()!=baseline and right.get_texture().get_image().get_data()==peer,"resource mutation isolates target paint")
	a.appearance=preload("res://demo/views/onward_marker_appearance.gd").new();await settle();reuse_check(left.get_texture().get_image().get_data()==baseline,"replacement resource restores exact pixels")
	a.raster_reference=Vector2(-20.75,-0.25);await settle();reuse_check(left.get_texture().get_image().get_data()!=baseline and right.get_texture().get_image().get_data()==peer and a.position==Vector2.ZERO,"fractional raster reference affects only target raster")
	a.raster_reference=Vector2.ZERO;a.hide();await settle();reuse_check(left.get_texture().get_image().get_data()==blank and right.get_texture().get_image().get_data()==peer,"hidden marker clears only target paint")
	a.show();a.appearance=null;await settle();reuse_check(left.get_texture().get_image().get_data()==blank,"null appearance clears paint")
	a.appearance=preload("res://demo/views/onward_marker_appearance.gd").new();left.remove_child(a);await settle();reuse_check(left.get_texture().get_image().get_data()==blank,"detached marker clears target paint")
	a.is_open=true;a.is_open=false;left.add_child(a);await settle();reuse_check(left.get_texture().get_image().get_data()==baseline and right.get_texture().get_image().get_data()==peer,"reattachment restores independent exact pixels")
	a.free();await settle();reuse_check(left.get_texture().get_image().get_data()==blank,"deletion clears target paint")
	a=View.instantiate();left.add_child(a);await settle();reuse_check(left.get_texture().get_image().get_data()==baseline and right.get_texture().get_image().get_data()==peer,"reinstantiation restores defaults")
	left.free();right.free()
