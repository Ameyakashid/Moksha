extends SceneTree
## Second process only; consumes test-owned fresh.json produced by host_contract.
var base:=""
func _initialize()->void:run.call_deferred()
func run()->void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--root="):base=a.trim_prefix("--root=")
	if not base.is_absolute_path() or base.begins_with(ProjectSettings.globalize_path("res://")) or not FileAccess.file_exists(base.path_join("FRESH_EXPECTED.json")):quit(2);return
	var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base.path_join("FRESH_EXPECTED.json")))
	if FileAccess.get_sha256(base.path_join("fresh.json"))!=expected.checkpoint_sha256:quit(2);return
	# JSON numbers are floats; checkpoint decoder intentionally restores metric sector to int.
	# Normalize only that documented integer field; every other receipt value remains exact.
	for metric in expected.metrics:
		if not metric.sector is float or metric.sector!=floor(metric.sector):quit(2);return
		metric.sector=int(metric.sector)
	var host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false
	host.campaign_save_path=base.path_join("fresh.json");host.history_path=base.path_join("trade-history");host.legacy_results_path=base.path_join("fresh-old.json")
	root.add_child(host);host.save_enabled=true;host.continue_run();host.set_physics_process(false)
	var facts:Dictionary={"run_id":host.run_id==expected.run_id,"sector":host.sector==int(expected.sector),"metrics":host.metrics==expected.metrics,"upgrades":host.upgrades==expected.upgrades,"smell":not host.smell_retained,"scent":not host.scent.enabled,"immune":not host.player.irritant_snapshot().susceptible,"hearing":host.hearing_retained,"sight":not host.blind}
	var ok:bool=facts.values().all(func(value):return value)
	print(JSON.stringify({"passed":ok,"facts":facts,"actual_metrics":host.metrics,"expected_metrics":expected.metrics,"scope":"Fresh process Continue from isolated seeded trade, exact identity/receipts and capability checks; not earned play"}))
	host.queue_free();paused=false;await process_frame;await process_frame;quit(0 if ok else 1)
