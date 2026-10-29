extends Node2D
## Legacy eight-area presentation pairs, not current-campaign coverage or physical playthroughs.
var records: Array = []
var failures: Array[String] = []
var sources: Dictionary = {}
func _ready() -> void: run.call_deferred()
func viewport() -> SubViewport:
	var v:=SubViewport.new();v.size=Vector2i(640,360);v.world_2d=World2D.new()
	v.transparent_bg=false;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(v);return v
func legacy_areas() -> Array[Dictionary]:
	var live: Array[Dictionary]=preload("res://demo/mission_data.gd").sectors()
	var sector_data: Array[Dictionary]=[]
	for id in preload("res://demo/components/checkpoint_codec.gd").V3_IDS:
		sector_data.append(live.filter(func(area):return str(area.get("id",""))==id)[0])
	return sector_data
func setup(host: Node, c: Dictionary) -> Array:
	var sector_data := legacy_areas()
	host.sectors=sector_data;host.sector=c.get("sector",0);host.state=c.get("state","playing")
	host.blind=c.get("blind",false);host.continue_available=c.get("continue",false)
	host.intro_time=c.get("time",0.0);host.elapsed=137.75;host.deaths=3;host.kills=17
	host.notice_left=1.0 if c.get("notice",false) else 0.0;host.notice="TEST / Original notice"
	host.chapter_left=1.0 if c.get("chapter",false) else 0.0
	host.archive_text="Recovered archive.\nA second line."
	var p:=CharacterBody2D.new();p.position=c.get("point",Vector2(-200,-200));host.player=p
	if c.get("no_player",false):host.player=null
	var health=preload("res://combat_pc/components/health_component.gd").new();health._current=c.get("health",57.5);host.health=health
	var room=preload("res://demo/components/mission_room.gd").new();host.room=room
	var receiver=preload("res://demo/components/freight_receiver.gd").new();room.freight_receiver=receiver
	receiver.is_latched=c.get("latched",false);room.gate_open=c.get("open",false)
	host.relay_on=c.get("relay_on",false)
	host.relay_states.assign([0] if c.get("partial",false) else [])
	host.caches.assign([1,3] if c.get("caches",false) else [])
	return [p,health,room,receiver]
func compare(c: Dictionary) -> void:
	var left:=viewport();var right:=viewport()
	var oracle=preload("res://simulation/tests/hud_legacy_oracle.gd").new()
	var mission=preload("res://demo/mission.gd").new()
	if c.has("review"):
		oracle.free();mission.free()
		oracle=load("res://simulation/tests/hud_"+c.review+"_oracle.gd").new()
		mission=load("res://demo/tests/"+c.review+".gd").new()
	var garbage:=setup(oracle,c);garbage.append_array(setup(mission,c))
	left.add_child(oracle)
	var hud=preload("res://simulation/ui/mission_hud.tscn").instantiate();right.add_child(hud)
	if not hud.set_snapshot(mission._hud_snapshot()): failures.append(c.label+" rejected snapshot")
	if c.get("hidden",false):oracle.hide();hud.hide()
	if c.get("null_style",false):oracle.hide();hud.appearance=null
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	var a:=left.get_texture().get_image();var b:=right.get_texture().get_image();a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
	var x:=a.get_data();var y:=b.get_data();var different:=0
	for i in range(0,x.size(),4):
		if x[i]!=y[i] or x[i+1]!=y[i+1] or x[i+2]!=y[i+2] or x[i+3]!=y[i+3]:different+=1
	var passed:=different==0
	if not passed:failures.append(c.label)
	records.append({"label":c.label,"passed":passed,"different_pixels":different})
	if not passed or c.get("save",false):
		a.save_png("res://simulation/evidence/hud_"+c.label+"_legacy.png");b.save_png("res://simulation/evidence/hud_"+c.label+"_current.png")
	left.free();right.free();mission.free()
	for n in garbage:n.free()
	print("HUD PIXEL ",c.label," difference=",different)
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Native rendering required");get_tree().quit(2);return
	for path in ["res://demo/tests/freight_lock_review.gd","res://demo/tests/relay_works_review.gd","res://simulation/tests/hud_freight_lock_review_oracle.gd","res://simulation/tests/hud_relay_works_review_oracle.gd","res://simulation/tests/hud_pixels.gd","res://demo/mission.gd","res://simulation/ui/mission_hud.gd","res://demo/views/hud_view.gd","res://demo/views/hud_appearance.gd","res://simulation/tests/hud_legacy_oracle.gd"]:sources[path]=FileAccess.get_sha256(path)
	for c in fixture_cases(): await compare(c)
	var unchanged:=true
	for path in sources:unchanged=unchanged and sources[path]==FileAccess.get_sha256(path)
	if not unchanged:failures.append("sources changed")
	FileAccess.open("res://simulation/evidence/hud_native_pixels.json",FileAccess.WRITE).store_string(JSON.stringify({"records":records,"failures":failures,"sources_unchanged":unchanged,"source_sha256":sources,"display_server":DisplayServer.get_name(),"scope":"Native 640x360 frozen HUD pairs; archived original renderer versus actual candidate host snapshot and independent view. No gameplay simulation claim."},"\t"))
	print("HUD PIXELS COMPLETE ",records.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func fixture_cases() -> Array[Dictionary]:
	var cases:Array[Dictionary]=[]
	for available in [false,true]:cases.append({"label":"title_"+str(available),"state":"title","continue":available,"no_player":true,"save":true})
	for t in [0.0,0.4,0.55,0.72,1.0,1.15,1.45,2.1,3.69]:cases.append({"label":"intro_"+str(t).replace(".","p"),"state":"intro","time":t,"save":t==1.15})
	var sectors: Array=legacy_areas()
	for i in sectors.size():
		for blind in [false,true]:cases.append({"label":"sector_%d_blind_%s"%[i,str(blind)],"sector":i,"blind":blind,"chapter":true,"save":i==0})
		var d:Dictionary=sectors[i]
		for field in ["station","relay","cache"]:
			if d.has(field):cases.append({"label":"sector_%d_prompt_%s"%[i,field],"sector":i,"point":d[field]})
		if d.has("relays"):
			cases.append({"label":"sector_%d_plural_partial"%i,"sector":i,"point":d.relays[0],"partial":true})
		if d.has("freight"):
			for latched in [false,true]:cases.append({"label":"freight_"+str(latched),"sector":i,"point":d.freight.cradle,"latched":latched,"save":true})
		for opened in [false,true]:cases.append({"label":"sector_%d_gate_%s"%[i,str(opened)],"sector":i,"point":Vector2(float(d.width)-45,float(d.get("gate_y",300))),"open":opened,"relay_on":true})
	for state in ["playing","archive","choice","paused","dead","complete"]:
		for blind in [false,true]:cases.append({"label":"modal_%s_%s"%[state,str(blind)],"state":state,"blind":blind,"caches":true,"notice":true,"save":true})
	for variant in ["hidden","null_style","no_player"]:
		var c:Dictionary={"label":variant};c[variant]=true;cases.append(c)
	for name in ["freight_lock_review","relay_works_review"]:
		cases.append({"label":name+"_complete","state":"complete","review":name,"save":true})
	return cases
