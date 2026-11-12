extends RefCounted
## Authored memory-works districts. Geometry/data only; no player overrides.
static func sectors() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_receiving(), _baffles(), _cargo(), _loom(), _evacuation(), _circuits(), _dispatch()
	]
	for area in result:
		area["level"] = 4
		area["level_name"] = "MEMORY WORKS"
	return result

static func _receiving() -> Dictionary:
	return {"id":"works_receiving","title":"04.1 / THE RECEIVING DESK","subtitle":"Two manifests, one falsified delivery","width":4400,"top":-400,"theme":"interior","station":Vector2(220,300),
	"text":"The Works calls people deliveries. Two copies of the same manifest disagree. Recover both before trusting its lock.","hint":"The west file is on the inspection balcony; the east copy is in the lower sorting bay. Fixed ladders return to both.",
	"platforms":[Rect2(480,245,160,55),Rect2(700,190,190,18),Rect2(940,135,240,18),Rect2(1230,80,360,18),Rect2(1670,80,260,18),Rect2(2010,135,220,18),Rect2(2360,190,380,18),Rect2(2860,80,350,18),Rect2(3340,135,420,18),Rect2(3930,245,160,55),Rect2(2140,220,24,80)],
	"ladders":[[1300,300,220],[2450,300,110],[3000,300,220],[3500,300,165]],
	"enemies":[[760,"listener",190],[1490,"sentry",80],[2110,"sentinel",300],[2560,"listener",190],[3080,"sentry",80],[3650,"sentinel",300]],"props":[[560,245],[1100,300],[1720,80],[2500,300],[3390,135]],
	"objectives":[{"id":"origin","label":"ORIGINAL MANIFEST","kind":"recover","at":Vector2(1400,80),"text":"The names were recorded before arrival."},{"id":"revision","label":"REVISED MANIFEST","kind":"recover","at":Vector2(2780,300),"text":"Every refusal was relabeled equipment failure."},{"id":"compare","label":"RECONCILE MANIFESTS","kind":"install","at":Vector2(3250,300),"requires":["origin","revision"],"text":"The inspection lock recognizes the unaltered signatures."},{"id":"margin","label":"HANDWRITTEN MARGIN","kind":"recover","at":Vector2(3570,135),"optional":true,"reward":"vitality","text":"Someone kept the names the ledger erased."}],
	"objective_doors":[{"at":Vector2(3820,160),"size":Vector2(26,280),"requires":["compare"]}],
	"signs":[[Vector2(260,255),"INSPECTION ^ / SORTING >"],[Vector2(2360,260),"EAST COPY BELOW"],[Vector2(3260,255),"COMPARE TWO COPIES / RELEASE INSPECTION"]],
	"route":[Vector2(220,300),Vector2(1300,300),Vector2(1300,80),Vector2(1400,80),Vector2(2000,300),Vector2(2780,300),Vector2(3250,300),Vector2(4355,300)]}

