extends "res://campaign/logic/campaign.gd"
## F6-friendly district entry. Select a stable district ID in the Inspector.
## Authored data composes placeable simulation scenes; no duplicate controller.
@export var district_id:="city_clinic"
@export var preview_lens:="neutral"
func _ready()->void:
	super._ready()
	save_enabled=false
	lens=preview_lens
	var chosen:=0
	for i in sectors.size():
		if sectors[i].id==district_id:chosen=i;break
	start_new(true)
	load_sector(chosen)
