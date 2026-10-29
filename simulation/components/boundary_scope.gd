class_name MokshaBoundaryScope
extends Node2D
## Optional composition-root hook. Local transform edits revoke in-flight world
## observations synchronously, including move-and-restore in one callback.
signal boundary_scope_invalidated()
func _ready() -> void:
	set_notify_local_transform(true)
func _notification(what: int) -> void:
	if what in [NOTIFICATION_LOCAL_TRANSFORM_CHANGED, NOTIFICATION_EXIT_TREE, NOTIFICATION_ENTER_CANVAS, NOTIFICATION_EXIT_CANVAS, NOTIFICATION_WORLD_2D_CHANGED]: boundary_scope_invalidated.emit()