static func _baffles() -> Dictionary:
	return {"id":"works_baffle_hall","irritants":[{"at":Vector2(1200,268)}],"title":"04.2 / THE LISTENING FLOOR","subtitle":"Noise court • shielded galleries • silent control","width":4800,"top":-400,"theme":"interior",
	"text":"Listeners patrol the open floor beside a gas disperser. Its warning precedes a short release that briefly interrupts attacks and guard. The upper baffles bypass the gas. Sever the surveillance feed, then engage the quiet interlock.","hint":"Gas does no direct health damage and leaves movement free; electricity still hurts. With hearing retained, GAS WARNING precedes GAS HISS. Strike spare props to draw listeners away.",
	"platforms":[Rect2(440,80,520,18),Rect2(1080,80,420,18),Rect2(1640,135,340,18),Rect2(2130,80,420,18),Rect2(2700,25,440,18),Rect2(3280,80,400,18),Rect2(3840,135,430,18),Rect2(760,200,26,100),Rect2(1830,210,26,90),Rect2(3000,175,26,125),Rect2(4070,215,26,85)],
	"ladders":[[510,300,220],[1420,300,220],[2240,300,220],[2800,300,275],[3540,300,220],[4140,300,165]],
	"enemies":[[880,"listener",300],[1260,"listener",300],[1750,"sentinel",135],[2460,"listener",300],[2930,"sentry",25],[3400,"listener",300],[3960,"sentinel",135]],"props":[[340,300],[690,80],[1150,300],[2180,80],[3160,300],[4000,135]],
	"hazards":[{"at":Vector2(1510,292),"size":Vector2(220,16),"period":3.6,"phase":0.3},{"at":Vector2(3190,292),"size":Vector2(220,16),"period":4.2,"phase":1.1}],
	"objectives":[{"id":"baffle_key","label":"BAFFLE SERVICE KEY","kind":"recover","at":Vector2(2360,80)},{"id":"quiet_bus","label":"SEVER SURVEILLANCE FEED / J","kind":"breaker","at":Vector2(1240,80),"requires":["baffle_key"],"text":"Machine noise no longer masks the workers' distress channel."},{"id":"quiet_lock","label":"ENGAGE BAFFLE INTERLOCK","kind":"install","at":Vector2(3730,300),"requires":["quiet_bus","baffle_key"]},{"id":"echo_notes","label":"LISTENER CALIBRATION NOTES","kind":"recover","at":Vector2(2930,25),"optional":true,"reward":"agility"}],
	"objective_doors":[{"at":Vector2(4370,160),"size":Vector2(26,280),"requires":["quiet_lock"]}],
	"signs":[[Vector2(280,255),"SPARE PROPS / BAFFLES ^"],[Vector2(1340,45),"SURVEILLANCE BREAKER / STRIKE J"],[Vector2(2310,45),"KEY / RETURN WEST <"],[Vector2(3580,255),"INTERLOCK >"]],
	"route":[Vector2(510,300),Vector2(510,80),Vector2(1420,80),Vector2(1420,300),Vector2(2240,300),Vector2(2240,80),Vector2(2360,80),Vector2(2240,300),Vector2(1420,300),Vector2(1420,80),Vector2(1240,80),Vector2(2800,300),Vector2(2800,25),Vector2(3050,25),Vector2(3540,80),Vector2(3730,300),Vector2(4755,300)]}

static func _cargo() -> Dictionary:
	return {"id":"works_cargo_exchange","title":"04.3 / RETURN TO SENDER","subtitle":"Acquisition roof • protected transfer • dispatch interlock","width":5000,"top":-370,"theme":"interior",
	"text":"An intact carrier can cross the dispatch interlock. Its route is shorter than yours: prepare the receiver, then escort it without destroying it.","hint":"J moves the marked delivery. E at its cradle replaces lost cargo. The receiver approach is flat; roof access is optional.",
	"platforms":[Rect2(430,100,360,18),Rect2(930,100,350,18),Rect2(1420,160,320,18),Rect2(1900,240,1400,18),Rect2(1920,70,340,18),Rect2(2430,70,300,18),Rect2(2880,70,300,18),Rect2(3650,135,380,18),Rect2(4160,80,360,18),Rect2(870,215,28,85),Rect2(3880,220,28,80)],
	"ladders":[[510,300,200],[1530,300,140],[1950,300,60],[2060,240,170],[3000,240,170],[3760,300,165],[4290,300,220]],
	"enemies":[[700,"listener",300],[1110,"sentry",100],[1590,"sentinel",160],[2540,"listener",70],[3090,"sentry",70],[3860,"sentinel",135],[4370,"listener",300]],"props":[[350,300],[1000,100],[1540,160],[2490,70],[3730,300]],
	"freight":{"cradle":Vector2(2510,240),"receiver":Vector2(3370,270),"shutter":[Vector2(3530,30),Vector2(26,540)]},
	"objectives":[{"id":"delivery_tag","label":"UNREDACTED DELIVERY TAG","kind":"recover","at":Vector2(1530,160),"text":"The carrier contains testimony, not replacement parts."},{"id":"receiver_bus","label":"RECEIVER BUS / SET 1","kind":"route","target":1,"at":Vector2(3260,240),"requires":["delivery_tag"]},{"id":"handoff","label":"VERIFY PROTECTED HANDOFF","kind":"install","at":Vector2(4100,300),"requires":["delivery_tag","receiver_bus"]},{"id":"carrier_note","label":"COURIER'S NOTE","kind":"recover","at":Vector2(4370,80),"optional":true,"reward":"force"}],
	"objective_doors":[{"at":Vector2(4600,160),"size":Vector2(26,280),"requires":["handoff"]}],
	"signs":[[Vector2(270,255),"MANIFEST ROOF ^"],[Vector2(1940,205),"DELIVERY CRADLE / E TO REPLACE"],[Vector2(2900,205),"KEEP CARGO ON DECK >"],[Vector2(3300,205),"RECEIVER BUS 1"],[Vector2(3600,255),"PROTECTED HANDOFF >"]],
	"route":[Vector2(510,300),Vector2(510,100),Vector2(1180,100),Vector2(1530,160),Vector2(1950,300),Vector2(1950,240),Vector2(2510,240),Vector2(3260,240),Vector2(3370,300),Vector2(4100,300),Vector2(4955,300)]}

