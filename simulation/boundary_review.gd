extends "res://demo/mission.gd"
## Explicit reusable review fixture. Authored mission layout is unchanged.
func _ready() -> void:
	save_enabled=false
	var arena: Dictionary=sectors[0].duplicate(true)
	arena.title="WORLD BOUNDARY / LOCKED-GAP REVIEW FIXTURE"
	arena.subtitle="Same origin witness for PC / four NPC families / cargo"
	arena.width=1100;arena.platforms=[];arena.gaps=[Vector2(430,700)];arena.lock=true
	arena.spawn=Vector2(350,300)
	arena.enemies=[[470,"sentinel",200],[525,"listener",200],[580,"sentry",200],[640,"warden",200]]
	arena.props=[[390,300],[680,200]];arena.erase("relay");arena.erase("cache")
	arena.text="Reusable fixture only. Gravity carries every eligible origin across y=420."
	sectors.assign([arena]); super._ready(); start_new(true)
	camera.offset=Vector2(0,85)
	chapter_left=0;notice="BOUNDARY REVIEW · A/D move · Space jump · J launch · Enter retry after fall";notice_left=15
	for enemy in enemies: enemy.ai_enabled=false
	room.get_node("BoundaryHazard").debug_draw=true
	var overlay := CanvasLayer.new(); overlay.layer=42; add_child(overlay)
	var legend := Label.new(); legend.position=Vector2(12,76);legend.text="RED LINE: y = 420 / the body's origin is the witness\nOne shared Health / Defeat rule; cargo has explicit retirement"
	legend.add_theme_font_size_override("font_size",11);legend.add_theme_color_override("font_color",Color("efb19b"));legend.add_theme_color_override("font_shadow_color",Color.BLACK);legend.add_theme_constant_override("shadow_offset_x",1);legend.add_theme_constant_override("shadow_offset_y",1);overlay.add_child(legend)
func load_sector(index: int) -> void:
	super.load_sector(index)
	room.get_node("BoundaryHazard").debug_draw=true
	for enemy in enemies: enemy.ai_enabled=false
