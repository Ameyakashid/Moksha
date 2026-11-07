extends SceneTree
var failures:Array[String]=[]
var scripts_checked:=0
var resources_checked:=0
func check(ok:bool,label:String)->void:
    if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
    check(FileAccess.get_sha256("res://BUILD_PROVENANCE.json")=="f2c309ea3e1957214788a979f1a45cfcb77b3332578039b5835d237242be859d","embedded provenance bytes")
    var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://BUILD_PROVENANCE.json"))
    if not provenance is Dictionary:
        push_error("PACK_AUDIT missing provenance");quit(1);return
    check(provenance.source_commit=="c489885befb2264bf2dc0afd2cac8e147d1c9730","frozen commit")
    for path in provenance.production_sha256:
        var uri="res://"+str(path)
        if str(path).ends_with(".gd"):
            check(FileAccess.get_sha256(uri)==provenance.production_sha256[path],"script hash "+str(path))
            scripts_checked+=1
        if str(path).ends_with(".tscn") or str(path).ends_with(".tres") or str(path).ends_with(".gdshader"):
            check(ResourceLoader.exists(uri) and ResourceLoader.load(uri)!=null,"resource loads "+str(path))
            resources_checked+=1
    for path in ["res://campaign/tests/campaign_smoke.gd", "res://campaign/quality/nov6_gamepad_navigation.gd", "res://campaign/quality/nov6_independent_controller.gd", "res://campaign/quality/nov6_controller_devices.gd"]:
        check(not FileAccess.file_exists(path),"developer fixture excluded "+path)
    var packed=load("res://campaign/campaign.tscn")
    if packed==null:
        push_error("PACK_AUDIT missing main scene");quit(1);return
    var host=packed.instantiate()
    host.save_enabled=false
    root.add_child(host)
    host.start_new(true)
    host.input_override={}
    var levels:Dictionary={}
    var districts:int=host.sectors.size()
    check(districts==32,"all 32 authored districts")
    for i in districts:
        host.load_sector(i)
        await physics_frame
        await process_frame
        levels[int(host.sectors[i].level)]=true
        check(is_instance_valid(host.player),"district player "+str(i))
        check(is_instance_valid(host.art),"district scenery "+str(i))
        check(is_instance_valid(host.actor_paint),"district actor paint "+str(i))
        check(is_instance_valid(host.object_paint),"district object paint "+str(i))
        check(host.player.get_node("BodyShape/IncomingStrikeReceiver")._health()==host.health,"district Health binding "+str(i))
    check(levels.size()==5,"five level data sets")
    host.state="choice"
    host.choose_sight(true)
    check(host.blind and host.sonar.blind,"real sight trade")
    check(not host.art.visible and not host.actor_paint.operative.visible,"sight trade hides presentation")
    host.load_sector(0)
    await process_frame
    check(not host.art.visible and not host.actor_paint.operative.visible,"sight trade survives district reload")
    host.start_new(true)
    await process_frame
    check(not host.blind and host.art.visible and host.actor_paint.operative.visible,"new run restores sight")
    host.queue_free()
    await process_frame
    var result={"source_commit":provenance.source_commit,"districts":districts,"levels":levels.size(),"script_hashes_checked":scripts_checked,"resources_loaded":resources_checked,"failures":failures}
    print("PACK_AUDIT_RESULT "+JSON.stringify(result))
    if failures.is_empty():print("PACK_AUDIT_PASS")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
