extends RefCounted
## Detached persisted run values. No node references, mutation or file access.
## The campaign host remains the live-state compatibility owner during migration.
static func capture(state:Dictionary)->Dictionary:
	return {"lens":state.lens,"upgrades":state.upgrades.duplicate(true),
		"rewards":state.rewards.duplicate(true),"level_seconds":state.level_seconds.duplicate(true),
		"level_receipts":state.level_receipts.duplicate(true)}
