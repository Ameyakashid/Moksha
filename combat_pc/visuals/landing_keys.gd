@tool
class_name MokshaLandingKeys
extends RefCounted
## Original MOKSHA hard-contact art. No Dead Cells frames or timing recovered.
## All phases use motor progress; these keys never define recovery duration.
const MODES=["hard_land_impact","hard_land_recovery"]
const POSES={
	"ordinary_contact":{"pelvis":Vector2(-1.4,-5.3),"lean":19.0,"torso":6.6,"head_tilt":10.0,"rib_width":6.7,"feet":[Vector2(5.5,0),Vector2(-5.5,0)],"hands":[Vector2(5.5,-11.2),Vector2(-5.8,-10)],"feet_on":[true,true]},
	"ordinary_gather":{"pelvis":Vector2(-1.4,-5.8),"lean":29.0,"torso":6.6,"head_tilt":-3.0,"rib_width":6.6,"feet":[Vector2(5.5,0),Vector2(-5.5,0)],"hands":[Vector2(6.5,-9),Vector2(-4,-11)],"feet_on":[true,true]},
	"dive_contact":{"pelvis":Vector2(-0.7,-4.2),"lean":57.0,"torso":6.7,"head_tilt":-24.0,"rib_width":6.8,"feet":[Vector2(6,0),Vector2(-5,0)],"hands":[Vector2(8,-3.8),Vector2(-3.5,-8.5)],"feet_on":[true,true]},
	"dive_gather":{"pelvis":Vector2(-1.0,-5.4),"lean":45.0,"torso":6.5,"head_tilt":-18.0,"rib_width":6.7,"feet":[Vector2(6,0),Vector2(-5,0)],"hands":[Vector2(7.5,-6.5),Vector2(-3,-10)],"feet_on":[true,true]},
	"compact_ready":{"pelvis":Vector2(-1,-6.1),"lean":38.0,"torso":6.6,"head_tilt":-18.0,"rib_width":6.5,"feet":[Vector2(5,0),Vector2(-4,0)],"hands":[Vector2(7,-7),Vector2(-2,-10)],"feet_on":[true,true]},
}
# Contact stays held throughout impact and through the first12% of recovery.
# The body gathers by58%, then unfolds only as far as the20px clearance allows.
const RECOVERY=[[0.0,"contact","hold"],[0.12,"contact","smooth"],[0.58,"gather","smooth"],[1.0,"compact_ready","hold"]]
