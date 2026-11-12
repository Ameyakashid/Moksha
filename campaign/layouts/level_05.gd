extends RefCounted
## Crown: manual shutdown preparations, one final confrontation, then a choice.
static func sectors() -> Array[Dictionary]:
	var result: Array[Dictionary] = [_ascent(), _witnesses(), _governor(), _refuge(), _coolant(), _warden(), _threshold()]
	for area in result:
		area["level"] = 5
		area["level_name"] = "THE CROWN"
	return result

static func _ascent() -> Dictionary:
	return {"id":"crown_ascent","title":"05.1 / ABOVE THE MACHINES","subtitle":"Exterior steps • fixed service spine • crown intake","width":4600,"top":-680,"theme":"exterior","gate_y":-250,
	"text":"Above the Works, the Crown receives commands from below and returns them as law. The service spine was built for people, not commands.","hint":"Recover the intake fuse on the lower east balcony, then install it at the upper landing. A missed jump returns to the continuous recovery floor.",
	"platforms":[Rect2(360,245,180,55),Rect2(650,190,240,18),Rect2(1010,135,260,18),Rect2(1380,80,280,18),Rect2(1800,25,320,18),Rect2(2230,-30,280,18),Rect2(2640,-85,300,18),Rect2(3070,-140,300,18),Rect2(3500,-195,300,18),Rect2(3920,-250,680,18),Rect2(2200,190,380,18),Rect2(2760,135,400,18),Rect2(3340,80,400,18)],
	"ladders":[[760,300,110],[1480,300,220],[2320,300,330],[2840,300,385],[3200,300,440],[3600,300,495],[4210,300,550]],
	"lifts":[[Vector2(1740,250),Vector2(0,-220),6.0]],
	"enemies":[[790,"sentinel",190],[1550,"sentry",80],[2400,"listener",190],[2870,"sentinel",135],[3250,"sentry",-140],[3620,"listener",80],[4320,"sentinel",-250]],"props":[[460,245],[1460,80],[2290,190],[2900,135],[3410,80],[4050,-250]],
	"objectives":[{"id":"intake_fuse","label":"MANUAL INTAKE FUSE","kind":"recover","at":Vector2(2970,135)},{"id":"intake","label":"RESTORE MANUAL INTAKE","kind":"install","at":Vector2(4050,-250),"requires":["intake_fuse"],"text":"The Crown intake accepts a local command again."},{"id":"weather_log","label":"WEATHER STATION LOG","kind":"recover","at":Vector2(1940,25),"optional":true,"reward":"agility","text":"The same storm is recorded twice. The instruments may have failed."}],
	"objective_doors":[{"at":Vector2(4420,-390),"size":Vector2(26,280),"requires":["intake"]}],
	"signs":[[Vector2(180,255),"SERVICE SPINE ^ / FALL RECOVERY BELOW"],[Vector2(2770,100),"INTAKE FUSE >"],[Vector2(3940,-285),"MANUAL INTAKE / CROWN >"]],
	"route":[Vector2(1480,300),Vector2(1480,80),Vector2(2320,-30),Vector2(2840,-85),Vector2(2840,135),Vector2(2970,135),Vector2(3200,300),Vector2(3200,-140),Vector2(3600,-195),Vector2(4050,-250),Vector2(4555,-250)]}

