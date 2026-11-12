extends RefCounted
## Optional presentation-only camera rig. Never moves actors or changes input.
## A small vertical window lets short jumps play inside the frame; look-ahead
## changes smoothly rather than teleporting the view when direction reverses.
const VIEW_HALF := Vector2(320,180)
const LOOKAHEAD_SECONDS := 0.13
const LOOKAHEAD_LIMIT := 30.0
const LOOKAHEAD_RATE := 150.0
const HORIZONTAL_RESPONSE := 12.0
const VERTICAL_RESPONSE := 12.0
const FOOT_TOP := -18.0
const FOOT_BOTTOM := 112.0
const FOOT_SAFE_TOP := -136.0
const FOOT_SAFE_BOTTOM := 140.0
# Original motion-driven tuning hypotheses, not borrowed SuperTux constants.
const FALL_DISTANCE := 160.0
const FALL_ENTER_SPEED := 220.0
const FALL_EXIT_SPEED := 80.0
const FALL_HOLD := 0.10
const FALL_LIMIT := 96.0
const FALL_SECONDS := 0.18
const FALL_ENTER_RATE := 480.0
const FALL_RETURN_RATE := 360.0
const FALL_FOOT_MIN_Y := 104.0
var fall_bias := 0.0
var fall_origin_y := 0.0
var fall_fast_time := 0.0
var fall_slow_time := 0.0
var fall_armed := false
var output := Vector2(320,180)
# Baseline center never receives the rendered bias or its final bounds clamp.
var center := Vector2(320,180)
var lookahead := 0.0
var initialized := false
var previous_player := Vector2.ZERO

func reset(player_position:Vector2, sector_data:Dictionary)->Vector2:
	lookahead=0.0
	fall_bias=0.0
	fall_origin_y=player_position.y
	fall_fast_time=0.0
	fall_slow_time=0.0
	fall_armed=false
	center=_bounded(player_position-Vector2(0,105),sector_data)
	previous_player=player_position
	initialized=true
	output=center
	return output

func follow(player_position:Vector2, velocity:Vector2, sector_data:Dictionary, dt:float, grounded:bool=true)->Vector2:
	if not initialized:return reset(player_position,sector_data)
	if dt<=0:return output
	# Scene fixtures and legitimate respawns should not drag the camera across a
	# whole map. Ordinary high-speed falls/rolls remain smoothly tracked.
	if player_position.distance_to(previous_player)>640:
		return reset(player_position,sector_data)
	var descending:=player_position.y>=previous_player.y and velocity.y>0
	previous_player=player_position
	var step:=minf(dt,0.1)
	var look_target:=clampf(velocity.x*LOOKAHEAD_SECONDS,-LOOKAHEAD_LIMIT,LOOKAHEAD_LIMIT)
	lookahead=move_toward(lookahead,look_target,LOOKAHEAD_RATE*step)
	var target:=Vector2(player_position.x+lookahead,center.y)
	var foot_offset:=player_position.y-center.y
	if foot_offset<FOOT_TOP:target.y=player_position.y-FOOT_TOP
	elif foot_offset>FOOT_BOTTOM:target.y=player_position.y-FOOT_BOTTOM
	target=_bounded(target,sector_data)
	center.x=lerpf(center.x,target.x,1.0-exp(-HORIZONTAL_RESPONSE*step))
	center.y=lerpf(center.y,target.y,1.0-exp(-VERTICAL_RESPONSE*step))
	# Fast falls may outrun exponential easing. Keep the body in the safe play
	# area without changing its velocity or allowing a camera overshoot.
	center.y=clampf(center.y,player_position.y-FOOT_SAFE_BOTTOM,player_position.y-FOOT_SAFE_TOP)
	center=_bounded(center,sector_data)
	_update_fall(player_position,velocity,grounded,descending,step)
	var visible_bias:=minf(fall_bias,maxf(0.0,player_position.y-center.y+VIEW_HALF.y-FALL_FOOT_MIN_Y))
	output=_bounded(center+Vector2(0,visible_bias),sector_data)
	return output

func _update_fall(position:Vector2, velocity:Vector2, grounded:bool, descending:bool, step:float)->void:
	if grounded or not descending:
		fall_origin_y=position.y
		fall_fast_time=0.0
		fall_slow_time=0.0
		fall_armed=false
	else:
		fall_fast_time=fall_fast_time+step if velocity.y>FALL_ENTER_SPEED else 0.0
		fall_slow_time=fall_slow_time+step if velocity.y<FALL_EXIT_SPEED else 0.0
		if position.y-fall_origin_y>=FALL_DISTANCE and fall_fast_time+0.000001>=FALL_HOLD:
			fall_armed=true
		if fall_slow_time+0.000001>=FALL_HOLD:fall_armed=false
	var wanted:=clampf(velocity.y*FALL_SECONDS,0,FALL_LIMIT) if fall_armed else 0.0
	fall_bias=move_toward(fall_bias,wanted,(FALL_ENTER_RATE if wanted>fall_bias else FALL_RETURN_RATE)*step)

func _bounded(value:Vector2, sector_data:Dictionary)->Vector2:
	var right:=maxf(VIEW_HALF.x,float(sector_data.get("width",640))-VIEW_HALF.x)
	var top:=minf(VIEW_HALF.y,float(sector_data.get("top",-100))+VIEW_HALF.y)
	return Vector2(clampf(value.x,VIEW_HALF.x,right),clampf(value.y,top,VIEW_HALF.y))
