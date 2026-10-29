extends Node2D
const Data = preload("res://demo/mission_data.gd")
var sectors: Array[Dictionary] = Data.sectors()
var sector := 0
var room: Node2D
var player: CharacterBody2D
var health: Node
var sonar: CanvasLayer
var audio: Node
var camera: Camera2D
var hud: Node2D
var bus: Node
var state := "title"
var blind := false
var traded_here := false
var relay_on := false
var relay_states: Array[int] = []
var enemies: Array[Node] = []
var caches: Array[int] = []
var kills := 0
var deaths := 0
var elapsed := 0.0
var sector_elapsed := 0.0
var notice := ""
var notice_left := 0.0
var chapter_left := 0.0
var tap_cooldown := 0.0
var intro_time := 0.0
var intro_caught := false
var archive_text := ""
var input_override: Variant = null
var metrics: Array[Dictionary] = []
var save_enabled := true
var continue_available := false
var _pending_sector := -1
var _pending_retry := false
var _base_speed := 218.0
var _base_roll: Array[float] = []
func _cache_total() -> int:
	var total:=0
	for area in sectors:
		if area.has("cache"): total+=1
	return total

func _relay_points() -> Array:
	var d: Dictionary = sectors[sector]
	return d.get("relays",[d.relay] if d.has("relay") else [])

func _near(point: Vector2, radius := 45.0) -> bool:
	return player.global_position.distance_to(point) < radius

func remaining_enemies() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead: count += 1
	return count

func _draw() -> void: render_hud(self)
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

func render_hud(c: Node2D) -> void:
	if state=="title":
		_panel(c,"MOKSHA / THE FIRST ASCENT","A washed-up operative. A sealed arcology.\nOne door to open. A sense you can choose to leave behind.\n\nA complete wireframe mission built on the v26 combat foundation.\n7 authored areas + finale · optional sight trade · checkpoint retries", "ENTER  New mission"+("     C  Continue checkpoint" if continue_available else ""))
		_text(c,"A/D move  ·  Space jump  ·  J combo  ·  K guard/parry  ·  Shift roll",Vector2(54,337),9,Color("77939b"))
		return
	if state=="intro":
		_panel(c,"04:17 / CITY FRINGE","A spear cuts through the rain.\nYour hand remembers before you do.","ENTER / SPACE  Skip opening")
		preload("res://demo/components/opening_scene.gd").draw(c,intro_time)
		return
	if not is_instance_valid(player): return
	# Quiet fixed HUD remains accessible while the world is blacked out.
	c.draw_rect(Rect2(0,0,640,39),Color(0.015,0.025,0.04,0.93))
	_text(c,sectors[sector].title,Vector2(15,15),10,Color("e3d0b0"))
	_text(c,"SIGHT TRADED / +25% SPEED" if blind else "SIGHT INTACT",Vector2(15,29),8,Color("85b8bd"))
	c.draw_rect(Rect2(382,12,98,5),Color("273b45"))
	c.draw_rect(Rect2(382,12,98*health.current_health/health.capacity,5),Color("c6e1d1"))
	_text(c,"%d/%d" % [health.current_health,health.capacity],Vector2(489,18),9)
	_text(c,"%02d:%02d" % [int(elapsed)/60,int(elapsed)%60],Vector2(581,18),10)
	var objective := "Reach the onward door [E]"
	if sectors[sector].has("freight") and not room.freight_receiver.is_latched: objective="Seat freight: J launch / E replace"
	elif not _relay_points().is_empty() and not relay_on: objective="Activate relays: %d / %d [E]" % [relay_states.size(),_relay_points().size()]
	elif sectors[sector].get("lock",false) and remaining_enemies()>0: objective="Security seal: %d guards remain" % remaining_enemies()
	elif sectors[sector].get("ending",false): objective="Enter the lift [E]"
	_text(c,objective,Vector2(382,31),8,Color("a4c6cd"))
	c.draw_rect(Rect2(0,339,640,21),Color(0.015,0.025,0.04,0.93))
	_text(c,"J combo   K guard/parry   Shift roll   Q tap   E use   R retry   Esc pause",Vector2(15,352),9,Color("9db6be"))
	if chapter_left>0:
		c.draw_rect(Rect2(12,45,616,79),Color(0.015,0.025,0.04,0.88))
		_text(c,sectors[sector].text,Vector2(23,62),10)
		_text(c,sectors[sector].hint,Vector2(23,114),8,Color("e1c89f"))
	if notice_left>0:
		c.draw_rect(Rect2(12,304,616,29),Color(0.015,0.025,0.04,0.94))
		_text(c,notice,Vector2(23,323),10,Color("ead9b5"))
	elif state=="playing":
		var prompt := ""
		var d: Dictionary = sectors[sector]
		if d.has("freight") and _near(d.freight.cradle,60): prompt="[E] Replace lost cargo · [J] strike from left" if not room.freight_receiver.is_latched else "FREIGHT SEATED · passage open"
		elif d.has("station") and _near(d.station) and not blind: prompt="[E] THE EXCHANGE · choose whether to trade sight"
		elif _relay_points().any(func(p): return _near(p)) and not relay_on: prompt="[E] Activate relay"
		elif d.has("cache") and _near(d.cache) and not caches.has(sector): prompt="[E] Field cache · restore health / collect archive"
		elif _near(Vector2(float(d.width)-45,float(d.get("gate_y",300))),65): prompt="[E] Continue" if room.gate_open else "DOOR SEALED · complete the objective"
		if not prompt.is_empty(): _text(c,prompt,Vector2(22,325),10,Color("f0ddb9"))
	match state:
		"archive": _panel(c,"FIELD ARCHIVE / %d OF %d" % [caches.size(),_cache_total()],archive_text+"\n\nHealth restored. This archive remains collected on retry.","E / Enter / Esc  Return to the mission")
		"choice": _panel(c,"THE EXCHANGE","Give up sight for the rest of this mission?\n\n+25% run and roll speed. Stronger, longer sound traces.\nTerrain and enemies disappear when sound fades.\nQ taps your baton. Footsteps, combat and props also reveal.\nYour health is restored. Retrying preserves the trade.","J  Trade sight     K / Esc  Keep sight")
		"paused": _panel(c,"PAUSED","A/D or arrows   Move\nSpace / C   Jump, then air jump\nJ   Fresh-tap three-strike combo     K   Raise / hold shield\nShift   Roll     S + Space   Drop / dive\nW / S   Climb ladders\nQ   Sound tap     E   Interact     M   Mute", "Esc Resume   R Restart area / reset "+("cargo" if sectors[sector].has("freight") else "relays")+"   N Title")
		"dead": _panel(c,"THE ASCENT CAN WAIT","You fell. This sector can be tried again.\n\nThe current checkpoint restores health and resets guards, relays, shutters and cargo.\nYour sight choice and collected archives remain.","R / Enter  Retry checkpoint     N  Title")
		"complete": _panel(c,"LIFT SECURED / DEMO COMPLETE","The city falls quiet beneath you.\nThe first door is open.\n\nActive play: %02d:%02d     Defeats: %d     Guards: %d\nArchives: %d / %d     Sight: %s\n\nThis completes The First Ascent, not the full tower story." % [int(elapsed)/60,int(elapsed)%60,deaths,kills,caches.size(),_cache_total(),"traded" if blind else "kept"],"Enter / N  Return to title")