static func _witnesses() -> Dictionary:
	return {"id":"crown_witness_galleries","title":"05.2 / THE WITNESS GALLERIES","subtitle":"Public record • sealed annex • uncensored passage","width":5200,"top":-490,"theme":"interior","station":Vector2(2400,300),
	"text":"The Crown presents one clean history. Its sealed annex contains the corrections. Carry the original and the correction together; neither is a complete answer.","hint":"The public record is low and west; the sealed annex is high and east. Their joint signature opens the witness passage.",
	"platforms":[Rect2(420,135,440,18),Rect2(1000,190,460,18),Rect2(1570,80,380,18),Rect2(2060,25,400,18),Rect2(2660,80,400,18),Rect2(2660,-140,400,18),Rect2(3170,-195,300,18),Rect2(3590,-250,450,18),Rect2(4180,-140,420,18),Rect2(4600,80,350,18),Rect2(1760,220,28,80),Rect2(3300,210,28,90)],
	"ladders":[[560,300,165],[1190,300,110],[2160,300,275],[2780,300,220],[2900,80,220],[3790,300,550],[4350,300,440],[4750,300,220]],
	"enemies":[[710,"listener",135],[1310,"sentinel",190],[2270,"sentry",25],[2960,"listener",-140],[3870,"sentinel",-250],[4410,"sentry",-140],[4830,"listener",300]],"props":[[470,300],[1090,190],[2190,25],[2730,80],[3650,-250],[4280,-140]],
	"objectives":[{"id":"public_copy","label":"PUBLIC RECORD PLATE","kind":"recover","at":Vector2(1330,190),"text":"The public copy describes a unanimous decision."},{"id":"annex_copy","label":"SEALED DISSENT PLATE","kind":"recover","at":Vector2(3900,-250),"text":"The annex lists dissent, then stops recording names."},{"id":"witness_passage","label":"PRESERVE DISSENT IN THE RECORD","kind":"install","at":Vector2(4150,300),"requires":["public_copy","annex_copy"],"text":"The passage opens without erasing either account."},{"id":"private_letter","label":"UNDELIVERED LETTER","kind":"recover","at":Vector2(4460,-140),"optional":true,"reward":"vitality","text":"I cannot promise to remember. I can promise to write it down."}],
	"objective_doors":[{"at":Vector2(4980,160),"size":Vector2(28,280),"requires":["witness_passage"]}],
	"signs":[[Vector2(1020,255),"PUBLIC RECORD ^"],[Vector2(2490,255),"ANNEX STACK ^"],[Vector2(3730,265),"ANNEX / FIXED RETURN ^"],[Vector2(4160,255),"PRESERVE BOTH PLATES"]],
	"route":[Vector2(1190,300),Vector2(1190,190),Vector2(1330,190),Vector2(1190,300),Vector2(2780,300),Vector2(2780,80),Vector2(2900,80),Vector2(2900,-140),Vector2(3790,-250),Vector2(3900,-250),Vector2(3790,300),Vector2(4150,300),Vector2(5155,300)]}

static func _governor() -> Dictionary:
	return {"id":"crown_manual_governor","title":"05.3 / THE MANUAL GOVERNOR","subtitle":"West bypass • east governor • command isolation","width":5500,"top":-470,"theme":"interior","spawn":Vector2(2600,300),"station":Vector2(2600,300),
	"text":"Two feeds sustain automatic reset. One controls authority; the other supplies its power. Isolate both before opening the manual governor.","hint":"Start at the central service desk. West holds authority isolation and an optional tool, east holds the power circuit. Return to the desk to unlock the Crown's manual path.",
	"platforms":[Rect2(430,80,420,18),Rect2(960,25,400,18),Rect2(1460,80,400,18),Rect2(1990,135,330,18),Rect2(2800,135,350,18),Rect2(3260,80,400,18),Rect2(3780,25,420,18),Rect2(4340,80,400,18),Rect2(4850,135,380,18),Rect2(1100,215,26,85),Rect2(3510,220,26,80),Rect2(4470,190,26,110)],
	"ladders":[[550,300,220],[1150,300,275],[1640,300,220],[2140,300,165],[2930,300,165],[3440,300,220],[3950,300,275],[4540,300,220]],
	"enemies":[[680,"sentinel",80],[1230,"sentry",25],[1720,"listener",300],[3000,"listener",135],[3540,"sentinel",80],[4050,"sentry",25],[4630,"listener",300],[5110,"sentinel",135]],"props":[[520,300],[1020,25],[1580,80],[2870,135],[3350,300],[3900,25],[4900,135]],
	"objectives":[{"id":"bypass","label":"MANUAL BYPASS KEY","kind":"recover","at":Vector2(650,80),"optional":true,"reward":"force","text":"A manual tool left for the next service crew; the two local feeds can be isolated independently."},{"id":"authority","label":"BREAK AUTHORITY FEED / J","kind":"breaker","at":Vector2(1230,25)},{"id":"supply","label":"LOCAL SUPPLY / SET 2","kind":"route","target":2,"at":Vector2(4050,25)},{"id":"governor","label":"UNLOCK MANUAL GOVERNOR","kind":"install","at":Vector2(2710,300),"requires":["authority","supply"],"text":"Automatic commands can no longer override the local controls."},{"id":"tool_roll","label":"SERVICE TOOL ROLL","kind":"recover","at":Vector2(5040,135),"optional":true,"reward":"force"}],
	"objective_doors":[{"at":Vector2(5310,160),"size":Vector2(26,280),"requires":["governor"]}],
	"hazards":[{"at":Vector2(1860,292),"size":Vector2(160,16),"period":4.4,"phase":0.9},{"at":Vector2(3700,292),"size":Vector2(160,16),"period":3.8,"phase":1.8}],
	"signs":[[Vector2(2350,250),"AUTHORITY < / SUPPLY >"],[Vector2(1700,45),"AUTHORITY < / STRIKE"],[Vector2(3370,45),"LOCAL SUPPLY >"],[Vector2(4780,265),"CROWN SERVICE EXIT >"]],
	"route":[Vector2(2600,300),Vector2(2140,300),Vector2(2140,135),Vector2(1640,80),Vector2(1150,25),Vector2(650,80),Vector2(1230,25),Vector2(1640,80),Vector2(2140,135),Vector2(2140,300),Vector2(3440,300),Vector2(3440,80),Vector2(3950,25),Vector2(4050,25),Vector2(3440,80),Vector2(3440,300),Vector2(2710,300),Vector2(3440,300),Vector2(3440,80),Vector2(3950,25),Vector2(4540,80),Vector2(5455,300)]}

