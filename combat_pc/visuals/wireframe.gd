@tool
class_name MokshaWireframe
extends Node2D
## Original MOKSHA movement presentation. The motor owns every physical root,
## collision, facing decision and ledge phase. No archived controller dependency.

signal phase_event(event_name: String, payload: Dictionary)
const Keys=preload("res://combat_pc/visuals/wireframe_keys.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const CombatKeys=preload("res://combat_pc/visuals/combat_keys.gd")
const ClimbKeys=preload("res://combat_pc/visuals/climb_keys.gd")
const Slope=preload("res://combat_pc/visuals/slope_pose.gd")
const ChargeKeys=preload("res://combat_pc/visuals/charge_keys.gd")
const ComboKeys=preload("res://combat_pc/visuals/combo_keys.gd")
const ShieldKeys=preload("res://combat_pc/visuals/shield_keys.gd")

@export var stroke_width: float=1.05
@export var show_contact_marks: bool=false
@export var ground_presentation: MokshaGroundPresentationProfile
@export_enum("idle","run","start","brake","turn","jump","air_jump","jump_rise","jump_apex","fall","land","land_run","crouch","ledge_catch","ledge_hang","ledge_pull","ledge_step","roll_start","roll_travel","roll_recovery","attack_windup","attack_active","attack_recovery","hurt","drop","dive_startup","dive_descent","dive_impact","dive_recovery","climb_align","climb_idle","climb_ascend","climb_descend","climb_top_exit","climb_blocked","climb_release","wall_run","wall_slide","wall_kick","hard_land_impact","hard_land_recovery","shield_raise","shield_parry","shield_hold","shield_miss_recovery","shield_success_recovery","shield_release_recovery","attack_slash_windup","attack_slash_active","attack_slash_recovery","attack_backhand_windup","attack_backhand_active","attack_backhand_recovery","attack_finisher_windup","attack_finisher_active","attack_finisher_recovery","attack_charge","attack_charged_thrust_windup","attack_charged_thrust_active","attack_charged_thrust_recovery") var preview_pose: String="idle":
	set(value):preview_pose=value;_preview()
@export_range(0.0,1.0,0.01) var preview_phase: float=0.0:
	set(value):preview_phase=value;_preview()
@export_enum("Right:1","Left:-1") var preview_facing: int=1:
	set(value):preview_facing=value;_preview()

var bone_positions: Dictionary:
	get:return _pose.get("bones",{}).duplicate(true)
var pose_name: String:
	get:return str(_pose.get("mode","idle"))
var pose_key: String:
	get:return str(_pose.get("key","ready"))

var _pose: Dictionary={}
var _telemetry: Dictionary={}
var _clock: float=0.0
var _gait_phase: float=0.0
var _last_root:=Vector2.ZERO
var _has_root:=false
var _events: Dictionary={}
var _previous_grounded:=false
var _previous_move: float=0.0
var _previous_speed: float=0.0
var _previous_facing: int=1
var _last_key: String=""
var _last_mode: String="idle"
var _foot_anchors: Dictionary={}
var _released_feet: Dictionary={}
var _last_support: Variant=null
var _grips: Dictionary={}
var _climb_contacts:Dictionary={}
var _climb_contact_points:Dictionary={}
var _climb_shape:Dictionary={}
var _wall_contacts:Dictionary={}
var _wall_contact_points:Dictionary={}
var _wall_binding:Array=[]
var _landing_contacts:Dictionary={}
var _landing_points:Dictionary={}
var _landing_binding:Array=[]
var _last_tick: int=-1
var _slope_binding:Array=[]
var _slope_contacts:Dictionary={}
var _slope_plane_distance:float=0.0
var _combo_serial:int=-1
var _combo_entry:Dictionary={}
var _charge_entry:Dictionary={}
var _combo_contact_facing:int=1
var _shield_attempt_serial:int=-1
var _shield_feedback:Array=[]
var _shield_feedback_seen:Dictionary={}

func _ready() -> void:
	if Engine.is_editor_hint():
		_preview()
	else:
		var motor:=get_parent()
		if motor and motor.has_signal("movement_event") and not motor.is_connected("movement_event",Callable(self,"event")):
			motor.connect("movement_event",Callable(self,"event"))
		var initial_root:Vector2=motor.global_position if motor is Node2D else Vector2.ZERO
		present(0.0,{"position":initial_root,"velocity":Vector2.ZERO,"facing":1,"grounded":true,"pose":"idle"})

func event(event_name: String,payload: Dictionary={}) -> void:
	var aliases:Dictionary={"takeoff":"ground_jump","land":"landed","pull":"pullup_begin","step":"ledge_step","release":"ledge_release"}
	var key: String=aliases.get(event_name,event_name)
	if ground_presentation != null and ground_presentation.retire_conflicting_intent:
		# A new ground intention retires the old transient instead of replaying
		# it after a short tap. This changes presentation only, never the motor.
		if key in ["run_start","brake","turn"]:
			for prior in ["run_start","brake","turn"]:
				if prior!=key: _events.erase(prior)
	if key=="strike_confirmed" and _combo_serial>=0:
		if int(payload.get("serial",-1))!=_combo_serial or not payload.has("contact_position"):return
		_combo_contact_facing=0 # Resolve from this serial's authoritative presentation snapshot.
	if key=="charge_started":
		_charge_entry.clear();_combo_entry.clear();_combo_serial=-1
		if str(_telemetry.get("attack_pose_id","")) in ComboKeys.STEP_IDS and str(_telemetry.get("weapon_phase",""))=="recovery":
			_charge_entry={"step":str(_telemetry.attack_pose_id),"phase":"recovery","progress":float(_telemetry.weapon_phase_progress),"facing":int(_pose.get("facing",_telemetry.get("facing",1)))}
		_events.erase("strike_confirmed")
	elif key in ["charge_cancelled","charge_committed"]:
		_charge_entry.clear();_events.erase("strike_confirmed")
		if str(_pose.get("mode",""))=="attack_charge":_pose.weapon={"visible":false};queue_redraw()
	if key=="attack_started":
		_charge_entry.clear();_combo_entry.clear();_combo_serial=-1
		if str(payload.get("attack_pose_id","")) in ComboKeys.STEP_IDS or str(payload.get("attack_pose_id",""))==ChargeKeys.STEP_ID:
			_combo_serial=int(payload.get("serial",-1))
			if str(_telemetry.get("attack_pose_id","")) in ComboKeys.STEP_IDS and str(_telemetry.get("weapon_phase",""))=="recovery" and int(payload.get("chain_serial",-1))==int(_telemetry.get("chain_serial",-2)):
				_combo_entry={"step":str(_telemetry.attack_pose_id),"phase":"recovery","progress":float(_telemetry.weapon_phase_progress),"facing":int(_pose.get("facing",_telemetry.get("facing",1)))}
	elif key in ["attack_finished","attack_cancelled","hurt_started","roll_started","shield_started","dive_started","climb_attached","wall_attached","ledge_catch","hard_land_started"]:
		_charge_entry.clear();_combo_entry.clear();_combo_serial=-1
		if _pose.has("combo"):_pose.weapon={"visible":false};queue_redraw()
	_events[key]={"time":_clock,"payload":payload.duplicate(true)}
	if key=="shield_started":
		_clear_shield_feedback();_shield_attempt_serial=int(payload.get("serial",payload.get("shield_serial",-1)))
		if _pose.has("weapon"):_pose.weapon={"visible":false};queue_redraw()
	elif key in ["shield_finished","shield_cancelled","hurt_started","roll_started","attack_started","charge_started","dive_started","climb_attached","wall_attached","ledge_catch","hard_land_started"]:_clear_shield_feedback()
	elif key in ["defense_resolved","shield_counter_confirmed","shield_reflection_confirmed"]:_record_shield_feedback(key,payload)
	if key in ["roll_started","attack_started","charge_started","hurt_started","drop_started","dive_started","climb_attached","wall_attached","hard_land_started","shield_started"]:
		_foot_anchors.clear();_released_feet.clear();_grips.clear()
		for transient in ["ground_jump","air_jump","run_start","brake","turn","landed","strike_confirmed"]:_events.erase(transient)
	if key in ["attack_cancelled","attack_finished","roll_cancelled","hurt_started"]:_events.erase("strike_confirmed")
	if key=="dive_impact":_foot_anchors.clear();_released_feet.clear()
	if key in ["dive_finished","dive_cancelled","hard_land_finished","hard_land_cancelled"]:_events.erase("landed")
	if key in ["hard_land_started","hard_land_finished","hard_land_cancelled","ground_jump","air_jump","roll_started","attack_started","charge_started","hurt_started","dive_started","climb_attached","wall_attached","ledge_catch"]:_clear_landing_contacts(key)
	if key in ["ground_jump","air_jump","ledge_catch","ledge_release"]:
		_foot_anchors.clear();_released_feet.clear()
	if key in ["ground_jump","air_jump","ledge_catch","roll_started","attack_started","charge_started","hurt_started","dive_started","climb_attached","wall_attached","hard_land_started","shield_started"]:_clear_slope_contacts(key)
	if key in ["ground_jump","air_jump"]:_events.erase("landed")
	if key=="ledge_release":_grips.clear()
	if key in ["climb_attached","climb_detached"]:_clear_climb_contacts(key);_foot_anchors.clear();_grips.clear()
	if key in ["wall_attached","wall_detached","wall_kick","wall_ledge_handoff","ledge_catch","climb_attached"]:_clear_wall_contacts(key)

func present(dt: float,telemetry: Dictionary={}) -> void:
	if dt<0.0:return
	var tick:int=int(telemetry.get("tick_id",-1))
	if tick>=0 and tick==_last_tick:return
	_last_tick=tick
	var visual_dt:=0.0 if bool(telemetry.get("paused",false)) else dt
	_clock+=visual_dt
	_telemetry=telemetry.duplicate(true)
	var root:Vector2=telemetry.get("world_position",telemetry.get("position",Vector2.ZERO))
	var velocity:Vector2=telemetry.get("velocity",Vector2.ZERO)
	var grounded:bool=telemetry.get("grounded",false)
	var move:float=float(telemetry.get("move_x",0.0))
	var facing:int=int(Pose.facing_of(telemetry))
	var support_delta:Vector2=telemetry.get("support_displacement",Vector2.ZERO)
	var travel:=velocity*visual_dt
	if telemetry.has("position") or telemetry.has("world_position"):
		travel=root-_last_root-support_delta if _has_root else Vector2.ZERO
		_last_root=root;_has_root=true
	if bool(telemetry.get("paused",false)):travel=Vector2.ZERO
	_gait_phase=fposmod(_gait_phase+absf(travel.x)/maxf(Pose.stride_for(telemetry),1.0),1.0)
	if grounded and _previous_grounded and not is_zero_approx(move) and is_zero_approx(_previous_move) and absf(_previous_speed)<35.0:
		event("run_start")
	if grounded and _previous_grounded and is_zero_approx(move) and not is_zero_approx(_previous_move) and absf(velocity.x)>20.0:
		event("brake")
	var reversing_momentum := absf(_previous_speed)>20.0 and signf(_previous_speed)!=facing
	if grounded and facing!=_previous_facing and absf(velocity.x)>20.0 and (ground_presentation==null or not ground_presentation.retire_conflicting_intent or reversing_momentum):
		event("turn")
	_previous_grounded=grounded;_previous_move=move;_previous_speed=velocity.x;_previous_facing=facing
	var selection:=_select(telemetry)
	var inputs:=telemetry.duplicate(true)
	inputs["visual_time"]=_clock
	# Presentation-only label from the existing motor detach event.
	inputs["climb_top_release"]=str(selection.mode)=="climb_release" and str(_events.get("climb_detached",{}).get("payload",{}).get("reason",""))=="top_exit"
	inputs["gait_phase"]=_gait_phase
	if _events.has("landed"):
		inputs["preimpact_speed"]=_events.landed.payload.get("preimpact_speed",_events.landed.payload.get("speed",300.0))
		inputs["landing_visual_progress"]=clampf(_age("landed")/Keys.TUNING.landing_time,0,1)
	inputs["strike_confirmed_visual"]=_age("strike_confirmed")<CombatKeys.IMPACT_TIME
	if str(selection.mode) in ComboKeys.MODES or str(selection.mode) in ChargeKeys.STRIKE_MODES:
		if not _combo_entry.is_empty():inputs["combo_visual_entry"]=_combo_entry.duplicate(true)
		inputs.strike_confirmed_visual=bool(inputs.strike_confirmed_visual) and int(_events.get("strike_confirmed",{}).get("payload",{}).get("serial",-1))==int(telemetry.get("attack_serial",-2))
		if inputs.strike_confirmed_visual:
			if _combo_contact_facing==0:_combo_contact_facing=int(telemetry.get("attack_facing",telemetry.get("facing",1)))
			inputs["combo_contact_world"]=_events.strike_confirmed.payload.contact_position
			inputs["combo_contact_facing"]=_combo_contact_facing
	else:_combo_entry.clear()
	if str(selection.mode)=="attack_charge":
		if not _charge_entry.is_empty():inputs["charge_visual_entry"]=_charge_entry.duplicate(true)
		inputs.strike_confirmed_visual=false
	else:_charge_entry.clear()
	if str(selection.mode).begins_with("shield_"):
		inputs["shield_visual_feedback"]=_active_shield_feedback(int(telemetry.get("shield_serial",-1)))
	else:_clear_shield_feedback()
	_pose=Pose.evaluate(selection.mode,selection.phase,inputs)
	if not bool(_pose.get("slope_support",false)):_clear_slope_contacts("owner_or_surface_changed")
	if bool(_pose.get("landing_support",false)):
		_clear_climb_contacts("owner_changed");_clear_wall_contacts("owner_changed")
		_apply_landing_contacts(root,support_delta)
	elif bool(_pose.get("wall_support",false)):
		_clear_landing_contacts("owner_changed")
		_clear_climb_contacts("owner_changed")
		_apply_wall_contacts(root)
	elif bool(_pose.get("climb_support",false)):
		_clear_landing_contacts("owner_changed")
		_clear_wall_contacts("owner_changed")
		_apply_climb_contacts(root)
	else:
		_clear_landing_contacts("owner_changed")
		_clear_climb_contacts("owner_changed")
		_clear_wall_contacts("owner_changed")
		_apply_support(root,support_delta)
	var key:=str(_pose.key)
	if key!=_last_key or _last_mode!=str(_pose.mode):
		phase_event.emit("pose_key",{"pose":_pose.mode,"key":key,"progress":_pose.phase,"authored":true})
		_last_key=key;_last_mode=str(_pose.mode)
	queue_redraw()

func update_visual(dt: float,telemetry: Dictionary={}) -> void:
	present(dt,telemetry)

func _age(event_name:String) -> float:
	return _clock-float(_events[event_name].time) if _events.has(event_name) else INF

func _clear_shield_feedback() -> void:
	_shield_feedback.clear();_shield_feedback_seen.clear();_shield_attempt_serial=-1
	if _pose.has("shield"):_pose.erase("shield");queue_redraw()

func _record_shield_feedback(event_name:String,payload:Dictionary) -> void:
	var serial:=int(payload.get("shield_serial",payload.get("serial",-1)))
	if serial<0 or serial!=_shield_attempt_serial or not payload.has("contact_position") or not payload.has("normal"):return
	var kind:String=str(payload.get("outcome","")) if event_name=="defense_resolved" else ("counter" if event_name=="shield_counter_confirmed" else "reflect")
	if kind not in ["parried","guarded","counter","reflect"]:return
	if event_name=="defense_resolved" and not bool(payload.get("consumed",false)):return
	var point:Vector2=payload.contact_position;var normal:Vector2=payload.normal
	if not point.is_finite() or not normal.is_finite() or normal.length_squared()<0.5:return
	var identity:=str(serial)+"/"+str(payload.get("attack_key",""))+"/"+kind
	if _shield_feedback_seen.has(identity):return
	_shield_feedback_seen[identity]=true
	_shield_feedback.append({"kind":kind,"point":point,"normal":normal.normalized(),"facing":int(payload.get("shield_facing",1)),"serial":serial,"time":_clock})

func _active_shield_feedback(serial:int) -> Array:
	var result:Array=[]
	if serial!=_shield_attempt_serial:return result
	for marker in _shield_feedback:
		if _clock-float(marker.time)<=ShieldKeys.FEEDBACK_SECONDS:result.append(marker.duplicate(true))
	return result

func _select(t:Dictionary) -> Dictionary:
	if bool(t.get("defeated",false)):
		_foot_anchors.clear();_released_feet.clear();_grips.clear();_clear_shield_feedback()
		return {"mode":"defeated" if bool(t.get("grounded",false)) else "defeated_air","phase":clampf(float(t.get("defeat_progress",0)),0,1)}
	var supplied:String=str(t.get("pose",""))
	var phase_name:String=str(t.get("action_phase",""))
	var progress:float=clampf(float(t.get("phase_progress",0.0)),0,1)
	if supplied=="drop_blocked":return {"mode":"crouch","phase":0.0}
	if supplied=="hurt" or str(t.get("main_action",""))=="hurt":
		return {"mode":"hurt","phase":clampf(float(t.get("hurt_progress",progress)),0,1)}
	# Hard contact is a motor owner, never an event-age or stale-phase overlay.
	if str(t.get("main_action",""))=="hard_land" or supplied in ["hard_land_impact","hard_land_recovery"]:
		var hard_phase:String=str(t.get("hard_land_phase",supplied.trim_prefix("hard_land_")))
		if hard_phase in ["impact","recovery"]:
			return {"mode":"hard_land_"+hard_phase,"phase":clampf(float(t.get("hard_land_phase_progress",progress)),0,1)}
	if supplied in ShieldKeys.MODES and bool(t.get("shield_active",false)):
		return {"mode":supplied,"phase":clampf(float(t.get("shield_phase_progress",progress)),0,1)}
	var roll:String=str(t.get("roll_phase",""))
	if roll in ["start","travel","recovery"] or supplied.begins_with("roll_"):
		return {"mode":"roll_"+roll if not roll.is_empty() else supplied,"phase":clampf(float(t.get("roll_phase_progress",progress)),0,1)}
	var dive:String=str(t.get("dive_phase",""))
	if supplied.begins_with("dive_") or (str(t.get("main_action",""))=="dive" and dive in ["startup","descent","impact","recovery"]):
		return {"mode":"dive_"+dive if not dive.is_empty() else supplied,"phase":clampf(float(t.get("dive_phase_progress",progress)),0,1)}
	# A collision exception can outlive the drop owner. It must not own the pose.
	if supplied=="drop" or str(t.get("main_action",""))=="drop":
		return {"mode":"drop","phase":clampf(float(t.get("drop_progress",progress)),0,1)}
	var weapon:String=str(t.get("weapon_phase","idle"))
	if weapon=="charge" and (supplied=="attack_charge" or supplied.is_empty()):
		return {"mode":"attack_charge","phase":clampf(float(t.get("charge_progress",0)),0,1)}
	if str(t.get("attack_pose_id",""))==ChargeKeys.STEP_ID:
		if weapon in ["windup","active","recovery"] and (supplied in ChargeKeys.STRIKE_MODES or supplied.is_empty()):
			return {"mode":"attack_charged_thrust_"+weapon,"phase":clampf(float(t.get("weapon_phase_progress",progress)),0,1)}
		weapon="idle"
	# A descriptive chain field cannot reclaim a different supplied pose owner.
	if str(t.get("attack_pose_id","")) in ComboKeys.STEP_IDS and not supplied.is_empty() and supplied not in ComboKeys.MODES:weapon="idle"
	if weapon in ["windup","active","recovery"] and str(t.get("attack_pose_id","")) in ComboKeys.STEP_IDS:
		return {"mode":"attack_"+str(t.attack_pose_id)+"_"+weapon,"phase":clampf(float(t.get("weapon_phase_progress",progress)),0,1)}
	if weapon in ["windup","active","recovery"] or (supplied.begins_with("attack_") and supplied not in ChargeKeys.MODES):
		return {"mode":"attack_"+weapon if weapon!="idle" else supplied,"phase":clampf(float(t.get("weapon_phase_progress",progress)),0,1)}
	if str(t.get("main_action",""))=="climb" or (supplied.begins_with("climb_") and bool(t.get("climb_active",false))):
		var climb_phase:String=str(t.get("climb_phase",supplied.trim_prefix("climb_")))
		if climb_phase in ["align","idle","ascend","descend","top_exit","blocked"]:
			return {"mode":"climb_"+climb_phase,"phase":clampf(float(t.get("climb_phase_progress",progress)),0,1)}
	if supplied.begins_with("ledge_"):return {"mode":supplied,"phase":progress}
	if str(t.get("main_action","")) in ["ledge","climb","mantle"] and phase_name in ["catch","hang","pull","step"]:
		return {"mode":"ledge_"+phase_name,"phase":progress}
	if str(t.get("main_action",""))=="wall" or supplied in ["wall_run","wall_slide","wall_kick"]:
		var wall_phase:String=str(t.get("wall_phase",supplied.trim_prefix("wall_")))
		if wall_phase in ["run","slide","kick"]:
			return {"mode":"wall_"+wall_phase,"phase":clampf(float(t.get("wall_kick_progress" if wall_phase=="kick" else "wall_phase_progress",progress)),0,1)}
	if _age("climb_detached")<ClimbKeys.RELEASE_SECONDS:
		var reason:String=str(_events.climb_detached.payload.get("reason",""))
		if reason in ["top_exit","bottom_exit","floor_exit","horizontal_release"] and _age("ground_jump")>=Keys.TUNING.jump_time and _age("air_jump")>=Keys.TUNING.air_jump_time:
			return {"mode":"climb_release","phase":_age("climb_detached")/ClimbKeys.RELEASE_SECONDS}
	if bool(t.get("crouched",false)) or supplied=="crouch":return {"mode":"crouch","phase":0.0}
	var grounded:bool=t.get("grounded",false)
	var velocity:Vector2=t.get("velocity",Vector2.ZERO)
	var move:float=float(t.get("move_x",0))
	var start_seconds: float=Keys.TUNING.start_time
	var brake_seconds: float=Keys.TUNING.brake_time
	var turn_seconds: float=Keys.TUNING.turn_time
	var current_intent := ground_presentation != null and ground_presentation.retire_conflicting_intent
	if ground_presentation != null:
		start_seconds=ground_presentation.duration("start",start_seconds)
		brake_seconds=ground_presentation.duration("brake",brake_seconds)
		turn_seconds=ground_presentation.duration("turn",turn_seconds)
	if not grounded:
		# A released short jump may reach its real apex before the authored takeoff
		# transient ends. Its physical apex/fall must remain readable immediately.
		if supplied in ["jump_apex","fall"]:return {"mode":supplied,"phase":progress}
		if _age("air_jump")<Keys.TUNING.air_jump_time:return {"mode":"air_jump","phase":_age("air_jump")/Keys.TUNING.air_jump_time}
		if _age("ground_jump")<Keys.TUNING.jump_time:return {"mode":"jump","phase":_age("ground_jump")/Keys.TUNING.jump_time}
		if supplied in ["jump_rise","jump_apex","fall"]:return {"mode":supplied,"phase":progress}
		return {"mode":"jump_rise" if velocity.y < -45 else ("jump_apex" if absf(velocity.y)<=45 else "fall"),"phase":0.0}
	if _age("landed")<Keys.TUNING.landing_time:
		return {"mode":"land_run" if not is_zero_approx(move) and absf(velocity.x)>35.0 else "land","phase":_age("landed")/Keys.TUNING.landing_time}
	if supplied=="land":return {"mode":"land","phase":progress}
	if _age("turn")<turn_seconds and (current_intent or absf(velocity.x)>12.0) and (not current_intent or not is_zero_approx(move)):
		return {"mode":"turn","phase":_age("turn")/turn_seconds}
	if supplied=="turn" and not current_intent:return {"mode":"turn","phase":progress}
	if (supplied=="brake" or is_zero_approx(move)) and _age("brake")<brake_seconds:
		return {"mode":"brake","phase":_age("brake")/brake_seconds}
	if supplied=="brake":return {"mode":"brake","phase":progress}
	if supplied in ["run","run_fast","run_slow"] or absf(velocity.x)>8.0:
		if _age("run_start")<start_seconds:return {"mode":"start","phase":_age("run_start")/start_seconds}
		return {"mode":"run","phase":_gait_phase}
	if _age("pullup_end")<0.10:return {"mode":"ledge_settle","phase":_age("pullup_end")/0.10}
	return {"mode":"idle","phase":0.0}

func _apply_landing_contacts(root:Vector2,support_delta:Vector2) -> void:
	_grips.clear();_released_feet.clear()
	var normal:Vector2=_telemetry.get("floor_normal",Vector2.UP)
	if not normal.is_finite() or normal.y>=-0.1:normal=Vector2.UP
	normal=normal.normalized()
	var binding:Array=[_telemetry.get("support_id",0),normal]
	if binding!=_landing_binding:
		_clear_landing_contacts("surface_changed")
		_landing_binding=binding
	var plane:Vector2=_telemetry.get("floor_contact_point",root)
	var bones:Dictionary=_pose.bones
	for i in 2:
		var side:String="near" if i==0 else "far"
		var kind:String="planted" if _pose.planted_feet[i] else ("sliding" if _pose.landing_touch_feet[i] else "none")
		var previous:String=str(_landing_contacts.get(side,"none"))
		if kind!="planted":_foot_anchors.erase(side)
		else:
			if not _foot_anchors.has(side):_foot_anchors[side]=root+Vector2(bones["sole_"+side])
			else:_foot_anchors[side]+=support_delta
			# Normal/plane come from actual contact; carrier motion is never skid.
			var anchor:Vector2=_foot_anchors[side]
			anchor-=normal*(anchor-plane).dot(normal)
			_foot_anchors[side]=anchor
			var sole:=anchor-root
			var ankle:=sole+normal*1.4
			var hip:Vector2=bones["hip_"+side]
			if hip.distance_to(ankle)>15.98:
				# A discontinuous host edit cannot leave an unreachable planted leg.
				_foot_anchors[side]=root+Vector2(bones["sole_"+side])
				sole=Vector2(_foot_anchors[side])-root;ankle=sole+normal*1.4
				kind="sliding";_pose.planted_feet[i]=false
			var tangent:=Vector2(-normal.y,normal.x)*float(_pose.facing)
			bones["sole_"+side]=sole;bones["ankle_"+side]=ankle
			bones["heel_"+side]=sole-tangent*1.8;bones["toe_"+side]=sole+tangent*3.6
			var bend:=signf((ankle-hip).cross(Vector2(bones["knee_"+side])-hip))
			if is_zero_approx(bend):bend=-float(_pose.facing)
			bones["knee_"+side]=Pose.solve_elbow(hip,ankle,8,8,bend)
			if (root+Vector2(bones["knee_"+side])-plane).dot(normal)<0:
				bones["knee_"+side]=Pose.solve_elbow(hip,ankle,8,8,-bend)
		var point:=root+Vector2(bones["sole_"+side])
		if kind!=previous:
			if previous!="none":phase_event.emit("foot_release",{"side":side,"surface":"floor","contact_type":previous,"position":_landing_points.get(side,point),"authored":true})
			if kind!="none":phase_event.emit("foot_plant" if kind=="planted" else "foot_touch",{"side":side,"surface":"floor","contact_type":kind,"position":point,"normal":normal,"authored":true})
		_landing_contacts[side]=kind;_landing_points[side]=point

func _clear_landing_contacts(reason:String) -> void:
	if _landing_binding.is_empty() and _landing_contacts.is_empty():return
	for side in _landing_contacts:
		var kind:String=str(_landing_contacts[side])
		if kind!="none":phase_event.emit("foot_release",{"side":side,"surface":"floor","contact_type":kind,"position":_landing_points.get(side,Vector2.ZERO),"reason":reason,"authored":true})
	_landing_contacts.clear();_landing_points.clear();_landing_binding.clear()
	_foot_anchors.clear();_released_feet.clear()

func _apply_wall_contacts(root:Vector2) -> void:
	_foot_anchors.clear();_released_feet.clear();_grips.clear()
	var binding:Array=[_telemetry.get("wall_contact_id",0),_telemetry.get("wall_episode_serial",0),_telemetry.get("wall_side",1)]
	if binding!=_wall_binding:
		_clear_wall_contacts("contact_changed")
		_wall_binding=binding
	for i in 2:
		var side:String="near" if i==0 else "far"
		for limb in ["hand","foot"]:
			var contact_key:String=limb+"_"+side
			var planted:bool=bool(_pose.planted_hands[i] if limb=="hand" else _pose.planted_feet[i])
			var touching:bool=bool(_pose.wall_touch_hands[i] if limb=="hand" else _pose.wall_touch_feet[i])
			var kind:String="planted" if planted else ("sliding" if touching else "none")
			var old_kind:String=str(_wall_contacts.get(contact_key,"none"))
			var bone:String=("palm_" if limb=="hand" else "sole_")+side
			var point:Vector2=root+Vector2(_pose.bones[bone])
			if kind!=old_kind:
				if old_kind!="none":phase_event.emit(limb+"_release",{"side":side,"position":_wall_contact_points.get(contact_key,point),"surface":"wall","contact_type":old_kind,"reason":"phase_or_reach","authored":true})
				if kind!="none":phase_event.emit(("hand_grip" if limb=="hand" else "foot_plant") if planted else limb+"_touch",{"side":side,"position":point,"surface":"wall","contact_type":kind,"normal":_pose.wall_normal,"authored":true})
			_wall_contacts[contact_key]=kind;_wall_contact_points[contact_key]=point

func _clear_wall_contacts(reason:String) -> void:
	for contact_key in _wall_contacts:
		var kind:String=str(_wall_contacts[contact_key])
		if kind=="none":continue
		var parts:PackedStringArray=String(contact_key).split("_")
		phase_event.emit(parts[0]+"_release",{"side":parts[1],"position":_wall_contact_points.get(contact_key,Vector2.ZERO),"surface":"wall","contact_type":kind,"reason":reason,"authored":true})
	_wall_contacts.clear();_wall_contact_points.clear();_wall_binding.clear()

func _apply_climb_contacts(root:Vector2) -> void:
	# The pure solver derives exact rung points from actual relative travel.
	# These markers observe those points; they never hold the physical root.
	_foot_anchors.clear();_released_feet.clear();_grips.clear()
	var shape:Dictionary={"target":_telemetry.get("climb_target_id",0),"width":_telemetry.get("climb_width",20.0),"spacing":_telemetry.get("climb_rung_spacing",12.0),"offset":_telemetry.get("climb_rung_origin_offset",4.0),"type":_telemetry.get("climb_type","ladder"),"height":float(_telemetry.get("climb_bottom_y",0))-float(_telemetry.get("climb_top_y",0))}
	if not _same_climb_geometry(shape):
		_clear_climb_contacts("geometry_changed")
		_climb_shape=shape
	for i in 2:
		var side:String="near" if i==0 else "far"
		for kind in ["hand","foot"]:
			var contact_key:String=kind+"_"+side
			var on:bool=bool(_pose.planted_hands[i] if kind=="hand" else _pose.planted_feet[i])
			var bone:String=("palm_" if kind=="hand" else "sole_")+side
			if on and not bool(_climb_contacts.get(contact_key,false)):
				phase_event.emit("hand_grip" if kind=="hand" else "foot_plant",{"side":side,"position":root+Vector2(_pose.bones[bone]),"surface":"climbable","authored":true})
			elif not on and bool(_climb_contacts.get(contact_key,false)):
				phase_event.emit("hand_release" if kind=="hand" else "foot_release",{"side":side,"position":_climb_contact_points.get(contact_key,root+Vector2(_pose.bones[bone])),"surface":"climbable","reason":"reach_or_step","authored":true})
			_climb_contacts[contact_key]=on
			_climb_contact_points[contact_key]=root+Vector2(_pose.bones[bone])

func _clear_climb_contacts(reason:String) -> void:
	for contact_key in _climb_contacts:
		if not bool(_climb_contacts[contact_key]):continue
		var parts:PackedStringArray=String(contact_key).split("_")
		phase_event.emit("hand_release" if parts[0]=="hand" else "foot_release",{"side":parts[1],"position":_climb_contact_points.get(contact_key,Vector2.ZERO),"surface":"climbable","reason":reason,"authored":true})
	_climb_contacts.clear();_climb_contact_points.clear();_climb_shape.clear()

func _same_climb_geometry(candidate:Dictionary) -> bool:
	if _climb_shape.is_empty():return false
	if candidate.target!=_climb_shape.target or candidate.type!=_climb_shape.type:return false
	for field in ["width","spacing","offset","height"]:
		if not is_equal_approx(float(candidate[field]),float(_climb_shape[field])):return false
	return true

func _apply_support(root:Vector2,support_delta:Vector2) -> void:
	if bool(_pose.get("slope_support",false)):
		_apply_slope_support(root,support_delta)
		return
	var support:Variant=_telemetry.get("support_id",0)
	if support!=_last_support:
		_foot_anchors.clear();_released_feet.clear();_last_support=support
	for side in _foot_anchors:_foot_anchors[side]+=support_delta
	var bones:Dictionary=_pose.bones
	var facing:float=_pose.facing
	var grounded:bool=_telemetry.get("grounded",false)
	var ledge:bool=_pose.ledge_support
	for i in 2:
		var suffix:="near" if i==0 else "far"
		var on:bool=bool(_pose.planted_feet[i]) and (grounded or (ledge and str(_pose.mode)=="ledge_step"))
		if not on:
			_foot_anchors.erase(suffix);_released_feet.erase(suffix)
		elif _released_feet.has(suffix):
			on=false
		else:
			if not _foot_anchors.has(suffix):
				_foot_anchors[suffix]=root+Vector2(bones["sole_"+suffix])
				phase_event.emit("foot_plant",{"side":suffix,"position":_foot_anchors[suffix],"authored":true})
			var sole:Vector2=Vector2(_foot_anchors[suffix])-root
			var ankle:=sole+Vector2(0,-1.4)
			var hip:Vector2=bones["hip_"+suffix]
			if hip.distance_to(ankle)>Keys.TUNING.upper_leg+Keys.TUNING.lower_leg-0.02:
				on=false;_foot_anchors.erase(suffix);_released_feet[suffix]=true
			else:
				bones["sole_"+suffix]=sole
				bones["ankle_"+suffix]=ankle
				bones["heel_"+suffix]=sole+Vector2(-1.8*facing,0)
				bones["toe_"+suffix]=sole+Vector2(3.6*facing,0)
				var bend:float=-facing
				if bool(_pose.get("floor_guard",false)):
					bend=signf((ankle-hip).cross(Vector2(bones["knee_"+suffix])-hip))
					if is_zero_approx(bend):bend=-facing
				bones["knee_"+suffix]=Pose.solve_elbow(hip,ankle,Keys.TUNING.upper_leg,Keys.TUNING.lower_leg,bend)
				if bool(_pose.get("floor_guard",false)) and bones["knee_"+suffix].y>0:
					bones["knee_"+suffix]=Pose.solve_elbow(hip,ankle,Keys.TUNING.upper_leg,Keys.TUNING.lower_leg,-bend)
		_pose.planted_feet[i]=on
		var grip:bool=bool(_pose.planted_hands[i])
		if grip and not bool(_grips.get(suffix,false)):
			phase_event.emit("hand_grip",{"side":suffix,"position":root+Vector2(bones["palm_"+suffix]),"authored":true})
		_grips[suffix]=grip

func _apply_slope_support(root:Vector2,support_delta:Vector2) -> void:
	var normal:Vector2=_pose.floor_normal
	var binding:Array=[_telemetry.get("support_id",0),normal]
	var plane_world:Vector2=_telemetry.floor_contact_point
	var changed:bool=_slope_binding.is_empty()
	if not changed:
		changed=binding[0]!=_slope_binding[0] or Vector2(_slope_binding[1]).distance_to(normal)>0.0001 or absf(plane_world.dot(normal)-_slope_plane_distance-support_delta.dot(normal))>0.03
	if changed:
		_clear_slope_contacts("surface_changed")
		_foot_anchors.clear();_released_feet.clear();_slope_binding=binding
	_slope_plane_distance=plane_world.dot(normal)
	var plane:Vector2=Vector2(_telemetry.floor_contact_point)-root
	var relative:Vector2=_telemetry.get("floor_relative_velocity",_telemetry.get("velocity",Vector2.ZERO))
	for i in 2:
		var side:String="near" if i==0 else "far"
		var on:bool=_pose.planted_feet[i]
		var old:bool=_slope_contacts.has(side)
		if not on:
			_foot_anchors.erase(side);_released_feet.erase(side)
		elif _released_feet.has(side):
			on=false
			if relative.is_zero_approx():_released_feet.erase(side)
		else:
			if not _foot_anchors.has(side):_foot_anchors[side]=root+Vector2(_pose.bones["sole_"+side])
			else:_foot_anchors[side]+=support_delta
			var sole:Vector2=Vector2(_foot_anchors[side])-root
			sole-=normal*(sole-plane).dot(normal)
			var hip:Vector2=_pose.bones["hip_"+side]
			if hip.distance_to(sole+normal*1.4)>Slope.REACH+0.01:
				on=false;_foot_anchors.erase(side);_released_feet[side]=true
			else:
				_foot_anchors[side]=root+sole
				Slope.set_leg(_pose,side,sole,normal)
		_pose.planted_feet[i]=on
		if on:
			var point:=root+Vector2(_pose.bones["sole_"+side])
			if not old:phase_event.emit("foot_plant",{"side":side,"position":point,"surface":"slope","normal":normal,"authored":true})
			_slope_contacts[side]=point
		elif old:
			phase_event.emit("foot_release",{"side":side,"position":_slope_contacts[side],"surface":"slope","reason":"step_or_reach","authored":true})
			_slope_contacts.erase(side)

func _clear_slope_contacts(reason:String) -> void:
	if _slope_binding.is_empty():return
	for side in _slope_contacts:phase_event.emit("foot_release",{"side":side,"position":_slope_contacts[side],"surface":"slope","reason":reason,"authored":true})
	_slope_contacts.clear();_slope_binding.clear();_foot_anchors.clear();_released_feet.clear()

func evaluate_pose(mode:String,phase:float,telemetry:Dictionary={}) -> Dictionary:
	return Pose.evaluate(mode,phase,telemetry)

func get_pose() -> Dictionary:
	return _pose.duplicate(true)

func get_bones(world_space:bool=false) -> Dictionary:
	var result:Dictionary=bone_positions
	if world_space:
		var root:Vector2=_telemetry.get("world_position",_telemetry.get("position",Vector2.ZERO))
		for bone in result:result[bone]+=root
	return result

func reset_presentation() -> void:
	_combo_serial=-1;_combo_entry.clear();_charge_entry.clear()
	if _pose.has("combo"):_pose.weapon={"visible":false};queue_redraw()
	_events.clear();_foot_anchors.clear();_released_feet.clear();_grips.clear()
	_clear_climb_contacts("reset")
	_clear_wall_contacts("reset")
	_clear_landing_contacts("reset")
	_clear_slope_contacts("reset")
	_clear_shield_feedback()
	_has_root=false;_last_tick=-1;_gait_phase=0;_last_key="";_last_support=null

func _preview() -> void:
	if not Engine.is_editor_hint():return
	var phase:float=preview_phase
	var anchor:=Vector2(9.2,-29)
	if preview_pose=="ledge_pull":anchor=Vector2(9.2,lerpf(-29,1,phase))
	elif preview_pose=="ledge_step":anchor=Vector2(lerpf(9.2,-12,phase),lerpf(1,0,phase))
	var telemetry:Dictionary={"position":Vector2.ZERO,"velocity":Vector2(260*preview_facing,0),"facing":preview_facing,"grounded":true,"move_x":preview_facing,"palm_target":Vector2(anchor.x*preview_facing,anchor.y),"visual_time":0.0,"gait_phase":phase}
	if preview_pose.begins_with("climb_"):
		var preview_root:=Vector2(0,80-phase*24)
		if preview_pose=="climb_align":preview_root.x=-10*(1-phase)*preview_facing
		if preview_pose=="climb_top_exit":preview_root.y=34*(1-phase)
		telemetry.position=preview_root;telemetry["world_position"]=preview_root
		telemetry["climb_axis_x"]=0.0;telemetry["climb_top_y"]=0.0;telemetry["climb_bottom_y"]=180.0
		telemetry["climb_rung_spacing"]=12.0;telemetry["climb_rung_origin_offset"]=4.0;telemetry["climb_width"]=20.0
		telemetry.grounded=preview_pose=="climb_release"
	if preview_pose.begins_with("wall_"):
		telemetry.grounded=false;telemetry["wall_active"]=preview_pose!="wall_kick"
		telemetry["wall_side"]=preview_facing;telemetry["wall_normal"]=Vector2(-preview_facing,0)
		telemetry["wall_plane_x"]=8.05*preview_facing;telemetry["wall_top_y"]=-100.0;telemetry["wall_bottom_y"]=100.0
		telemetry["wall_relative_travel"]=-phase*24;telemetry["wall_kick_direction"]=-preview_facing
	if preview_pose in ChargeKeys.MODES:
		telemetry.velocity=Vector2.ZERO;telemetry["attack_pose_id"]=ChargeKeys.STEP_ID;telemetry["attack_facing"]=preview_facing;telemetry["charge_progress"]=phase
	if preview_pose in ComboKeys.MODES:
		telemetry.velocity=Vector2.ZERO;telemetry["attack_pose_id"]=preview_pose.get_slice("_",1);telemetry["attack_facing"]=preview_facing
	if preview_pose in ShieldKeys.MODES:
		telemetry.velocity=Vector2.ZERO;telemetry["shield_phase"]=preview_pose.trim_prefix("shield_")
		telemetry["shield_active"]=true;telemetry["shield_facing"]=preview_facing;telemetry["shield_parry_open"]=preview_pose=="shield_parry"
	_pose=Pose.evaluate(preview_pose,phase,telemetry)
	queue_redraw()

func _draw() -> void:
	if _pose.is_empty():return
	var j:Dictionary=_pose.bones
	var front:=Color(0.89,0.96,0.96)
	var rear:=Color(0.43,0.59,0.64)
	var core:=Color(0.68,0.83,0.86)
	_chain(j,["hip_far","knee_far","ankle_far"],rear,stroke_width*0.82)
	_chain(j,["shoulder_far","elbow_far","palm_far"],rear,stroke_width*0.82)
	_foot(j,"far",rear,stroke_width*1.35)
	_palm(j,"far",rear)
	_chain(j,["shoulder_far","rib_far","waist_far","hip_far","hip_near","waist_near","rib_near","shoulder_near","shoulder_far"],core,stroke_width*0.85)
	_chain(j,["pelvis","chest","neck"],core,stroke_width*0.7)
	_chain(j,["hip_near","knee_near","ankle_near"],front,stroke_width)
	_chain(j,["shoulder_near","elbow_near","palm_near"],front,stroke_width)
	_foot(j,"near",front,stroke_width*1.5)
	_palm(j,"near",front)
	for bone in ["knee_near","elbow_near"]:draw_circle(j[bone],stroke_width*0.66,front,true,-1,true)
	var outline:=PackedVector2Array()
	var angle:=deg_to_rad(float(_pose.head_tilt))
	var head_scale:Vector2=_pose.head_scale
	var facing:float=_pose.facing
	for offset in [Vector2(-2.1,-2.0),Vector2(0.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-0.25),Vector2(3.2,0.55),Vector2(1.6,1.1),Vector2(0.7,2.5),Vector2(-1.8,2.0),Vector2(-2.5,0.5),Vector2(-2.1,-2.0)]:
		var point:Vector2=(offset*head_scale).rotated(angle)
		point.x*=facing
		outline.append(Vector2(j.head)+point)
	draw_polyline(outline,front,stroke_width,true)
	var brow:Vector2=Vector2(1.0,-0.4).rotated(angle)
	brow.x*=facing
	draw_line(j.head,Vector2(j.head)+brow,front,stroke_width*0.8,true)
	_draw_weapon()
	_draw_shield()
	if show_contact_marks:
		for i in 2:
			var side:="near" if i==0 else "far"
			if _pose.planted_feet[i]:draw_circle(j["sole_"+side],1.3,Color(0.42,0.96,0.71))
			if _pose.planted_hands[i]:draw_circle(j["palm_"+side],1.3,Color(0.97,0.75,0.4))

func _draw_shield() -> void:
	var shield:Dictionary=_pose.get("shield",{})
	if not bool(shield.get("visible",false)):return
	var ink:=Color(0.76,0.91,0.96) if not bool(shield.parry_open) else Color(0.91,1.0,0.88)
	for segment in shield.visible_segments:draw_line(segment[0],segment[1],ink,stroke_width,true)
	var normal:Vector2=shield.normal;var tangent:=Vector2(-normal.y,normal.x)
	var grip:Vector2=shield.grip
	draw_line(grip-tangent*1.5,grip+tangent*1.5,ink,stroke_width*1.3,true)
	# The forearm strap is separate from the code-native shield's reported band.
	draw_line(_pose.bones.elbow_near,grip,ink,stroke_width*1.5,true)
	for marker in shield.feedback:
		var point:Vector2=marker.point;var outward:Vector2=marker.normal
		var across:=Vector2(-outward.y,outward.x)
		match str(marker.kind):
			"guarded":draw_line(point-across*2,point+across*2,Color(0.96,0.75,0.44),stroke_width*1.3,true)
			"parried":
				for angle in [-0.65,0.0,0.65]:
					var ray:=outward.rotated(angle);draw_line(point+ray,point+ray*3.5,Color(0.82,1,0.89),stroke_width,true)
			"counter":
				draw_line(point+across*3,point+outward*4+across*3,Color(1,0.88,0.62),stroke_width,true)
				draw_line(point+outward*4+across*3,point+outward*2+across*1.5,Color(1,0.88,0.62),stroke_width,true)
			"reflect":
				draw_polyline(PackedVector2Array([point-outward*2-across*3,point,point+outward*4-across*3]),Color(0.66,0.91,1),stroke_width,true)

func _draw_weapon() -> void:
	var weapon:Dictionary=_pose.get("weapon",{})
	if not bool(weapon.get("visible",false)):return
	var color:=Color(0.98,0.92,0.72) if bool(weapon.get("contact",false)) else Color(0.73,0.84,0.86)
	draw_line(weapon.pommel,weapon.grip,color,stroke_width*1.5,true)
	draw_line(weapon.guard_a,weapon.guard_b,color,stroke_width*1.25,true)
	if weapon.has("visible_blade_segments"):
		for segment in weapon.visible_blade_segments:draw_line(segment[0],segment[1],color,stroke_width*0.85,true)
	else:draw_polyline(PackedVector2Array([weapon.blade_a,weapon.tip,weapon.blade_b,weapon.blade_a]),color,stroke_width*0.85,true)
	if bool(weapon.get("confirmed",false)):
		var tip:Vector2=weapon.get("contact_point",weapon.tip)
		for angle in [-0.8,0.0,0.8]:
			var direction:=Vector2(float(weapon.get("contact_facing",_pose.facing)),0).rotated(angle)
			draw_line(tip+direction*2,tip+direction*5,Color(1.0,0.82,0.48),stroke_width,true)

func _chain(j:Dictionary,names:Array,color:Color,width:float) -> void:
	for i in range(names.size()-1):draw_line(j[names[i]],j[names[i+1]],color,width,true)

func _foot(j:Dictionary,side:String,color:Color,width:float) -> void:
	draw_line(j["heel_"+side],j["toe_"+side],color,width,true)
	draw_line(j["ankle_"+side],j["heel_"+side],color,stroke_width*0.8,true)
	draw_line(j["ankle_"+side],j["toe_"+side],color,stroke_width*0.8,true)

func _palm(j:Dictionary,side:String,color:Color) -> void:
	var palm:Vector2=j["palm_"+side]
	var side_index:=0 if side=="near" else 1
	if bool(_pose.get("wall_support",false)) and bool(_pose.wall_touch_hands[side_index]):
		draw_line(palm+Vector2(0,-1.1),palm+Vector2(0,1.1),color,stroke_width*1.2,true)
		draw_line(palm+Vector2(0,-1.1),palm+Vector2(_pose.wall_normal),color,stroke_width*0.8,true)
		return
	if (bool(_pose.ledge_support) or bool(_pose.get("climb_support",false))) and bool(_pose.planted_hands[side_index]):
		var facing:float=_pose.facing
		draw_line(palm+Vector2(-1.1*facing,0),palm+Vector2(1.1*facing,0),color,stroke_width*1.2,true)
		draw_line(palm+Vector2(-1.1*facing,0),palm+Vector2(0,-1.0),color,stroke_width*0.8,true)
		return
	var direction:Vector2=(palm-Vector2(j["elbow_"+side])).normalized()
	var across:=Vector2(-direction.y,direction.x)
	draw_line(palm-across*0.9,palm+across*0.9,color,stroke_width*1.2,true)
	draw_line(palm+across*0.9,palm+direction*1.7+across*0.65,color,stroke_width*0.8,true)
