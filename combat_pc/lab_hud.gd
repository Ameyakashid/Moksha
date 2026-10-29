extends Control
var lab: Node
func _draw() -> void:
	if not is_instance_valid(lab):return
	var t:Dictionary=lab.snapshot()
	var v:Vector2=t.get("velocity",Vector2.ZERO)
	var font:=ThemeDB.fallback_font
	draw_rect(Rect2(0,0,640,49),Color(0.027,0.04,0.053,0.95))
	draw_string(font,Vector2(14,17),"MOKSHA / COMBAT PC FOUNDATION",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e8eff0"))
	draw_string(font,Vector2(14,32),"%s  ·  %s     FACE %s    VX %+.0f  VY %+.0f"%[str(t.get("main_action",t.get("state","ready"))).to_upper(),_weapon_status(t),"LEFT" if int(t.get("facing",1))<0 else "RIGHT",v.x,v.y],HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("9bddd0"))
	draw_string(font,Vector2(441,17),"Y  MODE: "+lab.MELEE_MODE_NAMES[lab.melee_mode],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("7f98a8"))
	draw_string(font,Vector2(14,44),"I  ENTRY AIM %s     U  TARGET %s     L  COMPARE FACING AWAY"%["ON" if t.get("inspection_entry_assist_enabled",false) else "OFF","PERCEIVED" if lab.candidate_awareness else "UNPERCEIVED"],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("7f98a8"))
	draw_rect(Rect2(0,318,640,42),Color(0.027,0.04,0.053,0.95))
	draw_string(font,Vector2(14,330),"A/D  MOVE    SPACE  JUMP / AIR JUMP    SHIFT  ROLL    J  ATTACK    K  SHIELD    W/S  CLIMB / LEDGE / CROUCH",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("d0dce1"))
	draw_string(font,Vector2(14,343),"R RESET  1–9,0  B/N FALLS  M SLOPES  T CHAIN  V GUARD  F SEND  H HARD LAND  S+SPACE DIVE  TAB INFO  ESC PAUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("7f98a8"))
	draw_string(font,Vector2(14,354),(lab.feedback_text if lab.feedback_timer>0 else lab.last_contact)+"    /    "+("ROLL INVULNERABLE" if t.get("roll_invulnerable",false) else ("HITPAUSE" if t.get("paused",false) else "READY")),HORIZONTAL_ALIGNMENT_LEFT,-1,6,Color("a6bdc7"))
	if lab.details:
		draw_rect(Rect2(10,55,310,164),Color(0.025,0.037,0.047,0.9))
		draw_string(font,Vector2(17,68),"INPUT %s   GROUNDED %s   EVENT %s"%[str(t.get("move_x",0)),str(t.get("grounded",false)),lab.last_event],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("a0b7c4"))
		draw_string(font,Vector2(17,81),"Dead Cells behavior reference / MOKSHA numeric tuning",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		draw_string(font,Vector2(17,94),"ROLL %.2fs  ATTACK %s  BUFFER %.2f / %.2f"%[float(t.get("roll_cooldown",0)),str(t.get("attack_serial",0)),float(t.get("roll_buffer",0)),float(t.get("attack_buffer",0))],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		draw_string(font,Vector2(17,107),"AIR JUMP %s  ROLL %s  DIVE %s  GRIP %.2fs"%[str(t.get("air_jumps_left",0)),str(t.get("air_roll_available",false)),str(t.get("dive_available",false)),float(t.get("climb_jump_grace",0))],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		draw_string(font,Vector2(17,120),"G  WALL ABILITY %s   PHASE %s"%["ON" if lab.wall_ability_enabled else "OFF",str(t.get("wall_phase","none")).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		draw_string(font,Vector2(17,133),"H  HARD LAND %s   FALL %.0f PX   B/N  HIGH/SOFT"%["ON" if lab.hard_landing_enabled else "OFF",float(t.get("fall_distance",0))],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		draw_string(font,Vector2(17,146),"SHIELD %s   OPEN %s   LOCK %.2fs"%[str(t.get("shield_phase","idle")).to_upper(),str(t.get("shield_parry_open",false)),float(t.get("shield_lock_remaining",0))],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		draw_string(font,Vector2(17,159),"CHAIN %d  STEP %d  QUEUE %d / %.2fs  LOCK %.2fs"%[int(t.get("chain_serial",0)),int(t.get("attack_step_index",-1))+1,int(t.get("chain_pending_input_id",0)),float(t.get("chain_pending_remaining",0)),float(t.get("melee_reuse_lock_remaining",0))],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		draw_string(font,Vector2(17,172),"HOLD %d  ARMED %s  REARM %s  REQUEST %s"%[int(t.get("attack_hold_id",0)),str(t.get("attack_hold_armed",false)),str(t.get("attack_rearm_required",false)),str(t.get("attack_request_kind",""))],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		draw_string(font,Vector2(17,185),"CHARGE %s  %.2f / %.2fs  REPEAT WAIT %.2fs"%[str(t.get("charge_phase","")).to_upper(),float(t.get("charge_elapsed",0)),float(t.get("charge_duration",0)),float(t.get("repeat_restart_remaining",0))],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		draw_string(font,Vector2(17,198),"ENTRY Q%d  %s   %d > %d"%[int(t.get("entry_assist_query_count",0)),str(t.get("entry_assist_reason","")).to_upper(),int(t.get("entry_assist_facing_before",1)),int(t.get("entry_assist_facing_after",1))],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
		var host:Dictionary=lab.entry_host_diagnostics()
		draw_string(font,Vector2(17,211),"HOST %s   ELIG %s  SEEN %s"%[str(host.get("reason","")).to_upper(),str(host.get("eligible",false)),str(host.get("perceived",false))],HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("879da9"))
	if lab.paused:
		draw_rect(Rect2(258,150,124,38),Color(0.02,0.03,0.04,0.92))
		draw_string(font,Vector2(283,174),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)

func _weapon_status(t: Dictionary) -> String:
	if t.get("shield_active", false): return ("SHIELD "+str(t.get("shield_phase", "idle"))).to_upper()
	if str(t.get("weapon_phase","idle"))=="charge":return "CHARGE / %d%%"%roundi(float(t.get("charge_progress",0))*100)
	if str(t.get("weapon_phase", "idle")) != "idle":
		var label: String = str(t.get("attack_step_label", ""))
		return ((label+" / " if not label.is_empty() else "")+str(t.get("weapon_phase", "idle"))).to_upper()
	return str(t.get("pose", "idle")).to_upper()