static func _refuge() -> Dictionary:
	return {"id":"crown_refuge_channel","title":"05.4 / BEFORE THE SILENCE","subtitle":"Evacuation routing • occupied refuge • independent exit","width":4800,"top":-420,"theme":"interior",
	"text":"A shutdown without an evacuation is another order given over people's heads. Open the refuge's independent exit before approaching the Crown controls.","hint":"The evacuation route needs a physical key and the refuge circuit. Rescue is a real prerequisite; the side shelter is optional.",
	"platforms":[Rect2(410,190,350,18),Rect2(870,135,360,18),Rect2(1360,80,420,18),Rect2(1900,135,360,18),Rect2(2380,80,400,18),Rect2(2890,25,430,18),Rect2(3440,80,400,18),Rect2(3960,135,430,18),Rect2(1090,220,26,80),Rect2(2620,200,26,100)],
	"ladders":[[540,300,110],[1490,300,220],[2050,300,165],[2530,300,220],[3060,300,275],[3600,300,220],[4110,300,165]],
	"enemies":[[660,"sentinel",190],[1180,"listener",300],[1640,"sentry",80],[2160,"listener",135],[3190,"sentinel",25],[3720,"sentry",80],[4270,"listener",300]],"props":[[460,190],[1020,300],[1530,80],[2460,80],[2980,25],[4020,135]],
	"objectives":[{"id":"refuge_key","label":"EVACUATION MECHANICAL KEY","kind":"recover","at":Vector2(1620,80)},{"id":"refuge_bus","label":"REFUGE CIRCUIT / SET 1","kind":"route","target":1,"at":Vector2(3170,25)},{"id":"exit_link","label":"CONNECT INDEPENDENT EXIT","kind":"install","at":Vector2(2530,300),"requires":["refuge_key","refuge_bus"]},{"id":"refuge_release","label":"RELEASE OCCUPIED REFUGE","kind":"rescue","at":Vector2(3610,300),"requires":["exit_link"],"text":"The refuge occupants leave by an exit that does not depend on the Crown."},{"id":"side_refuge","label":"OPEN THE SIDE SHELTER","kind":"rescue","at":Vector2(4200,135),"requires":["exit_link"],"optional":true,"reward":"vitality"}],
	"objective_doors":[{"at":Vector2(4520,160),"size":Vector2(28,280),"requires":["refuge_release"]}],
	"signs":[[Vector2(1370,255),"EVACUATION KEY ^"],[Vector2(2400,255),"EXIT LINK / CIRCUIT EAST ^"],[Vector2(3450,255),"OCCUPIED REFUGE >"],[Vector2(3980,255),"SIDE SHELTER ^"]],
	"route":[Vector2(1490,300),Vector2(1490,80),Vector2(1620,80),Vector2(1490,300),Vector2(3060,300),Vector2(3060,25),Vector2(3170,25),Vector2(3060,300),Vector2(2530,300),Vector2(3610,300),Vector2(4755,300)]}

