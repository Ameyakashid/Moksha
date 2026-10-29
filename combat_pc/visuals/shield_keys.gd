@tool
class_name MokshaShieldKeys
extends RefCounted
## Original MOKSHA guard art. Motor phases own all gameplay time and permissions.
const MODES=["shield_raise","shield_parry","shield_hold","shield_miss_recovery","shield_success_recovery","shield_release_recovery"]
const FEEDBACK_SECONDS=0.10 # Actor-local presentation lifetime, not a defense window.
const POSES={
	"fold":{"pelvis":Vector2(-1,-15.2),"lean":3.0,"torso":8.5,"head_tilt":7.0,"rib_width":6.1,"feet":[Vector2(4,0),Vector2(-4,0)],"hands":[Vector2(7,-17),Vector2(-4,-21)],"feet_on":[true,true],"grip_height":0.12},
	"present":{"pelvis":Vector2(-0.4,-15.8),"lean":17.0,"torso":8.8,"head_tilt":-6.0,"rib_width":5.8,"feet":[Vector2(5,0),Vector2(-5,0)],"hands":[Vector2(9,-20),Vector2(1,-23)],"feet_on":[true,true],"grip_height":-0.03},
	"brace":{"pelvis":Vector2(-1.1,-15.1),"lean":8.0,"torso":8.6,"head_tilt":2.0,"rib_width":6.2,"feet":[Vector2(4.5,0),Vector2(-5.5,0)],"hands":[Vector2(8,-19),Vector2(2,-24)],"feet_on":[true,true],"grip_height":0.03},
	"miss":{"pelvis":Vector2(-0.2,-14.7),"lean":23.0,"torso":8.4,"head_tilt":8.0,"rib_width":6.0,"feet":[Vector2(5,0),Vector2(-5,0)],"hands":[Vector2(8,-16),Vector2(-3,-22)],"feet_on":[true,true],"grip_height":0.15},
	"deflect":{"pelvis":Vector2(-1.5,-14.6),"lean":-8.0,"torso":8.5,"head_tilt":12.0,"rib_width":6.4,"feet":[Vector2(5.5,0),Vector2(-5.5,0)],"hands":[Vector2(8,-21),Vector2(2,-24)],"feet_on":[true,true],"grip_height":-0.10},
	"lower":{"pelvis":Vector2(-0.4,-16.2),"lean":4.0,"torso":8.8,"head_tilt":-2.0,"rib_width":5.8,"feet":[Vector2(3.5,0),Vector2(-3.5,0)],"hands":[Vector2(7,-15),Vector2(-3,-18)],"feet_on":[true,true],"grip_height":0.10},
}
const TIMELINES={
	"shield_raise":[[0.0,"fold","hold"],[0.20,"fold","smooth"],[1.0,"present","hold"]],
	"shield_parry":[[0.0,"present","hold"],[0.68,"present","smooth"],[1.0,"brace","hold"]],
	"shield_hold":[[0.0,"brace","hold"],[1.0,"brace","hold"]],
	"shield_miss_recovery":[[0.0,"brace","smooth"],[0.24,"miss","hold"],[0.48,"miss","smooth"],[1.0,"lower","hold"]],
	"shield_success_recovery":[[0.0,"deflect","hold"],[0.42,"deflect","smooth"],[1.0,"lower","hold"]],
	"shield_release_recovery":[[0.0,"brace","smooth"],[1.0,"lower","hold"]],
}
