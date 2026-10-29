extends "res://combat_pc/fixtures/guard_projectile.gd"
## Demo policy around the preserved continuously swept guard carrier.
## A shot belongs to its encounter until impact, expiry, reset or source exit.
@export var reflected_damage := 2.0
var shooter_ref: WeakRef
var encounter_epoch := 0
var blind_mode := false

func _ready() -> void:
	super._ready()
	add_to_group("demo_projectiles")
	# Enemy bodies do not intercept friendly shots; terrain and the PC do.
	collision_mask = 3

func configure_encounter(source: Node, launch_velocity: Vector2, identifier: int, epoch: int) -> void:
	shooter_ref = weakref(source)
	encounter_epoch = epoch
	configure(source, launch_velocity, identifier)

func _physics_process(dt: float) -> void:
	var shooter: Variant = shooter_ref.get_ref() if shooter_ref != null else null
	if not is_instance_valid(shooter) or not shooter.is_inside_tree() or shooter.is_queued_for_deletion() \
		or shooter.dead or shooter.projectile_epoch != encounter_epoch:
		retire(&"encounter_retired")
		return
	super._physics_process(dt)

func reflect_from_shield(payload: Dictionary) -> Dictionary:
	var result := super.reflect_from_shield(payload)
	if bool(result.get("accepted", false)):
		# The preserved carrier removes the original shooter's exception and
		# installs the defender's. Reflected shots now sweep enemy bodies32.
		collision_mask = 33
		attack_damage = maxf(attack_damage, reflected_damage)
	return result

func _draw() -> void:
	if not blind_mode: super._draw()
