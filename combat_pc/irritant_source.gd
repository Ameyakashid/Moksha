class_name MokshaIrritantSource
extends Node2D
## Narrow opt-in exposure lifetime. Actor owns susceptibility and response.
signal retired
var exposure_epoch := 0
var exposure_live := false
func activate_exposure() -> void:
	exposure_epoch += 1
	exposure_live = true
func retire_exposure() -> void:
	exposure_epoch += 1
	exposure_live = false
	retired.emit()
func current() -> bool: return false
func exposure_current(_actor: Node2D) -> bool: return false
func field_rect() -> Rect2: return Rect2()
