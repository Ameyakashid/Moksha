class_name MokshaMovementProfile
extends Resource
## ORIGINAL MOKSHA starting values. No parameter here is recovered v35 tuning.
## The historical 2019 2–3-frame grace example informs the 0.05 s grace only.
@export_category("Body / Godot collision adapter")
@export var body_width := 16.0
@export var standing_height := 34.0
@export var crouching_height := 20.0
@export var collision_margin := 0.02
@export var floor_probe := 2.0
@export var maximum_floor_angle_degrees := 47.0
@export_category("Ground response / original MOKSHA")
@export var ordinary_ground_response: MokshaGroundResponseProfile
@export var run_speed := 218.0
@export var ground_acceleration := 3100.0
@export var ground_braking := 1850.0
@export var reversal_acceleration := 3600.0
@export var crouch_speed := 92.0
@export var turn_pose_seconds := 0.11
@export var landing_pose_seconds := 0.09
@export_category("Air response / original MOKSHA")
@export var ordinary_air_response: MokshaAirResponseProfile
@export var air_acceleration := 1450.0
@export var air_idle_drag := 120.0
@export var jump_speed := 365.0
@export var air_jump_speed := 350.0
@export var air_jump_count := 1
@export var gravity := 1100.0
@export var falling_gravity_multiplier := 1.25
@export var released_jump_gravity_multiplier := 1.6
@export var jump_release_rise_cap := 165.0
@export var terminal_fall_speed := 780.0
@export var coyote_seconds := 0.05
@export var jump_buffer_seconds := 0.10
@export var apex_pose_speed := 65.0
@export_category("Ledge assistance / original MOKSHA")
@export var ledge_reach := 8.0
@export var ledge_probe_above_head := 8.0
@export var ledge_min_top_above_feet := 4.0
@export var ledge_surface_inset := 1.0
@export var ledge_max_rising_speed := 260.0
@export var ledge_max_falling_speed := 560.0
@export var ledge_outside_gap := 1.2
@export var ledge_hang_drop := 29.0
@export var ledge_top_clearance := 1.0
@export var ledge_step_inset := 4.0
@export var ledge_catch_seconds := 0.065
@export var ledge_pull_seconds := 0.17
@export var ledge_step_seconds := 0.14
@export var ledge_regrab_delay := 0.20
@export var blocked_pull_retry_seconds := 0.16
@export var ledge_release_horizontal_speed := 48.0
@export var ledge_release_fall_speed := 35.0
@export var ledge_max_transport_speed := 420.0
@export var automatic_arrival_pull := false
@export var collision_path_step := 2.0
@export_category("Original movement noise")
@export var footstep_distance := 44.0
@export var footstep_loudness := 0.65
@export var landing_loudness := 1.0
@export_category("Targeted one-way drop / original MOKSHA")
@export var down_action_buffer_seconds := 0.10
@export var drop_release_seconds := 0.08
@export var drop_initial_speed := 100.0
@export var drop_preflight_distance := 4.0
@export var drop_plane_clearance := 2.5
@export var drop_max_ignore_seconds := 0.30
@export var drop_coplanar_tolerance := 0.05
@export_category("Ladder / vine traversal: original MOKSHA")
@export var climb_entry_vertical_margin := 0.15
@export var climb_up_speed := 115.0
@export var climb_down_speed := 145.0
@export var climb_acceleration := 1100.0
@export var climb_braking := 1800.0
@export var climb_align_speed := 160.0
@export var climb_align_timeout := 0.25
@export var climb_regrab_delay := 0.18
@export var climb_jump_grace_seconds := 0.06
@export var climb_max_transport_speed := 420.0
@export var climb_end_tolerance := 0.15
@export var climb_release_speed := 48.0
@export_category("Wall traversal / original MOKSHA")
@export var wall_toward_threshold := 0.5
@export var wall_probe_reach := 3.0
@export var wall_separation_distance := 6.0
@export var wall_run_speed := 180.0
@export var wall_run_acceleration := 1500.0
@export var wall_run_max_rise := 72.0
@export var wall_run_max_seconds := 0.50
@export var wall_slide_speed := 90.0
@export var wall_slide_acceleration := 900.0
@export var wall_slide_max_seconds := 1.20
@export var wall_contact_push_speed := 24.0
@export var wall_kick_horizontal_speed := 230.0
@export var wall_kick_vertical_speed := 365.0
@export var wall_kick_commit_seconds := 0.09
@export var wall_kick_grace_seconds := 0.06
@export var wall_regrab_delay := 0.16
@export var wall_max_transport_speed := 420.0
@export_enum("Separation and recontact", "Ground contact only") var wall_rearm_policy := 0

@export_category("Optional high-fall recovery / original MOKSHA")
@export var hard_land_min_distance := 220.0
@export var hard_land_min_relative_speed := 400.0
@export var hard_land_impact_seconds := 0.06
@export var hard_land_recovery_seconds := 0.12
@export var hard_land_braking := 2800.0
@export var hard_land_loudness := 1.4