static func _loom() -> Dictionary:
	return {"id":"works_memory_loom","title":"04.4 / THE MEMORY LOOM","subtitle":"Stacked records • return bridges • disputed testimony","width":5600,"top":-620,"theme":"interior","station":Vector2(2400,300),
	"text":"The machine stores contradictory accounts in separate shelves. No single record explains the loop. Keep both intact rather than choosing the machine's preferred history.","hint":"Two independent stacks feed the comparison desk. Climb fixed ladders; the moving lift is only a shortcut.",
	"platforms":[Rect2(420,135,380,18),Rect2(940,80,300,18),Rect2(1300,80,400,18),Rect2(1300,-140,400,18),Rect2(1730,-195,220,18),Rect2(2000,-250,460,18),Rect2(2530,-195,280,18),Rect2(3000,80,420,18),Rect2(3000,-140,420,18),Rect2(3500,-195,250,18),Rect2(3820,-250,420,18),Rect2(4370,-195,300,18),Rect2(4720,80,450,18),Rect2(2750,220,25,80)],
	"ladders":[[510,300,165],[1400,300,220],[1510,80,220],[2200,300,550],[3110,300,220],[3220,80,220],[4020,300,550],[4840,300,220]],
	"lifts":[[Vector2(2640,250),Vector2(0,-440),6.5]],
	"enemies":[[680,"listener",135],[1580,"sentry",-140],[2300,"sentinel",-250],[2820,"listener",300],[3280,"sentinel",80],[4090,"sentry",-250],[4920,"listener",80]],"props":[[600,300],[1420,80],[2110,-250],[3040,300],[3130,-140],[4410,-195]],
	"objectives":[{"id":"first_account","label":"FIRST-PERSON ACCOUNT","kind":"recover","at":Vector2(2320,-250),"text":"The operative remembers giving the order. The date is absent."},{"id":"other_account","label":"SECOND WITNESS ACCOUNT","kind":"recover","at":Vector2(4110,-250),"text":"A witness remembers refusing the order. The recorder is damaged."},{"id":"preserve","label":"ISOLATE BOTH ORIGINALS","kind":"install","at":Vector2(4570,300),"requires":["first_account","other_account"],"text":"The originals leave the rewriting bus. Their disagreement remains evidence."},{"id":"index","label":"LOOM SERVICE INDEX","kind":"recover","at":Vector2(4900,80),"optional":true,"reward":"vitality"}],
	"objective_doors":[{"at":Vector2(5230,160),"size":Vector2(28,280),"requires":["preserve"]}],
	"signs":[[Vector2(1200,255),"FIRST ACCOUNT ^"],[Vector2(2340,255),"REST / SECOND ACCOUNT >"],[Vector2(3040,255),"SECOND ACCOUNT ^"],[Vector2(4300,255),"PRESERVE BOTH / COMPARISON >"]],
	"route":[Vector2(1400,300),Vector2(1400,80),Vector2(1510,80),Vector2(1510,-140),Vector2(2200,-250),Vector2(2320,-250),Vector2(2200,300),Vector2(3110,300),Vector2(3110,80),Vector2(3220,80),Vector2(3220,-140),Vector2(4020,-250),Vector2(4110,-250),Vector2(4020,300),Vector2(4570,300),Vector2(5555,300)]}

