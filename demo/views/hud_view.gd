@tool
extends Node2D
const Appearance = preload("res://demo/views/hud_appearance.gd")
var data: Dictionary = {}
var appearance: Appearance:
	set(value):
		if appearance != null and appearance.changed.is_connected(_refresh): appearance.changed.disconnect(_refresh)
		appearance = value
		if appearance != null and not appearance.changed.is_connected(_refresh): appearance.changed.connect(_refresh)
		_refresh()
func set_snapshot(value: Dictionary) -> void:
	data = value.duplicate(true)
	queue_redraw()
func _refresh() -> void:
	modulate = appearance.tint if appearance != null else Color.WHITE
	queue_redraw()
func _draw() -> void:
	if appearance == null or data.is_empty(): return
	render_snapshot(self)
func _text(c: Node2D, text: String, p: Vector2, size := 10, color := Color("d8e7e6")) -> void:
	for line in text.split("\n"):
		c.draw_string(ThemeDB.fallback_font,p,line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
		p.y += size+5

func _panel(c: Node2D, title: String, body: String, footer: String) -> void:
	c.draw_rect(Rect2(0,0,640,360),Color(0.015,0.03,0.045,0.94))
	c.draw_line(Vector2(54,77),Vector2(586,77),Color("567e85"),1)
	_text(c,title,Vector2(54,62),23,Color("e8d8bb"))
	_text(c,body,Vector2(54,112),12)
	c.draw_line(Vector2(54,283),Vector2(586,283),Color("354e58"),1)
	_text(c,footer,Vector2(54,307),11,Color("b6d6d2"))

func render_snapshot(c: Node2D) -> void:
	if data.panel_override:
		_panel(c,data.panel_title,data.panel_body,data.panel_footer)
		return
	if data.state=="title":
		_panel(c,"MOKSHA / THE FIRST ASCENT","A washed-up operative. A sealed arcology.\nOne door to open. A sense you can choose to leave behind.\n\nA complete wireframe mission built on the v26 combat foundation.\n%d authored areas + %s · optional sight trade · checkpoint retries" % [int(data.get("authored_area_count",0)), "finale" if int(data.get("ending_count",0))==1 else "%d finales" % int(data.get("ending_count",0))], "ENTER  New mission"+("     C  Continue checkpoint" if data.continue_available else ""))
		_text(c,"A/D move  ·  Space jump  ·  J combo  ·  K guard/parry  ·  Shift roll",Vector2(54,337),9,Color("77939b"))
		return
	if data.state=="intro":
		_panel(c,"04:17 / CITY FRINGE","A spear cuts through the rain.\nYour hand remembers before you do.","ENTER / SPACE  Skip opening")
		preload("res://demo/components/opening_scene.gd").draw(c,data.intro_time)
		return
	if not data.player_present: return
	# Quiet fixed HUD remains accessible while the world is blacked out.
	c.draw_rect(Rect2(0,0,640,39),Color(0.015,0.025,0.04,0.93))
	_text(c,data.sector_title,Vector2(15,15),10,Color("e3d0b0"))
	_text(c,"SIGHT TRADED / +25% SPEED" if data.blind else "SIGHT INTACT",Vector2(15,29),8,Color("85b8bd"))
	c.draw_rect(Rect2(382,12,98,5),Color("273b45"))
	c.draw_rect(Rect2(382,12,98*data.health_current/data.health_capacity,5),Color("c6e1d1"))
	_text(c,"%d/%d" % [data.health_current,data.health_capacity],Vector2(489,18),9)
	_text(c,"%02d:%02d" % [int(data.elapsed)/60,int(data.elapsed)%60],Vector2(581,18),10)
	_text(c,data.objective,Vector2(382,31),8,Color("a4c6cd"))
	c.draw_rect(Rect2(0,339,640,21),Color(0.015,0.025,0.04,0.93))
	_text(c,"J combo   K guard/parry   Shift roll   Q tap   E use   R retry   Esc pause",Vector2(15,352),9,Color("9db6be"))
	if data.chapter_visible:
		c.draw_rect(Rect2(12,45,616,79),Color(0.015,0.025,0.04,0.88))
		_text(c,data.sector_text,Vector2(23,62),10)
		_text(c,data.sector_hint,Vector2(23,114),8,Color("e1c89f"))
	if data.notice_visible:
		c.draw_rect(Rect2(12,304,616,29),Color(0.015,0.025,0.04,0.94))
		_text(c,data.notice,Vector2(23,323),10,Color("ead9b5"))
	elif data.state=="playing" and not data.prompt.is_empty():
		_text(c,data.prompt,Vector2(22,325),10,Color("f0ddb9"))
	match data.state:
		"archive": _panel(c,"FIELD ARCHIVE / %d OF %d" % [data.cache_count,data.cache_total],data.archive_text+"\n\nHealth restored. This archive remains collected on retry.","E / Enter / Esc  Return to the mission")
		"choice": _panel(c,"THE EXCHANGE","Give up sight for the rest of this mission?\n\n+25% run and roll speed. Stronger, longer sound traces.\nTerrain and enemies disappear when sound fades.\nQ taps your baton. Footsteps, combat and props also reveal.\nYour health is restored. Retrying preserves the trade.","J  Trade sight     K / Esc  Keep sight")
		"paused": _panel(c,"PAUSED","A/D or arrows   Move\nSpace / C   Jump, then air jump\nJ   Fresh-tap three-strike combo     K   Raise / hold shield\nShift   Roll     S + Space   Drop / dive\nW / S   Climb ladders\nQ   Sound tap     E   Interact     M   Mute", "Esc Resume   R Restart area / reset "+("cargo" if data.has_freight else "relays")+"   N Title")
		"dead": _panel(c,"THE ASCENT CAN WAIT","You fell. This sector can be tried again.\n\nThe current checkpoint restores health and resets guards, relays, shutters and cargo.\nYour sight choice and collected archives remain.","R / Enter  Retry checkpoint     N  Title")
		"complete": _panel(c,"LIFT SECURED / DEMO COMPLETE","The city falls quiet beneath you.\nThe first door is open.\n\nActive play: %02d:%02d     Defeats: %d     Guards: %d\nArchives: %d / %d     Sight: %s\n\nThis completes The First Ascent, not the full tower story." % [int(data.elapsed)/60,int(data.elapsed)%60,data.deaths,data.kills,data.cache_count,data.cache_total,"traded" if data.blind else "kept"],"Enter / N  Return to title")
