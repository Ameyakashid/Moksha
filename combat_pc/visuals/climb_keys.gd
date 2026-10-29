@tool
class_name MokshaClimbKeys
extends RefCounted
## Original MOKSHA ladder/vine art. Rung geometry is supplied by the motor;
## none of these pose values or visual release timings are recovered source data.
const MODES=["climb_align","climb_idle","climb_ascend","climb_descend","climb_top_exit","climb_blocked","climb_release"]
const RELEASE_SECONDS=0.10
const TUNING={"hand_center":-24.0,"low_hand_center":-12.0,"foot_center":-12.0,"grip_fraction":0.5,"hand_width":4.2,"foot_width":3.5,"vine_hand_width":0.9,"vine_foot_width":1.8,"hand_swing":2.6,"foot_swing":3.6}
const BODY={
	"climb_align":{"pelvis":Vector2(-1,-14),"lean":17.0,"torso":8.6,"head_tilt":-9.0,"rib_width":5.8},
	"climb_idle":{"pelvis":Vector2(0,-15),"lean":5.0,"torso":8.8,"head_tilt":-3.0,"rib_width":5.8},
	"climb_ascend":{"pelvis":Vector2(-0.3,-14.6),"lean":10.0,"torso":8.8,"head_tilt":-13.0,"rib_width":5.5},
	"climb_descend":{"pelvis":Vector2(0.2,-14.6),"lean":-3.0,"torso":8.6,"head_tilt":14.0,"rib_width":5.9},
	"climb_top_exit":{"pelvis":Vector2(-0.5,-14.5),"lean":12.0,"torso":8.8,"head_tilt":-8.0,"rib_width":5.7},
	"climb_blocked":{"pelvis":Vector2(-0.5,-14.4),"lean":14.0,"torso":8.5,"head_tilt":-4.0,"rib_width":6.1},
}
