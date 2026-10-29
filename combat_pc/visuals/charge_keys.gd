@tool
class_name MokshaChargeKeys
extends RefCounted
## Original MOKSHA held-charge/thrust art. These normalized keys are not gameplay
## timers, a recovered reference track, or an instruction to move the actor.
const STEP_ID="charged_thrust"
const STRIKE_MODES=["attack_charged_thrust_windup","attack_charged_thrust_active","attack_charged_thrust_recovery"]
const MODES=["attack_charge","attack_charged_thrust_windup","attack_charged_thrust_active","attack_charged_thrust_recovery"]
const ENTRY_BLEND_END=0.16
const POSES={
 "gather":{"pelvis":Vector2(-1,-13),"lean":-8.0,"torso":8.8,"head_tilt":4.0,"rib_width":6.2,"feet":[Vector2(5,0),Vector2(-5,0)],"hands":[Vector2(6,-22),Vector2(-2,-22)],"feet_on":[true,true],"weapon_angle":-5.0},
 "brace":{"pelvis":Vector2(-1.6,-12),"lean":-12.0,"torso":8.9,"head_tilt":6.0,"rib_width":6.5,"feet":[Vector2(7,0),Vector2(-7,0)],"hands":[Vector2(2,-21.5),Vector2(-1,-20)],"feet_on":[true,true],"weapon_angle":0.0},
 "loaded":{"pelvis":Vector2(-2,-11.6),"lean":-15.0,"torso":8.8,"head_tilt":7.0,"rib_width":6.7,"feet":[Vector2(7.5,0),Vector2(-7,0)],"hands":[Vector2(.5,-21.6),Vector2(-2,-20)],"feet_on":[true,true],"weapon_angle":0.0},
 "set":{"pelvis":Vector2(-1,-12.5),"lean":-4.0,"torso":8.9,"head_tilt":2.0,"rib_width":6.3,"feet":[Vector2(7,0),Vector2(-6,0)],"hands":[Vector2(5,-21),Vector2(-2,-22)],"feet_on":[true,true],"weapon_angle":0.0},
 "contact":{"pelvis":Vector2(2.3,-11.8),"lean":33.0,"torso":9.0,"head_tilt":-10.0,"rib_width":5.4,"feet":[Vector2(9,0),Vector2(-7,-2.5)],"hands":[Vector2(18,-18),Vector2(-1,-24)],"feet_on":[true,false],"weapon_angle":0.0},
 "follow":{"pelvis":Vector2(2.8,-11.7),"lean":27.0,"torso":8.8,"head_tilt":-8.0,"rib_width":5.8,"feet":[Vector2(8,-2),Vector2(-6,0)],"hands":[Vector2(15,-16),Vector2(-1,-22)],"feet_on":[false,true],"weapon_angle":3.0},
 "ready":{"pelvis":Vector2(0,-15),"lean":5.0,"torso":8.8,"head_tilt":-2.0,"rib_width":5.9,"feet":[Vector2(5,0),Vector2(-4,0)],"hands":[Vector2(6,-21),Vector2(-4,-20)],"feet_on":[true,true],"weapon_angle":-8.0}
}
const TIMELINES={
 "charge":[[0.0,"gather","smooth"],[0.35,"brace","smooth"],[0.82,"loaded","hold"],[1.0,"loaded","hold"]],
 "windup":[[0.0,"loaded","hold"],[0.55,"loaded","smooth"],[1.0,"set","hold"]],
 "active":[[0.0,"contact","hold"],[0.56,"contact","smooth"],[1.0,"follow","hold"]],
 "recovery":[[0.0,"follow","hold"],[0.18,"follow","smooth"],[0.65,"gather","smooth"],[1.0,"ready","hold"]]
}
