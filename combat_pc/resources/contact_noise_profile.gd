class_name MokshaContactNoiseProfile
extends Resource
## Authored impact policy, in pixels/second and seconds. This is deliberately
## not a sliding, scraping, rolling, audio playback, or material simulation.
@export var kind: StringName = &"prop_impact"
@export_range(0.01, 2000.0, 0.1) var minimum_closing_speed := 85.0
@export_range(0.01, 2000.0, 0.1) var loudness_speed_scale := 240.0
@export_range(0.01, 10.0, 0.01) var minimum_loudness := 0.45
@export_range(0.01, 10.0, 0.01) var maximum_loudness := 1.9
## Sustained low closing speed rearms a contact without inventing an impact.
@export_range(0.0, 500.0, 0.1) var quiet_closing_speed := 20.0
@export_range(0.001, 2.0, 0.001) var quiet_rearm_seconds := 0.05
## Missing reports must persist this long before the same shape pair rearms.
@export_range(0.001, 2.0, 0.001) var separation_rearm_seconds := 0.025
@export_range(1, 128, 1) var max_contacts_reported := 16
@export_range(0, 256, 1) var recent_receipt_limit := 32
