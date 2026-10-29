class_name EmberPropTuning
extends Resource
## Physical body and charged-impact values, independent of level/run state.

@export_category("Body")
@export var body_mass: float = 1.1
@export var body_gravity_scale: float = 1.0
@export var body_linear_damp: float = 0.35
@export var body_angular_damp: float = 0.6
@export var bounce: float = 0.40
@export var friction: float = 0.7
@export_category("Launch")
@export var launch_speed: float = 465.0
@export var launch_lift: float = -185.0
@export var launch_spin_range: Vector2 = Vector2(9, 17)
@export var charge_seconds: float = 2.5
@export_category("Impact")
@export var damage: int = 3
@export var contact_damage_speed: float = 80.0
@export var proximity_damage_speed: float = 100.0
@export var proximity_radius: float = 27.0
@export var enemy_center_offset: Vector2 = Vector2(0, -22)
@export var chain_speed: float = 130.0
@export var chain_charge_seconds: float = 1.5
@export var splash_radius: float = 0.0
@export var splash_damage: int = 0

@export_category("Material impacts")
@export var impact_noise_speed: float = 85.0
@export var hard_impact_speed: float = 255.0
@export var hard_impacts_to_break: int = 4
@export var impact_cooldown: float = 0.18
