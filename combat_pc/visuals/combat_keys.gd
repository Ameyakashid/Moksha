@tool
class_name MokshaCombatKeys
extends RefCounted
## Original MOKSHA combat pose art. These are normalized authoring keys, not
## recovered Dead Cells sprite data, hit windows, or duration constants.
const WEAPON := {"length":18.0,"width":1.15,"grip":3.0,"guard":2.2}
const IMPACT_TIME := 0.07
const POSES := {
	"roll_load":{"pelvis":Vector2(-1,-6.1),"lean":38.0,"torso":6.6,"head_tilt":-18.0,"rib_width":6.5,"feet":[Vector2(5,0),Vector2(-4,0)],"hands":[Vector2(7,-7),Vector2(-2,-10)],"feet_on":[true,true],"leg_bend":[1.0,-1.0]},
	"roll_tuck":{"pelvis":Vector2(-3,-7),"lean":55.0,"torso":5.4,"head_tilt":22.0,"rib_width":5.2,"feet":[Vector2(4,-5),Vector2(-1,-14)],"hands":[Vector2(6,-8),Vector2(2,-4)],"feet_on":[false,false],"leg_bend":[1.0,-1.0]},
	"roll_exit":{"pelvis":Vector2(0.7,-6.2),"lean":39.0,"torso":6.3,"head_tilt":-16.0,"rib_width":6.3,"feet":[Vector2(6,0),Vector2(-5,-2)],"hands":[Vector2(8,-7),Vector2(-3,-10)],"feet_on":[true,false],"leg_bend":[1.0,-1.0]},
	"weapon_ready":{"pelvis":Vector2(0,-16),"lean":5.0,"torso":8.8,"head_tilt":-2.0,"rib_width":5.9,"feet":[Vector2(5,0),Vector2(-4,0)],"hands":[Vector2(6,-22),Vector2(-4,-20)],"feet_on":[true,true],"weapon_angle":-40.0},
	"weapon_load":{"pelvis":Vector2(-1,-14.8),"lean":-14.0,"torso":9.0,"head_tilt":7.0,"rib_width":6.2,"feet":[Vector2(6,0),Vector2(-5,0)],"hands":[Vector2(-5,-28),Vector2(-7,-21)],"feet_on":[true,true],"weapon_angle":-124.0},
	"weapon_contact":{"pelvis":Vector2(1,-13),"lean":22.0,"torso":9.0,"head_tilt":-7.0,"rib_width":5.4,"feet":[Vector2(8,0),Vector2(-7,0)],"hands":[Vector2(14,-19),Vector2(-3,-25)],"feet_on":[true,true],"weapon_angle":-5.0},
	"weapon_follow":{"pelvis":Vector2(2,-12.8),"lean":27.0,"torso":8.8,"head_tilt":-8.0,"rib_width":5.7,"feet":[Vector2(8,0),Vector2(-6,0)],"hands":[Vector2(11,-15),Vector2(-2,-23)],"feet_on":[true,true],"weapon_angle":24.0},
	"hurt_recoil":{"pelvis":Vector2(-1,-13.5),"lean":-25.0,"torso":8.5,"head_tilt":19.0,"rib_width":6.1,"feet":[Vector2(5,0),Vector2(-6,-1)],"hands":[Vector2(3,-21),Vector2(-9,-25)],"feet_on":[false,false]},
	"hurt_guard":{"pelvis":Vector2(-0.6,-12),"lean":12.0,"torso":8.2,"head_tilt":-9.0,"rib_width":6.5,"feet":[Vector2(5,0),Vector2(-5,0)],"hands":[Vector2(7,-22),Vector2(4,-24)],"feet_on":[true,true]},
}
const TIMELINES := {
	"roll_start":[[0.0,"roll_load","hold"],[0.22,"roll_load","snap"],[0.70,"roll_tuck","hold"],[1.0,"roll_tuck","hold"]],
	"roll_recovery":[[0.0,"roll_tuck","smooth"],[0.42,"roll_exit","hold"],[0.65,"roll_exit","smooth"],[1.0,"roll_load","hold"]],
	"attack_windup":[[0.0,"weapon_ready","smooth"],[0.55,"weapon_load","hold"],[1.0,"weapon_load","hold"]],
	"attack_active":[[0.0,"weapon_contact","hold"],[0.66,"weapon_contact","smooth"],[1.0,"weapon_follow","hold"]],
	"attack_recovery":[[0.0,"weapon_follow","hold"],[0.18,"weapon_follow","smooth"],[0.78,"weapon_ready","hold"],[1.0,"weapon_ready","hold"]],
	"hurt":[[0.0,"hurt_recoil","hold"],[0.32,"hurt_recoil","smooth"],[0.72,"hurt_guard","smooth"],[1.0,"weapon_ready","hold"]],
}