static func _evacuation() -> Dictionary:
	return {"id":"works_service_refuge","title":"04.5 / THE SERVICE REFUGE","subtitle":"Return key • shelter circuit • occupied pods","width":4700,"top":-400,"theme":"interior",
	"text":"The service crew stayed to hold an evacuation channel open. Their pods have power but no route. Recover a key, route shelter power, then release them.","hint":"The key is beyond the shelter on its upper service balcony. Return by the lower corridor. Do not route power to the machinery feed.",
	"platforms":[Rect2(400,190,350,18),Rect2(880,135,420,18),Rect2(1420,80,500,18),Rect2(2060,135,320,18),Rect2(2500,80,400,18),Rect2(3000,25,500,18),Rect2(3640,80,400,18),Rect2(4140,190,240,18),Rect2(1120,225,24,75),Rect2(2670,210,24,90)],
	"ladders":[[520,300,110],[1600,300,220],[2180,300,165],[2620,300,220],[3160,300,275],[3850,300,220]],
	"enemies":[[680,"sentinel",190],[1240,"listener",300],[2240,"listener",135],[2770,"sentry",80],[3320,"sentinel",25],[3920,"listener",300]],"props":[[580,190],[950,300],[1740,80],[2510,300],[3080,25],[3760,80]],
	"objectives":[{"id":"crew_key","label":"CREW OVERRIDE KEY","kind":"recover","at":Vector2(3370,25)},{"id":"shelter_power","label":"SHELTER POWER / SET 2","kind":"route","target":2,"at":Vector2(1770,80),"requires":["crew_key"]},{"id":"crew_release","label":"OPEN CREW EVAC POD","kind":"rescue","at":Vector2(2180,300),"requires":["crew_key","shelter_power"],"text":"The crew takes the service exit. One leaves a maintenance map behind."},{"id":"side_pod","label":"RELEASE ISOLATED TECHNICIAN","kind":"rescue","at":Vector2(3900,80),"requires":["shelter_power"],"optional":true,"reward":"agility","text":"The technician refuses to call uncertainty a malfunction."}],
	"objective_doors":[{"at":Vector2(4460,160),"size":Vector2(28,280),"requires":["crew_release"]}],
	"hazards":[{"at":Vector2(2910,292),"size":Vector2(180,16),"period":4.0,"phase":0.7}],
	"signs":[[Vector2(1450,255),"SHELTER POWER ^"],[Vector2(2080,255),"OCCUPIED POD / KEY EAST ^"],[Vector2(3180,-10),"CREW KEY / RETURN WEST <"],[Vector2(3680,255),"OPTIONAL TECHNICIAN ^"]],
	"route":[Vector2(2620,300),Vector2(2620,80),Vector2(3160,25),Vector2(3370,25),Vector2(3160,25),Vector2(2620,80),Vector2(2620,300),Vector2(1600,300),Vector2(1600,80),Vector2(1770,80),Vector2(2180,300),Vector2(2620,300),Vector2(2620,80),Vector2(3160,25),Vector2(3850,80),Vector2(4655,300)]}

static func _circuits() -> Dictionary:
	# Reuse one existing authored layout, not repeated-room generation.
	var area: Dictionary = preload("res://demo/areas/relay_works.gd").sector().duplicate(true)
	area["id"] = "works_three_crews"
	area["title"] = "04.6 / THREE CREWS"
	area["text"] = "The crews left independent circuits so no supervisor could own the only way out. Restore all three; the machine gallery joins Dispatch above the shutters."
	area["route"] = [Vector2(2200,300),Vector2(450,300),Vector2(1250,300),Vector2(1250,80),Vector2(2600,300),Vector2(2600,80),Vector2(2700,80),Vector2(2700,-140),Vector2(3200,-155),Vector2(3200,-430),Vector2(3440,-430),Vector2(4220,300),Vector2(4220,-240),Vector2(5520,300),Vector2(5520,-240),Vector2(6355,300)]
	return area

