extends RefCounted
## Pure campaign envelope validation around the preserved stable-ID progress codec.
## Filesystem reads/writes and live-state application belong to the campaign host.
const Checkpoint=preload("res://demo/components/checkpoint_codec.gd")
const BuildRules=preload("res://campaign/logic/build_rules.gd")
const VERSION := 1

static func decode(raw:Variant,sectors:Array)->Dictionary:
	if not raw is Dictionary or not Checkpoint.whole(raw.get("campaign_version")) or int(raw.campaign_version)!=VERSION:return {"ok":false}
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
	decoded["campaign"]=raw
	return decoded
