@tool
class_name MokshaWallKeys
extends RefCounted
## Original MOKSHA wall art. The primary historical clip establishes rise and
## outward departure only; these keys and normalized holds are not recovered frames.
const MODES=["wall_run","wall_slide","wall_kick"]
const TUNING={"stride":24.0,"stance":0.38,"foot_base":-13.0,"foot_skin":0.95,"palm_skin":0.7,"joint_skin":0.8,"foot_recovery":5.5,"knee_lift":4.0}
const RUN={"pelvis":Vector2(-1.3,-14.3),"lean":15.0,"torso":8.8,"head_tilt":-12.0,"rib_width":5.6}
const SLIDE={"pelvis":Vector2(-1.7,-13.8),"lean":-4.0,"torso":8.6,"head_tilt":14.0,"rib_width":6.1}
const KICK={
	"compress":{"pelvis":Vector2(-1,-13),"lean":-10.0,"torso":8.7,"head_tilt":7.0,"rib_width":6.3,"feet":[Vector2(4,-8),Vector2(-5,-4)],"hands":[Vector2(7,-24),Vector2(-5,-20)],"feet_on":[false,false]},
	"push":{"pelvis":Vector2(1,-15.5),"lean":23.0,"torso":9.0,"head_tilt":-9.0,"rib_width":5.4,"feet":[Vector2(6,-8),Vector2(-5.6,-6)],"hands":[Vector2(8,-25),Vector2(-5,-17)],"feet_on":[false,false]},
	"open":{"pelvis":Vector2(0,-16),"lean":12.0,"torso":9.0,"head_tilt":-8.0,"rib_width":5.5,"feet":[Vector2(7,-8),Vector2(-5,-2)],"hands":[Vector2(8,-28),Vector2(-5,-19)],"feet_on":[false,false]},
}
const KICK_KEYS=[[0.0,"compress","hold"],[0.16,"compress","snap"],[0.28,"push","hold"],[0.52,"push","smooth"],[1.0,"open","hold"]]
