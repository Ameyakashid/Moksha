extends Resource
## Visual acoustic abstraction, not a physical acoustic solver.
## Distances are world pixels and times are simulation seconds.

@export_category("Propagation")
@export_range(50.0, 2400.0, 10.0) var propagation_speed: float = 550.0
@export_range(100.0, 3000.0, 10.0) var contour_speed: float = 650.0
@export_range(40.0, 1400.0, 10.0) var base_range: float = 370.0
@export_range(0.02, 0.6, 0.01) var bright_head_seconds: float = 0.095
@export_range(0.05, 2.0, 0.01) var trail_seconds: float = 0.53
@export_range(0.05, 2.0, 0.01) var origin_seconds: float = 0.32
@export_range(0.1, 2.0, 0.05) var quiet_preview_opacity: float = 0.24

@export_category("Geometry and performance")
@export_range(2.0, 24.0, 1.0) var sample_spacing: float = 6.0
@export_range(0.05, 3.0, 0.05) var geometry_refresh_seconds: float = 0.35
@export_range(1, 64, 1) var max_active_pulses: int = 18
@export_range(64, 24000, 64) var max_geometry_segments: int = 9000
@export_range(32, 12000, 32) var max_draw_segments: int = 3600
@export_range(8, 1024, 8) var history_limit: int = 160
@export_range(0.5, 4.0, 0.1) var line_width: float = 1.15
@export var draw_proprioception: bool = true
@export var draw_origin_labels: bool = true
@export_category("Noise warnings")
@export var draw_threat_direction: bool = true
@export_range(0.05, 0.8, 0.01) var threat_warning_seconds: float = 0.34
@export_range(0.05, 0.5, 0.01) var threat_strike_seconds: float = 0.18
@export_range(8.0, 40.0, 1.0) var threat_marker_length: float = 23.0
@export_category("Contact feedback")
@export var draw_contact_feedback: bool = true
@export_range(0.1, 0.8, 0.01) var hit_feedback_seconds: float = 0.38
@export_range(0.1, 1.0, 0.01) var defeat_feedback_seconds: float = 0.58
@export_range(4.0, 60.0, 1.0) var origin_label_separation: float = 26.0

## Event profiles are semantic, never guessed from the player's position.
## Actors may add new kinds without changing the renderer; unknown kinds work.
func profile(kind: StringName, loudness: float) -> Dictionary:
	var strength := clampf(loudness, 0.05, 4.0)
	var radius_factor := 1.0
	var life_factor := 1.0
	match String(kind):
		"player_step", "footstep", "step":
			radius_factor = 0.62; life_factor = 0.68
		"enemy_step", "enemy_footstep":
			radius_factor = 0.76; life_factor = 0.82
		"weapon_tap", "tap":
			radius_factor = 1.1
		"prop_impact", "impact", "landing":
			radius_factor = 1.16
		"prop_break", "break", "explosion":
			radius_factor = 1.4; life_factor = 1.2
		"enemy_attack", "attack", "parry":
			radius_factor = 0.94
	return {
		"range": base_range * radius_factor * sqrt(strength),
		"strength": minf(1.0, 0.5 + strength * 0.5),
		"trail": trail_seconds * life_factor,
	}
