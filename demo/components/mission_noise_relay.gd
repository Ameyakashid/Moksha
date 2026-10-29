extends "res://combat_pc/components/noise_relay.gd"
## Translate only semantic names, after the preserved PC has committed a
## genuine origin/identity. Base relay retains all lifecycle validation.
func _on_noise(event: Dictionary, binding: int) -> void:
	var normalized := event.duplicate()
	var aliases := {&"hurt":&"player_damage",&"strike":&"attack",&"land":&"landing",&"hard_land":&"landing",&"dive_impact":&"landing"}
	normalized["kind"] = aliases.get(event.get("kind"),event.get("kind"))
	super._on_noise(normalized,binding)
