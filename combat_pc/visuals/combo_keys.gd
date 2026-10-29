@tool
class_name MokshaComboKeys
extends RefCounted
## MOKSHA original light-chain authoring. Normalized keys, never gameplay clocks.
## Slash reuses our accepted M2 first swing; backhand/finisher are new original art.
const STEP_IDS=["slash","backhand","finisher"]
const PHASES=["windup","active","recovery"]
const MODES=["attack_slash_windup","attack_slash_active","attack_slash_recovery","attack_backhand_windup","attack_backhand_active","attack_backhand_recovery","attack_finisher_windup","attack_finisher_active","attack_finisher_recovery"]
const ENTRY_BLEND_END=0.45
const POSES={
 "backhand_load":{"pelvis":Vector2(-0.8,-14.0),"lean":20.0,"torso":8.8,"head_tilt":-8.0,"rib_width":5.3,"feet":[Vector2(6,0),Vector2(-5,0)],"hands":[Vector2(-3,-18),Vector2(6,-26)],"feet_on":[true,true],"weapon_angle":152.0},
 "backhand_contact":{"pelvis":Vector2(0.5,-14.0),"lean":-7.0,"torso":8.8,"head_tilt":4.0,"rib_width":6.3,"feet":[Vector2(7,0),Vector2(-5,0)],"hands":[Vector2(10.5,-25),Vector2(-8,-20)],"feet_on":[true,true],"weapon_angle":-12.0},
 "backhand_follow":{"pelvis":Vector2(0,-14.2),"lean":-12.0,"torso":8.7,"head_tilt":6.0,"rib_width":6.1,"feet":[Vector2(6,0),Vector2(-5,0)],"hands":[Vector2(7,-28),Vector2(-7,-18)],"feet_on":[true,true],"weapon_angle":-40.0},
 "finisher_load":{"pelvis":Vector2(-1.0,-13.2),"lean":-5.0,"torso":8.8,"head_tilt":5.0,"rib_width":6.4,"feet":[Vector2(7,0),Vector2(-6,0)],"hands":[Vector2(2,-31),Vector2(-4,-28)],"feet_on":[true,true],"weapon_angle":-102.0},
 "finisher_contact":{"pelvis":Vector2(1.6,-11.5),"lean":29.0,"torso":8.8,"head_tilt":-12.0,"rib_width":5.5,"feet":[Vector2(8,0),Vector2(-7,0)],"hands":[Vector2(12,-17.5),Vector2(6,-23)],"feet_on":[true,true],"weapon_angle":18.0},
 "finisher_follow":{"pelvis":Vector2(2,-11.2),"lean":35.0,"torso":8.6,"head_tilt":-13.0,"rib_width":5.6,"feet":[Vector2(8,0),Vector2(-6,0)],"hands":[Vector2(10,-13),Vector2(5,-21)],"feet_on":[true,true],"weapon_angle":31.0}
}
const TIMELINES={
 "backhand_windup":[[0.0,"weapon_ready","smooth"],[0.52,"backhand_load","hold"],[1.0,"backhand_load","hold"]],
 "backhand_active":[[0.0,"backhand_contact","hold"],[0.62,"backhand_contact","smooth"],[1.0,"backhand_follow","hold"]],
 "backhand_recovery":[[0.0,"backhand_follow","hold"],[0.20,"backhand_follow","smooth"],[0.82,"weapon_ready","hold"],[1.0,"weapon_ready","hold"]],
 "finisher_windup":[[0.0,"weapon_ready","smooth"],[0.58,"finisher_load","hold"],[1.0,"finisher_load","hold"]],
 "finisher_active":[[0.0,"finisher_contact","hold"],[0.72,"finisher_contact","smooth"],[1.0,"finisher_follow","hold"]],
 "finisher_recovery":[[0.0,"finisher_follow","hold"],[0.30,"finisher_follow","smooth"],[0.90,"weapon_ready","hold"],[1.0,"weapon_ready","hold"]]
}
# Low clearance retracts a forward blade; a rear-to-front planar rotation would
# pass through the ceiling/floor between valid keys.
const LOW_ANGLES={"weapon_ready":-12.0,"weapon_load":-5.0,"weapon_contact":-5.0,"weapon_follow":4.0,"backhand_load":-6.0,"backhand_contact":-6.0,"backhand_follow":-5.0,"finisher_load":-2.0,"finisher_contact":-2.0,"finisher_follow":8.0}
