extends Resource
## Authored encounter differences only. The shared controller owns outcomes.
@export var health_capacity := 3.0
@export var movement_speed := 82.0
@export var windup_seconds := 0.56
@export var recovery_seconds := 0.72
## Zero adds no extra cap; positive values are an exclusive horizontal limit.
@export var sight_range_exclusive := 0.0
@export var hearing_memory_seconds := 1.8
@export var tint := Color("e3b688")
@export var ear_marker := false
