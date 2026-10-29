@tool
class_name MokshaDescentKeys
extends RefCounted
## Original MOKSHA drop/dive poses. Motor contact and phase progress own timing.
## The audited reference bodies and original sprite/frame data are unavailable.
const MODES=["drop","dive_startup","dive_descent","dive_impact","dive_recovery"]
const POSES={
	"drop_release":{"pelvis":Vector2(0,-16.2),"lean":7.0,"torso":8.8,"head_tilt":13.0,"rib_width":6.0,"feet":[Vector2(3,0),Vector2(-3,-0.8)],"hands":[Vector2(7,-18),Vector2(-6,-19)],"feet_on":[false,false]},
	"drop_clear":{"pelvis":Vector2(0,-15.5),"lean":9.0,"torso":8.7,"head_tilt":17.0,"rib_width":5.9,"feet":[Vector2(2,0),Vector2(-3,-2)],"hands":[Vector2(8,-18),Vector2(-7,-20)],"feet_on":[false,false]},
	"dive_brace":{"pelvis":Vector2(-0.5,-13),"lean":14.0,"torso":8.6,"head_tilt":8.0,"rib_width":6.3,"feet":[Vector2(5,-6),Vector2(-4,-8)],"hands":[Vector2(5,-24),Vector2(-1,-23)],"feet_on":[false,false]},
	"dive_point":{"pelvis":Vector2(0,-16.8),"lean":4.0,"torso":8.7,"head_tilt":16.0,"rib_width":5.1,"feet":[Vector2(1.5,0),Vector2(-2,-3)],"hands":[Vector2(5,-17),Vector2(-2,-18)],"feet_on":[false,false]},
	"dive_contact":{"pelvis":Vector2(-0.5,-7.8),"lean":45.0,"torso":7.8,"head_tilt":-18.0,"rib_width":6.7,"feet":[Vector2(6,0),Vector2(-5,0)],"hands":[Vector2(8,-7),Vector2(-3,-11)],"feet_on":[true,true]},
	"dive_rebound":{"pelvis":Vector2(0,-11.5),"lean":23.0,"torso":8.4,"head_tilt":-7.0,"rib_width":6.1,"feet":[Vector2(5,0),Vector2(-5,0)],"hands":[Vector2(8,-15),Vector2(-4,-19)],"feet_on":[true,true]},
	"dive_ready":{"pelvis":Vector2(0,-17),"lean":0.0,"torso":9.0,"head_tilt":0.0,"rib_width":5.6,"feet":[Vector2(3,0),Vector2(-3,0)],"hands":[Vector2(5.5,-16),Vector2(-4.5,-17)],"feet_on":[true,true]},
}
const LOW_POSES={
	"drop_release":{"pelvis":Vector2(-1,-6.1),"lean":38.0,"torso":6.6,"head_tilt":-9.0,"rib_width":6.5,"feet":[Vector2(4,0),Vector2(-4,-0.5)],"hands":[Vector2(7,-7),Vector2(-2,-10)],"feet_on":[false,false]},
	"drop_clear":{"pelvis":Vector2(-0.5,-6.2),"lean":38.0,"torso":6.5,"head_tilt":-5.0,"rib_width":6.2,"feet":[Vector2(2,0),Vector2(-3,-1)],"hands":[Vector2(8,-7),Vector2(-3,-10)],"feet_on":[false,false]},
	"dive_brace":{"pelvis":Vector2(-0.5,-6),"lean":40.0,"torso":6.2,"head_tilt":-12.0,"rib_width":6.3,"feet":[Vector2(3,-1),Vector2(-3,-3)],"hands":[Vector2(8,-12),Vector2(1,-13)],"feet_on":[false,false]},
	"dive_point":{"pelvis":Vector2(0,-6.4),"lean":37.0,"torso":6.2,"head_tilt":-4.0,"rib_width":5.8,"feet":[Vector2(1.5,0),Vector2(-2,-2)],"hands":[Vector2(6,-5),Vector2(0,-8)],"feet_on":[false,false]},
	"dive_contact":{"pelvis":Vector2(-0.5,-5),"lean":47.0,"torso":6.3,"head_tilt":-20.0,"rib_width":6.7,"feet":[Vector2(5,0),Vector2(-5,0)],"hands":[Vector2(8,-5),Vector2(-3,-9)],"feet_on":[true,true]},
	"dive_rebound":{"pelvis":Vector2(-0.5,-5.7),"lean":42.0,"torso":6.3,"head_tilt":-17.0,"rib_width":6.5,"feet":[Vector2(5,0),Vector2(-4,0)],"hands":[Vector2(8,-7),Vector2(-3,-10)],"feet_on":[true,true]},
	"dive_ready":{"pelvis":Vector2(-1,-6.1),"lean":38.0,"torso":6.6,"head_tilt":-18.0,"rib_width":6.5,"feet":[Vector2(5,0),Vector2(-4,0)],"hands":[Vector2(7,-7),Vector2(-2,-10)],"feet_on":[true,true]},
}
const TIMELINES={
	"drop":[[0.0,"drop_release","hold"],[0.30,"drop_release","smooth"],[1.0,"drop_clear","hold"]],
	"dive_startup":[[0.0,"dive_brace","hold"],[0.62,"dive_brace","snap"],[0.88,"dive_point","hold"],[1.0,"dive_point","hold"]],
	"dive_descent":[[0.0,"dive_point","hold"],[1.0,"dive_point","hold"]],
	"dive_impact":[[0.0,"dive_contact","hold"],[1.0,"dive_contact","hold"]],
	"dive_recovery":[[0.0,"dive_contact","hold"],[0.12,"dive_contact","smooth"],[0.48,"dive_rebound","smooth"],[1.0,"dive_ready","hold"]],
}
