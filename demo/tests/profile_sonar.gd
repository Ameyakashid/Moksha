extends "res://demo/components/mission_sonar.gd"
var cpu_usec: Dictionary = {"render":0,"refresh":0,"emit":0}
var counts: Dictionary = {"render":0,"refresh":0,"emit":0}
func render_on(canvas:Node2D)->void:
	var start:=Time.get_ticks_usec()
	super.render_on(canvas)
	cpu_usec.render+=Time.get_ticks_usec()-start
	counts.render+=1
func refresh_geometry()->void:
	var start:=Time.get_ticks_usec()
	super.refresh_geometry()
	cpu_usec.refresh+=Time.get_ticks_usec()-start
	counts.refresh+=1
func _on_noise_emitted(origin:Vector2,kind:StringName,loudness:float,source:Node=null)->void:
	var start:=Time.get_ticks_usec()
	super._on_noise_emitted(origin,kind,loudness,source)
	cpu_usec.emit+=Time.get_ticks_usec()-start
	counts.emit+=1