static func _coolant() -> Dictionary:
	return {"id":"crown_coolant_interlock","title":"05.5 / THE LAST SERVICE RUN","subtitle":"Intact delivery • split coolant control • fixed bypass","width":5300,"top":-480,"theme":"interior","station":Vector2(230,300),
	"text":"The manual controls cannot be isolated safely while the Crown is hot. Deliver the service carrier, then divert the cooling flow away from automatic restart.","hint":"The cargo deck stays flat. Upper routes shelter the operator from floor pulses. Lost cargo can be replaced at its cradle; no timing gate is mandatory.",
	"platforms":[Rect2(430,135,400,18),Rect2(950,80,360,18),Rect2(1440,240,1500,18),Rect2(1500,70,400,18),Rect2(2020,15,360,18),Rect2(2490,70,390,18),Rect2(3350,80,400,18),Rect2(3880,-30,420,18),Rect2(4420,80,400,18),Rect2(4900,190,220,18),Rect2(3680,200,26,100)],
	"ladders":[[560,300,165],[1110,300,220],[1500,300,60],[1660,240,170],[2210,240,225],[2670,240,170],[3480,300,220],[4050,300,330],[4580,300,220]],
	"enemies":[[720,"listener",135],[1210,"sentinel",80],[1800,"sentry",70],[2290,"listener",15],[2770,"sentinel",70],[3610,"sentry",80],[4190,"sentinel",-30],[4730,"listener",300]],"props":[[520,135],[1040,80],[1630,70],[2100,15],[2550,70],[3420,300],[3950,-30]],
	"freight":{"cradle":Vector2(2150,240),"receiver":Vector2(3010,270),"shutter":[Vector2(3220,30),Vector2(26,540)]},
	"objectives":[{"id":"coolant_tag","label":"SERVICE COOLANT TAG","kind":"recover","at":Vector2(1180,80)},{"id":"divert","label":"COOLANT DIVERSION / SET 2","kind":"route","target":2,"at":Vector2(4160,-30),"requires":["coolant_tag"]},{"id":"cold_lock","label":"RELEASE COLD-SERVICE INTERLOCK","kind":"install","at":Vector2(4650,300),"requires":["coolant_tag","divert"],"text":"Cooling remains active. Automatic restart loses its feed."},{"id":"service_drawing","label":"HAND-DRAWN SERVICE PLAN","kind":"recover","at":Vector2(2230,15),"optional":true,"reward":"agility"}],
	"objective_doors":[{"at":Vector2(5130,160),"size":Vector2(26,280),"requires":["cold_lock"]}],
	"hazards":[{"at":Vector2(3750,292),"size":Vector2(180,16),"period":4.0,"phase":0.3}],
	"signs":[[Vector2(950,255),"SERVICE TAG ^"],[Vector2(1470,205),"CARGO / FLAT TRANSFER >"],[Vector2(2780,205),"RECEIVER >"],[Vector2(3410,255),"FIXED BYPASS ^ / DIVERSION EAST"],[Vector2(4480,255),"COLD-SERVICE INTERLOCK >"]],
	"route":[Vector2(1110,300),Vector2(1110,80),Vector2(1180,80),Vector2(1500,300),Vector2(1500,240),Vector2(2150,240),Vector2(2940,240),Vector2(3010,300),Vector2(3480,300),Vector2(3480,80),Vector2(4050,-30),Vector2(4160,-30),Vector2(4580,80),Vector2(4650,300),Vector2(5255,300)]}

