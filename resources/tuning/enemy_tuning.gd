class_name EmberEnemyTuning
extends Resource
## AI and impact response; the collider and graphics remain scene-editable.

@export_category("Health and movement")
@export var max_health: int = 3
@export var gravity: float = 1100.0
@export var move_speed: float = 42.0
@export var patrol_speed: float = 18.0
@export var patrol_frequency: float = 0.7
@export var detection_range: Vector2 = Vector2(235, 72)
@export var stopping_distance: float = 28.0
@export_category("Attack")
@export var initial_cooldown: float = 0.6
@export var attack_distance: float = 35.0
@export var attack_seconds: float = 0.48
@export var attack_cooldown: float = 1.1
@export var hit_remaining: float = 0.14
@export var hit_range: Vector2 = Vector2(49, 37)
@export var attack_lunge_speed: float = 235.0
@export var attack_damage: int = 1
@export_category("Damage response")
@export var stun_friction: float = 400.0
@export var sword_stun: float = 0.23
@export var prop_stun: float = 0.42
@export var sword_knockback: float = 130.0
@export var prop_knockback: float = 280.0
@export var sword_lift: float = -60.0
@export var prop_lift: float = -125.0
@export var hurt_flash_seconds: float = 0.14

@export_category("Grounded behavior")
@export var footstep_spacing: float = 28.0
@export var avoid_ledges: bool = true
@export var ledge_probe_forward: float = 15.0
@export var ledge_probe_depth: float = 24.0
