extends RefCounted
## Eight differentiated authored spaces; no repeated-wave or elapsed-time gates.
## Duration is measured separately; no novice-time inference.
static func sectors() -> Array[Dictionary]:
	return [
		preload("res://demo/areas/rainline_neighbourhood.gd").sector(),
		preload("res://demo/areas/quarantine_intake.gd").sector(),
		preload("res://demo/areas/exchange_circulation.gd").sector(),
		preload("res://demo/areas/freight_journey.gd").sector(),
		preload("res://demo/areas/cistern_journey.gd").sector(),
		preload("res://demo/areas/upper_residential_crossing.gd").sector(),
		preload("res://demo/areas/relay_works.gd").sector(),
		preload("res://demo/areas/warden_loops.gd").sector(),
		{"id":"above_the_rain","title":"09 / ABOVE THE RAIN", "subtitle":"Evacuation lift secured", "width":700,"theme":"interior",
		"text":"The city falls quiet beneath the lift.\nThe first door is open. The rest of the tower can wait.","hint":"E at the lift completes this demo.","platforms":[],"enemies":[],"props":[],"ending":true}
	]
