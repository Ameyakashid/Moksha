extends RefCounted
## Original prose. Fixed semantic events, never executable content or effects.
static func entries()->Array[Dictionary]:
	return [
		{"id":"rain_roof","event":"rain_roof","priority":1,"text":"Intellect: Above the traffic. For once, a sound decision."},
		{"id":"rain_street","event":"rain_street","priority":1,"text":"Intellect: Street level. Keep a way out, old man."},
		{"id":"rain_relay","event":"rain_relay","priority":3,"text":"Intellect: The badge still works. Try not to look surprised."},
		{"id":"clinic_cell","event":"clinic_cell","priority":2,"text":"Intellect: Charged. Back to the clinic generator."},
		{"id":"clinic_power","event":"clinic_power","priority":4,"text":"Intellect: Lights first. The street shortcut is open now."},
		{"id":"clinic_rescue","event":"clinic_rescue","priority":5,"text":"Intellect: An evacuation, not a body count. Keep that habit."},
		{"id":"tram_map","event":"tram_map","priority":2,"text":"Intellect: A circuit map. Better than guessing with your boots."},
		{"id":"tram_power","event":"tram_power","priority":3,"text":"Intellect: Current routed. The welded brake still needs a strike."},
		{"id":"records","event":"records","priority":3,"text":"Intellect: Your squad record. Paper remembers differently."},
		{"id":"evac","event":"evac","priority":3,"text":"Intellect: One shelter open. There is still another."},
		{"id":"captain","event":"captain","priority":4,"text":"Lancer: Badge or not, you stop here. / Operative: Open the crossing."},
		{"id":"captain_down","event":"captain_down","priority":5,"text":"Intellect: The seal is no longer his. Find the onward passage."},
		{"id":"sight_kept","event":"sight_kept","priority":6,"text":"Intellect: Keeping your eyes. No shame in using what you have."},
		{"id":"sight_traded","event":"sight_traded","priority":6,"text":"Intellect: Take a breath. Sound tap reveals the way; listen before moving."}
	]