static func _warden() -> Dictionary:
	return {"id":"crown_last_warden","title":"05.6 / THE LAST AUTHORITY","subtitle":"Outer watch • command dais • maintenance escape loops","width":4200,"top":-460,"theme":"interior","boss_name":"CROWN WARDEN","lock":true,"station":Vector2(240,300),
	"text":"WARDEN: Someone must hold this command.\nOPERATIVE: Holding a command is not the same as choosing it.\nThe final guard waits at the command dais; the maintenance loops remain open.","hint":"This security seal requires the Warden and all five watch guards defeated. Open the dais interlock too. Use solid plinths for cover and both recovery ladders.",
	"platforms":[Rect2(420,135,380,18),Rect2(940,80,400,18),Rect2(1460,135,360,18),Rect2(1900,245,180,55),Rect2(2170,190,320,18),Rect2(2540,120,32,130),Rect2(2660,135,300,18),Rect2(3060,245,180,55),Rect2(3300,190,340,18),Rect2(2110,-40,330,18),Rect2(2700,-40,330,18),Rect2(3730,135,270,18)],
	"ladders":[[540,300,165],[1100,300,220],[1580,300,165],[2270,300,110],[2350,190,230],[2810,300,165],[2910,135,175],[3470,300,110],[3850,300,165]],
	"enemies":[[710,"listener",135],[1210,"sentinel",80],[1730,"sentry",135],[2320,"sentry",190],[2770,"warden",300],[3410,"sentry",190]],"props":[[500,300],[1020,80],[1520,135],[2230,190],[2720,-40],[3200,300]],
	"objectives":[{"id":"approach_key","label":"DAIS MAINTENANCE KEY","kind":"recover","at":Vector2(1200,80)},{"id":"dais_release","label":"OPEN COMMAND DAIS","kind":"install","at":Vector2(1850,300),"requires":["approach_key"]},{"id":"final_record","label":"THE WARDEN'S SERVICE RECORD","kind":"recover","at":Vector2(2880,-40),"optional":true,"reward":"force","text":"Orders were revised. The guard's appointment never was."}],
	"objective_doors":[{"at":Vector2(2090,140),"size":Vector2(24,320),"requires":["dais_release"]}],
	"signs":[[Vector2(870,255),"MAINTENANCE KEY ^"],[Vector2(1690,255),"DAIS INTERLOCK >"],[Vector2(2200,255),"WEST LOOP ^ / COVER PLINTH"],[Vector2(3100,255),"EAST LOOP ^ / RECOVERY FLOOR"],[Vector2(3830,100),"MANUAL CONTROLS >"]],
	"route":[Vector2(1100,300),Vector2(1100,80),Vector2(1200,80),Vector2(1850,300),Vector2(2270,300),Vector2(2270,190),Vector2(2350,-40),Vector2(2810,135),Vector2(2770,300),Vector2(3470,300),Vector2(3470,190),Vector2(4155,300)]}

static func _threshold() -> Dictionary:
	return {"id":"crown_choice_threshold","title":"05.7 / A CHOICE WITHOUT AN ORDER","subtitle":"Safeguards • preserved testimony • the manual threshold","width":4000,"top":-400,"theme":"interior","station":Vector2(220,300),
	"text":"The Warden is silent. The Crown still runs. Before choosing its future, separate the evacuation channel and preserve the records you brought this far. Neither action explains the loop. Both are yours.","hint":"No compulsory combat. Complete the independent safeguards, then reach the manual threshold. The final decision is not a claim about immortality or the loop's cause.",
	"platforms":[Rect2(430,190,400,18),Rect2(970,135,410,18),Rect2(1510,80,460,18),Rect2(2110,135,400,18),Rect2(2650,80,420,18),Rect2(3210,135,450,18),Rect2(1770,220,24,80)],
	"ladders":[[570,300,110],[1110,300,165],[1700,300,220],[2260,300,165],[2820,300,220],[3410,300,165]],
	"enemies":[],"props":[[530,190],[1050,135],[1590,80],[2190,135],[2760,80],[3300,135]],
	"objectives":[{"id":"independent_exit","label":"KEEP EVACUATION INDEPENDENT / SET 1","kind":"route","target":1,"at":Vector2(1200,135),"text":"The evacuation channel will remain powered after your decision."},{"id":"testimony","label":"PRESERVE THE CONTRADICTORY RECORD","kind":"recover","at":Vector2(2900,80),"text":"Two accounts remain. Neither has been rewritten to comfort the other."},{"id":"manual_threshold","label":"UNLOCK FINAL MANUAL CONTROLS","kind":"install","at":Vector2(2340,135),"requires":["independent_exit","testimony"],"text":"The last automatic veto disengages. What follows is a choice, not an instruction."},{"id":"blank_page","label":"LEAVE A BLANK PAGE","kind":"terminal","at":Vector2(3510,135),"optional":true,"text":"For the next person, there is space to disagree."}],
	"objective_doors":[{"at":Vector2(3750,160),"size":Vector2(26,280),"requires":["manual_threshold"]}],
	"signs":[[Vector2(890,255),"EVACUATION SAFEGUARD ^"],[Vector2(2050,255),"MANUAL CONTROLS ^ / RECORD EAST"],[Vector2(2690,255),"PRESERVED TESTIMONY ^"],[Vector2(3660,255),"FINAL DECISION >"]],
	"route":[Vector2(1110,300),Vector2(1110,135),Vector2(1200,135),Vector2(1110,300),Vector2(2820,300),Vector2(2820,80),Vector2(2900,80),Vector2(2820,300),Vector2(2260,300),Vector2(2260,135),Vector2(2340,135),Vector2(3955,300)]}
