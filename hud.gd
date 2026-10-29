extends Node2D
## Screen-space information only; world and sensory simulation stay independent.
var game: Node
const FONT = preload("res://fonts/DejaVuSansMono.ttf")
func _process(_delta: float) -> void: queue_redraw()
func text(value: String, at: Vector2, size := 9, color := Color("abbabd")) -> void:
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func _draw() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	var pale := Color("e6e7dc")
	var accent := Color.WHITE if game.sight_sacrificed else Color("76bbb4")
	var dim := Color("92a8ae")
	draw_rect(Rect2(0,0,640,45),Color(0.025,0.04,0.055,0.97))
	draw_line(Vector2(14,45),Vector2(626,45),Color("375058"),1)
	text("MOKSHA",Vector2(15,17),12,pale)
	text("HEALTH",Vector2(15,34),7,dim)
	for i in game.player.max_hp:
		draw_rect(Rect2(49+i*10,27,7,7),Color("d19d75") if i<game.player.hp else Color("26343c"))
	text("ROLL",Vector2(117,15),7,dim)
	draw_rect(Rect2(117,27,38,4),Color("26343c"))
	draw_rect(Rect2(117,27,38*clampf(1.0-game.player.dash_cd/game.player.tuning.dash_cooldown,0,1),4),accent)
	text(game.level_title.to_upper(),Vector2(184,17),9,pale)
	text(("SIGHT OFF / SPEED %d%%" % roundi(game.player.speed_multiplier*100)) if game.sight_sacrificed else "SIGHT ON / SPEED 100%",Vector2(184,33),8,accent)
	text("GUARDS",Vector2(459,14),7,dim)
	text(str(game.kills)+"/"+str(game.total),Vector2(471,32),11,pale)
	text("PROP KILLS",Vector2(538,14),7,dim)
	text(str(game.prop_kills).pad_zeros(2),Vector2(567,32),11,accent)
	if game.notice_time>0 and game.state=="playing":
		draw_rect(Rect2(10,51,620,21),Color(0.02,0.035,0.05,0.91))
		text(game.notice,Vector2(18,65),8,pale)
	var prompt: String = game.interaction_prompt()
	if not prompt.is_empty():
		draw_rect(Rect2(116,278,408,25),Color("142831") if not game.sight_sacrificed else Color("171717"))
		draw_rect(Rect2(116,278,408,25),accent,false,1)
		var width: float = FONT.get_string_size(prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
		text(prompt,Vector2(320-width/2,294),9,pale)
	elif game.sight_sacrificed and game.state=="playing":
		var hint: String = game.navigation_hint()
		var hint_width: float = FONT.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
		text(hint,Vector2(320-hint_width/2,303),8,Color("c9c9c9"))
	# Compact two-line control rail keeps the sensory input visible.
	draw_rect(Rect2(0,317,640,43),Color(0.025,0.04,0.055,0.98))
	draw_line(Vector2(14,317),Vector2(626,317),Color("375058"),1)
	text("A D MOVE   SPACE JUMP x2   SHIFT ROLL   J / CLICK STRIKE   Q / C TAP",Vector2(16,332),8,pale)
	text("E USE    R RETRY ROOM    N NEW RUN    ESC PAUSE    M SOUND",Vector2(16,348),8,dim)
	if game.level_number==2:
		var percent := int(clampf((1000.0-game.player.global_position.y)/864.0,0,1)*100)
		text(str(percent)+"% UP",Vector2(577,348),8,accent)
	if game.flash>0: draw_rect(Rect2(0,45,640,272),Color(1,1,1,minf(0.12,game.flash)))
	if game.state in ["dead","won","paused"]:
		draw_rect(Rect2(0,45,640,272),Color(0.0,0.01,0.015,0.79))
		draw_rect(Rect2(113,97,414,164),Color("0b1720"))
		draw_rect(Rect2(113,97,414,164),Color("67898d"),false,1)
		var title := "FIRST ASCENT COMPLETE" if game.state=="won" else "OPERATIVE DOWN"
		if game.state=="paused": title="HOLD POSITION"
		text(title,Vector2(139,134),20,pale)
		if game.state=="paused":
			text("ESC RESUME / M TOGGLE SOUND",Vector2(166,176),11,accent)
			text("Q taps the weapon. Real impacts map the room.",Vector2(134,205),8,dim)
		else:
			text("CITY + ARCOLOGY / TWO-LEVEL PROTOTYPE" if game.state=="won" else "Use the scenery. Roll through incoming attacks.",Vector2(137,165),9,dim)
			text("GUARDS %d/%d    PHYSICAL PROP KILLS %d"%[game.kills,game.total,game.prop_kills],Vector2(159,192),9,accent)
			text("R RETRY THIS ROOM / N RETURN TO THE CITY",Vector2(142,231),10,pale)
