class_name EmberStrikeTuning
extends Resource
## Melee queries are kept in the player's reusable StrikeComponent.

@export var center_offset: Vector2 = Vector2(31, -22)
@export var hitbox_size: Vector2 = Vector2(60, 42)
@export_flags_2d_physics var target_mask: int = 4 | 8
@export_flags_2d_physics var terrain_mask: int = 1
@export var damage: int = 1
@export var finisher_damage: int = 2
@export var finisher_launch_multiplier: float = 1.15