static func _dispatch() -> Dictionary:
	return {"id":"works_dispatch_refusal","title":"04.7 / THE UNSENT ORDER","captains":[{"kind":"captain_keeper","at":Vector2(4740,300)}],"captain_required":true,"subtitle":"Stamp archive • isolation desk • crown approach","width":5200,"top":-450,"theme":"interior","station":Vector2(230,300),
	"text":"An unsigned reset order waits at dispatch. You can isolate its transmission without deciding yet what the Crown should become.","hint":"Disconnect the east bus, then return to the dispatch desk. The west authorization stamp is optional evidence. At departure, the Keeper retreats before thrusting: close after recovery, not during the warning. Fixed ladders remain.",
	"platforms":[Rect2(480,135,420,18),Rect2(1000,80,440,18),Rect2(1530,-30,460,18),Rect2(2110,80,340,18),Rect2(2550,135,380,18),Rect2(3060,80,400,18),Rect2(3570,-30,460,18),Rect2(4120,80,400,18),Rect2(4660,190,280,18),Rect2(1190,220,24,80),Rect2(3280,200,24,100)],
	"ladders":[[580,300,165],[1150,300,220],[1710,300,330],[2660,300,165],[3200,300,220],[3800,300,330],[4340,300,220]],
	"enemies":[[730,"listener",135],[1280,"sentry",80],[1810,"sentinel",-30],[2780,"listener",135],[3370,"sentry",80],[3900,"sentinel",-30],[4470,"listener",300]],"props":[[600,135],[1050,300],[1640,-30],[2570,135],[3130,300],[3690,-30],[4300,80]],
	"objectives":[{"id":"stamp","label":"DISPATCH AUTHORIZATION STAMP","kind":"recover","at":Vector2(1800,-30),"optional":true,"reward":"agility","text":"A signature preserved as evidence, not permission to obey the order."},{"id":"isolate","label":"ISOLATE RESET BUS / SET 0","kind":"route","target":0,"at":Vector2(3880,-30),"text":"Dispatch no longer repeats the pending command."},{"id":"refuse","label":"SEAL UNSENT ORDER","kind":"install","at":Vector2(2750,135),"requires":["isolate"],"text":"The order remains evidence. It is not transmitted."},{"id":"last_shift","label":"LAST SHIFT REGISTER","kind":"recover","at":Vector2(4380,80),"optional":true,"reward":"force","text":"There is no final entry. The register ends in the middle of a sentence."}],
	"objective_doors":[{"at":Vector2(5000,160),"size":Vector2(28,280),"requires":["refuse"]}],
	"hazards":[{"at":Vector2(3470,292),"size":Vector2(180,16),"period":3.8,"phase":1.3}],
	"signs":[[Vector2(1000,255),"STAMP ARCHIVE ^"],[Vector2(2580,255),"DISPATCH DESK ^ / BUS EAST"],[Vector2(3680,255),"ISOLATION ^ / FIXED RETURN"],[Vector2(4600,255),"KEEPER: RETREAT / THRUST / PUNISH RECOVERY"],[Vector2(4940,255),"CROWN APPROACH >"]],
	"route":[Vector2(1710,300),Vector2(1710,-30),Vector2(1800,-30),Vector2(1710,300),Vector2(3200,300),Vector2(3200,80),Vector2(3800,-30),Vector2(3880,-30),Vector2(3200,80),Vector2(3200,300),Vector2(2660,300),Vector2(2660,135),Vector2(2750,135),Vector2(3200,300),Vector2(3200,80),Vector2(3800,-30),Vector2(4340,80),Vector2(5155,300)]}
