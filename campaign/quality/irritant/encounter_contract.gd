extends SceneTree
var host:Node
var checks:=0
var failures:Array[String]=[]
const Data=preload("res://campaign/logic/campaign_data.gd")
const Catalog=preload("res://campaign/content/campaign_catalog.gd")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	run.call_deferred()
func run()->void:
	var catalog:Dictionary=Data.load_catalog()
	check(catalog.ok and catalog.sectors.size()==32,"catalog remains five levels and32districts")
	var placed:Array=catalog.sectors.filter(func(d):return not d.get("irritants",[]).is_empty())
	check(placed.size()==3,"exact three authored encounter rooms")
	var levels:Array=[]
	for i in range(1,6):levels.append(load("res://campaign/layouts/level_%02d.gd"%i).sectors())
	for bad in [[{"at":Vector2(NAN,268)}],[{"at":Vector2(0,268)}],[{"at":Vector2(1150,268),"immune":true}],[{"at":"1150"}],42]:
		var copy:Array=levels.duplicate(true);copy[0][0]["irritants"]=bad
		check(not Catalog.validate(copy).ok,"malformed irritant rejected")
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true);host.set_physics_process(false)
	for d in placed:
		var index:int=catalog.sectors.find(d)
		host.blind=true;host.hearing_retained=true;host.load_sector(index)
		check(host.irritant_dispersers.size()==1,"one bound field "+d.id)
		var source=host.irritant_dispersers[0]
		check(source.host==host and source.target==host.player and source.get_parent()==host.room,"exact currentroom/player binding")
		check(not source._view.visible,"born blind has no hardware/cloud frame")
		host.player.reset_actor(source.position+Vector2(0,32),1)
		source.armed=true;source.phase=&"active";source.activate_exposure()
		var admitted:Dictionary=host.player.admit_irritant(source)
		check(admitted.outcome=="cough" and not host.cough_feedback.snapshot().is_empty(),"actual cough gives blind proprioceptive cue")
		host.blind=false;host.hearing_retained=false;host._apply_senses()
		check(not host.cough_feedback.snapshot().is_empty(),"same actual cough visible deaf")
		host.state="journal"
		check(host.cough_feedback.snapshot().is_empty(),"modal immediately retires cue")
		host.state="playing";host.player.reset_actor(source.position+Vector2(0,32),1)
		check(host.cough_feedback.snapshot().is_empty(),"actor reset clears cue without cache")
		var old=weakref(source)
		host.load_sector(maxi(0,index-1));await process_frame
		check(host.irritant_dispersers.is_empty(),"neighbor has no exposure/source")
		check(not is_instance_valid(old.get_ref()),"room retirement destroys old source")
		check(host.cough_feedback.snapshot().is_empty(),"room retirement has no stale body cue")
	print(JSON.stringify({"checks":checks,"failures":failures,"hz":Engine.physics_ticks_per_second,"scope":"Seeded save-disabled catalog/owner/cue contract; not traversal"}))
	host.queue_free();paused=false;await process_frame;await process_frame;quit(1 if failures.size() else 0)
