extends "res://demo/mission.gd"
## Labelled capability fixture: no enemies; initial actor/cargo placement only.
func _ready() -> void:
	var receiver_y:=180.0
	for arg in OS.get_cmdline_user_args():
		if arg=="--grade=down": receiver_y=210.0
	sectors=[{"title":"FREIGHT TRANSPORT CAPABILITY","subtitle":"Flat deck / actual repeated strikes","width":1450,"top":-100,"theme":"interior","spawn":Vector2(160,180),"text":"Capability fixture, not authored campaign content.","hint":"J strike cargo; E replace at original cradle.","platforms":[Rect2(100,180,900,18)],"ladders":[[140,300,120]],"enemies":[],"props":[],"freight":{"cradle":Vector2(220,180),"receiver":Vector2(1080,receiver_y),"shutter":[Vector2(1240,50),Vector2(26,500)]}}, {"title":"TRIAL EXIT","subtitle":"","width":700,"theme":"interior","text":"","hint":"","platforms":[],"enemies":[],"props":[],"ending":true}]
	super._ready()
	save_enabled=false
	start_new(true)
