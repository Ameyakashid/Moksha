class_name MokshaGroundPresentationProfile
extends Resource
## Optional MOKSHA-authored ground transients. The motor still owns facing,
## collision and action priority. A null resource retains the previous view.
@export_range(0.01, 0.5, 0.005) var start_seconds := 0.075
@export_range(0.01, 0.5, 0.005) var brake_seconds := 0.10
@export_range(0.01, 0.5, 0.005) var turn_seconds := 0.085
@export var retire_conflicting_intent := true

func duration(action: String, fallback: float) -> float:
	var value := start_seconds if action=="start" else (brake_seconds if action=="brake" else turn_seconds)
	return value if is_finite(value) and value>=0.01 else fallback
