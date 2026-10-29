extends Control
var lab: Node2D
func _draw() -> void:
	if not is_instance_valid(lab): return
	var p: MokshaMovementMotor = lab.player
	var n: MokshaMovementMotor = lab.npc
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0,0,640,82),Color(0.025,0.04,0.055,0.98))
	draw_string(font,Vector2(12,17),"MOKSHA   /   MOVEMENT LAB",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e7edf0"))
	draw_string(font,Vector2(12,32),"PC  %-5s   INPUT %+.0f   FACE %s   VX %+.0f   VY %+.0f" % [p.state,p.axis,"LEFT" if p.facing<0 else "RIGHT",p.velocity.x,p.velocity.y],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("69e2e8"))
	draw_string(font,Vector2(12,45),"JUMPS %d/%d   AIR DASH %d/%d   BUFFER %.2f   GRACE %.2f   %s" % [p.jump_count,2 if p.double_jump_enabled else 1,p.air_dash_count,1 if p.air_dash_enabled else 0,p.jump_buffer,p.coyote,p.last_event if p.last_event_seconds>0 else ""],HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("aec2cc"))
	var brain: Node = n.get_node("Intent")
	draw_string(font,Vector2(12,58),"NPC  %s / %s  FACE %s  VX %+.0f" % [brain.brain_state,n.state,"LEFT" if n.facing<0 else "RIGHT",n.velocity.x],HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("e6b75e"))
	draw_string(font,Vector2(12,73),"A/D MOVE    SPACE JUMP (HOLD / TAP)    K / SHIFT DASH    R RESET    ESC PAUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("d0dbe1"))
	draw_rect(Rect2(0,326,640,34),Color(0.025,0.04,0.055,0.98))
	draw_string(font,Vector2(12,338),"TOGGLES  1 DOUBLE %s   2 AIR DASH %s   3 COYOTE %s   4 VARIABLE %s   5 BUFFER %s   6 CHASE %s" % [_on(p.double_jump_enabled),_on(p.air_dash_enabled),_on(p.coyote_enabled),_on(p.variable_jump_enabled),_on(p.input_buffer_enabled),_on(brain.chase_enabled)],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("aec2cc"))
	draw_string(font,Vector2(12,352),"H HIT-PAUSE PROBE   I IMPULSE PROBE   F9 RECORD INPUT TRACE   F8 TWO-LEVEL BUILD   F12 CAPTURE",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("7e99a8"))
	if lab.paused:
		draw_rect(Rect2(235,143,170,60),Color(0.02,0.035,0.05,0.96))
		draw_string(font,Vector2(279,169),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
		draw_string(font,Vector2(255,186),"ESC RESUME  /  R RESET",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("b4c7d2"))
func _on(value: bool) -> String: return "ON" if value else "OFF"
