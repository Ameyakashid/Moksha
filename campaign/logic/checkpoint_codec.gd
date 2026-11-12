extends RefCounted
## Pure campaign envelope validation around the preserved stable-ID progress codec.
## Filesystem reads/writes and live-state application belong to the campaign host.
const Checkpoint=preload("res://demo/components/checkpoint_codec.gd")
const BuildRules=preload("res://campaign/logic/build_rules.gd")
const VERSION := 2

static func valid_run_id(value:Variant)->bool:
	if not value is String or value.length()!=32:return false
	for character in value:
		if character not in "0123456789abcdef":return false
	return true

static func decode(raw:Variant,sectors:Array)->Dictionary:
	if not raw is Dictionary or not Checkpoint.whole(raw.get("campaign_version")) or int(raw.campaign_version) not in [1,VERSION]:return {"ok":false}
	if int(raw.campaign_version)==VERSION:
		if not valid_run_id(raw.get("run_id")) or raw.get("run_status") not in ["active","completed"] or raw.get("run_origin") not in ["new","legacy_resume"]:return {"ok":false,"error":"Invalid run identity or lifecycle."}
	var decoded:Dictionary=Checkpoint.decode(raw.get("progress"),sectors)
	if not decoded.ok:return decoded
	if raw.get("lens") not in BuildRules.LENSES or not raw.get("upgrades") is Array or not raw.get("rewards") is Dictionary:return {"ok":false}
	for upgrade in raw.upgrades:
		if upgrade not in BuildRules.AUGMENTS:return {"ok":false}
	if raw.upgrades.size()>4:return {"ok":false}
	for reward in raw.rewards.values():
		if reward not in BuildRules.AUGMENTS:return {"ok":false}
	if not raw.get("level_seconds",{}) is Dictionary or not raw.get("level_receipts",[]) is Array:return {"ok":false}
	for value in raw.get("level_seconds",{}).values():
		if not Checkpoint.number(value):return {"ok":false}
	for receipt in raw.get("level_receipts",[]):
		if not receipt is Dictionary or not Checkpoint.whole(receipt.get("level")) or int(receipt.level)<1 or int(receipt.level)>5 or not Checkpoint.number(receipt.get("active_seconds")):return {"ok":false}
	decoded["campaign"]=raw.duplicate(true)
	return decoded
