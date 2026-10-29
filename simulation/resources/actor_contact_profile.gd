extends Resource
## Role-neutral actor/faction membership and physics query configuration.
@export_flags_2d_physics var body_layer := 32
@export_flags_2d_physics var body_mask := 1
@export_flags_2d_physics var terrain_mask := 1
@export_flags_2d_physics var hurtbox_layer := 64
@export_flags_2d_physics var strike_target_mask := 76
@export_flags_2d_physics var obstruction_mask := 1
@export var material_profile: Resource
@export var groups := PackedStringArray(["simulation_actors"])
@export var remove_groups := PackedStringArray(["combat_pc"])
