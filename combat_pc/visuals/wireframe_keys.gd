@tool
class_name MokshaWireframeKeys
extends RefCounted
## MOKSHA original pose design. These are NOT recovered Dead Cells frame poses or timings.
## Design evidence: Thomas Vasseur's 2018 primary animation article, as classified in
## reference_sources/dead-cells-audit/DEAD_CELLS_MOVEMENT_AUDIT.md: strong keys and deliberate timing.

const METADATA := {
	"art":"Original MOKSHA articulated wireframe",
	"timing":"Original MOKSHA authoring; no original game sprite/frame data recovered",
	"units":"pixels; standing height approximately34; feet plane local y0",
	"physics":"Motor owns roots, collision, Facing and traversal phases",
}
const TUNING := {
	"standing_height":34.0, "upper_leg":8.0, "lower_leg":8.0,
	"upper_arm":6.0, "lower_arm":5.8, "head_radius":Vector2(2.5,2.7),
	"run_reference_speed":260.0, "slow_stride":24.0, "fast_stride":64.0,
	"slow_stance":0.48, "fast_stance":0.28,
	"start_time":0.14, "jump_time":0.12, "air_jump_time":0.16,
	"landing_time":0.18, "brake_time":0.16, "turn_time":0.16,
	"ordinary_blend":0.035, "line_width":1.05,
}
# Feet are sole anchors, not toes. Hands are palm targets. Angles are degrees.
# Keys intentionally favor readable silhouettes over smooth motion everywhere.
const POSES := {
	"ready": {"pelvis":Vector2(0,-17),"lean":0.0,"torso":9.0,"head_tilt":0.0,"rib_width":5.6,"feet":[Vector2(3,0),Vector2(-3,0)],"hands":[Vector2(5.5,-16),Vector2(-4.5,-17)],"feet_on":[true,true]},
	"drive_load": {"pelvis":Vector2(-1.5,-14),"lean":19.0,"torso":8.8,"head_tilt":-3.0,"rib_width":5.9,"feet":[Vector2(5.5,0),Vector2(-5.5,0)],"hands":[Vector2(-2,-20),Vector2(7.5,-24)],"feet_on":[true,true]},
	"drive_push": {"pelvis":Vector2(1,-15),"lean":24.0,"torso":9.0,"head_tilt":-6.0,"rib_width":5.6,"feet":[Vector2(6,-4),Vector2(-8.5,0)],"hands":[Vector2(9,-26),Vector2(-3,-18)],"feet_on":[false,true]},
	"brake_hit": {"pelvis":Vector2(-2,-13),"lean":-18.0,"torso":8.8,"head_tilt":8.0,"rib_width":6.0,"feet":[Vector2(8.2,0),Vector2(-6.8,0)],"hands":[Vector2(3,-21),Vector2(-9,-22)],"feet_on":[true,false]},
	"brake_settle": {"pelvis":Vector2(-0.7,-15.6),"lean":-5.0,"torso":8.8,"head_tilt":3.0,"rib_width":5.7,"feet":[Vector2(4,0),Vector2(-4,0)],"hands":[Vector2(6,-19),Vector2(-6,-19)],"feet_on":[true,true]},
	"turn_load": {"pelvis":Vector2(-2,-13.8),"lean":-9.0,"torso":8.8,"head_tilt":-5.0,"rib_width":6.3,"feet":[Vector2(7,0),Vector2(-7,0)],"hands":[Vector2(7,-22),Vector2(-8,-20)],"feet_on":[true,true]},
	"turn_drive": {"pelvis":Vector2(1,-14.8),"lean":18.0,"torso":8.8,"head_tilt":-4.0,"rib_width":5.7,"feet":[Vector2(5,-3),Vector2(-7,0)],"hands":[Vector2(8,-26),Vector2(-3,-17)],"feet_on":[false,true]},
	"jump_wind": {"pelvis":Vector2(0,-11.8),"lean":22.0,"torso":8.2,"head_tilt":-10.0,"rib_width":6.6,"feet":[Vector2(4,-1),Vector2(-4,-1)],"hands":[Vector2(-3,-17),Vector2(-6,-18)],"feet_on":[false,false]},
	"jump_push": {"pelvis":Vector2(0,-16.2),"lean":8.0,"torso":9.2,"head_tilt":-12.0,"rib_width":5.1,"feet":[Vector2(5,-5),Vector2(-3,-1)],"hands":[Vector2(6,-31),Vector2(-5,-23)],"feet_on":[false,false]},
	"rise": {"pelvis":Vector2(0,-16),"lean":12.0,"torso":9.0,"head_tilt":-8.0,"rib_width":5.5,"feet":[Vector2(7,-8),Vector2(-5,-2)],"hands":[Vector2(8,-28),Vector2(-5,-19)],"feet_on":[false,false]},
	"air_fold": {"pelvis":Vector2(-1,-15),"lean":-18.0,"torso":8.2,"head_tilt":12.0,"rib_width":6.2,"feet":[Vector2(7,-10),Vector2(-4,-9)],"hands":[Vector2(4,-27),Vector2(-9,-25)],"feet_on":[false,false]},
	"air_snap": {"pelvis":Vector2(0,-16.5),"lean":-3.0,"torso":9.4,"head_tilt":-10.0,"rib_width":5.0,"feet":[Vector2(2,-9),Vector2(-6,-5)],"hands":[Vector2(7,-19),Vector2(-5,-18)],"feet_on":[false,false]},
	"air_open": {"pelvis":Vector2(0,-16),"lean":8.0,"torso":9.0,"head_tilt":-8.0,"rib_width":5.7,"feet":[Vector2(6,-6),Vector2(-5,-3)],"hands":[Vector2(8,-27),Vector2(-7,-23)],"feet_on":[false,false]},
	"apex": {"pelvis":Vector2(0,-16),"lean":3.0,"torso":8.9,"head_tilt":1.0,"rib_width":6.0,"feet":[Vector2(5,-5),Vector2(-4,-4)],"hands":[Vector2(9,-24),Vector2(-8,-25)],"feet_on":[false,false]},
	"fall": {"pelvis":Vector2(0,-16.0),"lean":5.0,"torso":8.9,"head_tilt":12.0,"rib_width":5.8,"feet":[Vector2(4,-1.2),Vector2(-4,-2.5)],"hands":[Vector2(8,-23),Vector2(-7,-24)],"feet_on":[false,false]},
	"impact": {"pelvis":Vector2(0,-10.5),"lean":28.0,"torso":7.8,"head_tilt":-7.0,"rib_width":6.8,"feet":[Vector2(5,0),Vector2(-5,0)],"hands":[Vector2(8,-13),Vector2(-3,-14)],"feet_on":[true,true]},
	"land_recover": {"pelvis":Vector2(0,-15.2),"lean":7.0,"torso":8.8,"head_tilt":-2.0,"rib_width":5.9,"feet":[Vector2(4,0),Vector2(-4,0)],"hands":[Vector2(7,-18),Vector2(-5,-20)],"feet_on":[true,true]},
	"land_drive": {"pelvis":Vector2(0.8,-13.2),"lean":25.0,"torso":8.5,"head_tilt":-7.0,"rib_width":5.9,"feet":[Vector2(6,-3),Vector2(-6,0)],"hands":[Vector2(8,-25),Vector2(-3,-16)],"feet_on":[false,true]},
	"crouch": {"pelvis":Vector2(-1,-6.1),"lean":38.0,"torso":6.6,"head_tilt":-18.0,"rib_width":6.5,"feet":[Vector2(5,0),Vector2(-4,0)],"hands":[Vector2(7,-7),Vector2(-2,-10)],"feet_on":[true,true]},
	"ledge_load": {"pelvis":Vector2(1,-11.5),"lean":8.0,"torso":8.6,"head_tilt":-22.0,"rib_width":5.8,"feet":[Vector2(3,-1),Vector2(-3,-3)],"hands":[Vector2(9,-30),Vector2(6,-30)],"feet_on":[false,false]},
	"ledge_over": {"pelvis":Vector2(-1,-6.0),"lean":57.0,"torso":8.2,"head_tilt":-25.0,"rib_width":6.2,"feet":[Vector2(10,-2),Vector2(-7,-4)],"hands":[Vector2(9,0),Vector2(0,-10)],"feet_on":[false,false]},
	"ledge_plant": {"pelvis":Vector2(-0.5,-7.5),"lean":42.0,"torso":8.0,"head_tilt":-17.0,"rib_width":6.0,"feet":[Vector2(7,0),Vector2(-5,-4)],"hands":[Vector2(3,-4),Vector2(-4,-13)],"feet_on":[true,false]},
	"ledge_settle": {"pelvis":Vector2(0,-15.5),"lean":8.0,"torso":8.7,"head_tilt":-3.0,"rib_width":5.8,"feet":[Vector2(3,0),Vector2(-3,0)],"hands":[Vector2(6,-19),Vector2(-5,-21)],"feet_on":[true,true]},
}
# A key can HOLD to preserve an impact silhouette. Ease only surrounds the held key.
# Times are normalized within an original authored transient. Physical ledge phases
# instead use motor progress and are not assigned a guessed gameplay duration.
const TIMELINES := {
	"start":[[0.0,"drive_load","hold"],[0.25,"drive_load","smooth"],[0.55,"drive_push","hold"],[0.72,"drive_push","smooth"],[1.0,"rise","smooth"]],
	"jump":[[0.0,"jump_wind","hold"],[0.20,"jump_wind","snap"],[0.35,"jump_push","hold"],[0.53,"jump_push","smooth"],[1.0,"rise","smooth"]],
	"air_jump":[[0.0,"air_fold","hold"],[0.16,"air_fold","snap"],[0.25,"air_snap","hold"],[0.49,"air_snap","smooth"],[1.0,"air_open","smooth"]],
	"brake":[[0.0,"brake_hit","hold"],[0.30,"brake_hit","smooth"],[0.80,"brake_settle","hold"],[1.0,"brake_settle","smooth"]],
	"turn":[[0.0,"turn_load","hold"],[0.22,"turn_load","snap"],[0.40,"turn_drive","hold"],[0.63,"turn_drive","smooth"],[1.0,"drive_push","smooth"]],
	"land":[[0.0,"impact","hold"],[0.24,"impact","smooth"],[0.75,"land_recover","smooth"],[1.0,"ready","smooth"]],
	"land_run":[[0.0,"impact","hold"],[0.17,"impact","snap"],[0.36,"land_drive","hold"],[0.55,"land_drive","smooth"],[1.0,"drive_push","smooth"]],
	"ledge_step":[[0.0,"ledge_over","hold"],[0.20,"ledge_over","smooth"],[0.47,"ledge_plant","hold"],[0.62,"ledge_plant","smooth"],[1.0,"ledge_settle","smooth"]],
}
const GROUND_CYCLE := [
	[0.00,0.0,0.0,"contact"],[0.08,1.1,3.0,"weight"],[0.24,-0.2,0.0,"pass"],
	[0.40,-1.0,-2.0,"flight"],[0.50,0.0,0.0,"contact"],[0.58,1.1,3.0,"weight"],
	[0.74,-0.2,0.0,"pass"],[0.90,-1.0,-2.0,"flight"],[1.00,0.0,0.0,"contact"],
]
