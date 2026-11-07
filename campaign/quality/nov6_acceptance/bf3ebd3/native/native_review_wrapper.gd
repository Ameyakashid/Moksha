extends SceneTree
const FIXTURE_PATH = "/workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/external-fixtures/campaign/quality/nov6_native_review.gd"
const FIXTURE_SHA = "77b25b36e6f71bfca306828f3b3f6307d0ca4f926bc17ddd26d37ded0ea9264a"
const PROVENANCE_SHA = "f2c309ea3e1957214788a979f1a45cfcb77b3332578039b5835d237242be859d"
const SOURCE_COMMIT = "c489885befb2264bf2dc0afd2cac8e147d1c9730"
func _initialize()->void:call_deferred("start")
func start()->void:
    var failures:Array[String]=[]
    if FileAccess.get_sha256(FIXTURE_PATH)!=FIXTURE_SHA:failures.append("external native fixture hash mismatch")
    if FileAccess.get_sha256("res://BUILD_PROVENANCE.json")!=PROVENANCE_SHA:failures.append("packed provenance mismatch")
    if FileAccess.file_exists("res://campaign/quality/nov6_native_review.gd"):failures.append("native fixture must not be a loose or packed runtime resource")
    for arg in OS.get_cmdline_user_args():
        if arg in ["--capture-ui","--capture-all"] and DisplayServer.get_name()=="headless":failures.append("native capture requires a real renderer")
    if not failures.is_empty():
        for failure in failures:push_error(failure)
        quit(1);return
    var fixture_script=load(FIXTURE_PATH)
    if fixture_script==null:
        push_error("Could not load frozen external native fixture");quit(1);return
    var fixture=fixture_script.new()
    if not fixture is Node:
        push_error("Frozen native fixture is not a Node");quit(1);return
    root.add_child(fixture)
    print("PACKED_NATIVE_WRAPPER_READY "+JSON.stringify({"passed":true,"checks":4,"failures":[],"source_commit":SOURCE_COMMIT,"fixture_sha256":FIXTURE_SHA,"display_server":DisplayServer.get_name(),"scope":"Frozen external native fixture, production resources from verified PCK; controlled visual fixtures, not a route or Windows test."}))
