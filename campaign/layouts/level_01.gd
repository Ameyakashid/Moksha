extends RefCounted
## Authored street prologue: lives, logistics and an entry route, not a kill corridor.
static func sectors()->Array[Dictionary]:
	var market:Dictionary=preload("res://demo/areas/rainline_neighbourhood.gd").sector().duplicate(true)
	market.title="RAINLINE / THE LAST BADGE";market.level=1;market.level_name="CITY WITHOUT A MASTER"
	market.route=[Vector2(710,300),Vector2(1870,-40),Vector2(2590,-160),Vector2(3500,-280),Vector2(6155,300)]
	var intake:Dictionary=preload("res://demo/areas/quarantine_intake.gd").sector().duplicate(true)
	intake.title="QUARANTINE / TWO WAYS THROUGH";intake.level=1;intake.level_name="CITY WITHOUT A MASTER"
	intake.captains=[{"kind":"captain_lancer","at":Vector2(2000,300)}];intake.captain_required=true
	intake.text="Restore the crossing relay, then defeat the lancer holding its seal.\nOther patrols can be bypassed. Dodge the lancer's committed charge.\nThe upper maintenance route and ground lane meet at the crossing."
	intake.route=[Vector2(1430,230),Vector2(1540,0),Vector2(2355,-280)]
	return [market,_clinic(),_tram(),_archives(),_evacuation(),intake]
static func _clinic()->Dictionary:
	return {"id":"city_clinic","level":1,"level_name":"CITY WITHOUT A MASTER","title":"THE NIGHT CLINIC","subtitle":"Supply line · sheltered court · ambulance roof","width":6400,"top":-400,"theme":"city","backdrop_scene":preload("res://demo/views/favela_backdrop.tscn"),
	"text":"The clinic's reserve power is stranded beyond the patrol line.\nBring the cell back to its generator, then unlock the evacuation pod.\nThe shelter is not a security target: you can leave its guards behind.","hint":"TAB opens the objective journal. E recovers and installs items. Rooftops bypass crossfire.",
	"platforms":[Rect2(320,245,180,55),Rect2(570,180,290,18),Rect2(980,115,340,18),Rect2(1450,50,310,18),Rect2(1890,-15,350,18),Rect2(2380,-80,420,18),Rect2(2940,-145,380,18),Rect2(3440,-80,310,18),Rect2(3900,-15,360,18),Rect2(4420,50,300,18),Rect2(4880,115,380,18),Rect2(5400,180,400,18),Rect2(5980,245,180,55),Rect2(1750,245,180,55),Rect2(3050,220,280,80),Rect2(4100,245,160,55)],
	"ladders":[[710,300,120],[1590,300,250],[2570,300,380],[3100,220,365],[4020,300,315],[5550,300,120]],"lifts":[[Vector2(4560,240),Vector2(0,-220),5.0]],
	"enemies":[[920,"sentinel",300],[1160,"sentry",115],[1700,"listener",300],[2100,"sentinel",-15],[2700,"sentry",-80],[3650,"listener",300],[4200,"sentinel",-15],[4720,"sentry",300],[5150,"sentinel",115],[5880,"listener",300]],
	"props":[[650,300],[1300,300],[2010,-15],[2820,300],[3500,-80],[4450,300],[5600,180]],
	"objectives":[{"id":"cell","label":"Recover clinic power cell","kind":"recover","at":Vector2(3190,-145),"text":"A portable cell, still charged."},{"id":"generator","label":"Restore clinic reserve","kind":"install","at":Vector2(1590,50),"requires":["cell"],"text":"The stairwell lights return."},{"id":"patients","label":"Release clinic evacuation pod","kind":"rescue","at":Vector2(5640,180),"requires":["generator"]},{"id":"medic","label":"Recover medic's augment","kind":"recover","at":Vector2(2530,-80),"optional":true,"reward":"vitality"}],
	"objective_doors":[{"at":Vector2(5300,205),"size":Vector2(24,190),"requires":["generator"]}],"cache":Vector2(4020,-15),"archive":"CLINIC / The young medic remembers your name. You do not remember teaching it to her. She hands you the keys anyway.",
	"signs":[[Vector2(250,210),"CLINIC RESERVE ^ / POWER CELL EAST >"],[Vector2(1450,0),"GENERATOR [E] · CELL FROM ROOFS"],[Vector2(2940,-190),"POWER CELL [E]"],[Vector2(5300,140),"EVACUATION POD >"]],
	"route":[Vector2(710,180),Vector2(2570,-80),Vector2(3100,-145),Vector2(1590,50),Vector2(5550,180),Vector2(6355,300)]}
static func _tram()->Dictionary:
	return {"id":"city_tram_depot","level":1,"level_name":"CITY WITHOUT A MASTER","title":"THE SILENT TRAM","subtitle":"Electrical depot · roof connector · rail trench","width":7200,"top":-420,"theme":"city",
	"text":"A stalled tram blocks the civilian route. Route auxiliary current\nthrough the depot, then strike the welded brake housing in its upper cabin.\nLive rails flash before discharge; the service catwalk stays safe.","hint":"A routing console cycles three circuits. Its panel names the target. Jump the live strips or take the roofs.",
	"platforms":[Rect2(300,245,170,55),Rect2(550,180,280,18),Rect2(960,115,420,18),Rect2(1520,50,350,18),Rect2(2030,-15,410,18),Rect2(2600,-80,420,18),Rect2(3180,-145,410,18),Rect2(3750,-210,430,18),Rect2(4340,-145,400,18),Rect2(4900,-80,430,18),Rect2(5500,-15,400,18),Rect2(6060,50,430,18),Rect2(6650,145,300,18),Rect2(2200,240,200,60),Rect2(3700,235,240,65),Rect2(5050,240,200,60)],
	"ladders":[[700,300,120],[1700,300,250],[2800,300,380],[3400,300,445],[3910,235,445],[4550,300,445],[5730,300,315],[6780,300,155]],
	"enemies":[[1000,"sentinel",300],[1280,"sentry",115],[1860,"listener",300],[2280,"sentinel",-15],[2900,"sentry",-80],[3500,"listener",300],[4000,"sentry",-210],[4490,"sentinel",-145],[5070,"listener",300],[5700,"sentry",-15],[6290,"sentinel",50],[6800,"listener",300]],
	"props":[[780,300],[1640,50],[2500,300],[3330,-145],[4300,300],[5220,-80],[6200,50]],
	"objectives":[{"id":"schematic","label":"Recover depot circuit map","kind":"recover","at":Vector2(1710,50)},{"id":"auxiliary","label":"Route tram auxiliary current","kind":"route","target":2,"at":Vector2(3410,-145),"requires":["schematic"]},{"id":"brake","label":"Break the welded tram brake","kind":"breaker","at":Vector2(6250,50),"requires":["auxiliary"]}],
	"objective_doors":[{"at":Vector2(5900,210),"size":Vector2(24,180),"requires":["auxiliary"]}],
	"hazards":[{"at":Vector2(2460,294),"size":Vector2(100,12),"period":3.4},{"at":Vector2(4780,294),"size":Vector2(100,12),"period":3.9,"phase":1.0}],
	"cache":Vector2(3990,-210),"archive":"TRAM RECORD / The city used to run on timetables. Now every departure requires permission from above.","signs":[[Vector2(500,135),"SERVICE CATWALK ^ / ELECTRIFIED TRACK >"],[Vector2(3260,-190),"AUXILIARY TARGET: CIRCUIT 2"],[Vector2(6100,5),"BRAKE HOUSING"]],
	"route":[Vector2(1700,50),Vector2(3400,-145),Vector2(6250,50),Vector2(7155,300)]}
static func _archives()->Dictionary:
	return {"id":"city_records","level":1,"level_name":"CITY WITHOUT A MASTER","title":"RECORDS UNDER THE RAIN","subtitle":"Old squad archive · channel crossing · roof antenna","width":5600,"top":-500,"theme":"city",
	"text":"The gate calls you an intruder. The old municipal archive still\nknows your squad. Recover its proof and transmit it from the roof.\nChoose the exposed antenna steps or the sheltered service ladders.","hint":"You can bypass patrols. Physical crates make noise and can interrupt a dangerous lane.",
	"platforms":[Rect2(300,245,180,55),Rect2(570,180,320,18),Rect2(1050,115,320,18),Rect2(1530,50,340,18),Rect2(2030,-15,340,18),Rect2(2530,-80,360,18),Rect2(3040,-145,360,18),Rect2(3560,-210,360,18),Rect2(4080,-275,380,18),Rect2(4580,-210,350,18),Rect2(5060,-145,400,18),Rect2(2200,230,340,70),Rect2(3400,245,180,55)],
	"ladders":[[710,300,120],[1700,300,250],[2320,230,245],[2730,300,380],[3230,300,445],[4270,300,575],[5280,300,445]],"lifts":[[Vector2(3700,190),Vector2(0,-350),7.0]],
	"enemies":[[900,"sentinel",300],[1200,"sentry",115],[1800,"listener",300],[2230,"sentinel",-15],[2810,"listener",-80],[3280,"sentry",-145],[3750,"sentinel",-210],[4380,"sentry",-275],[4800,"listener",300],[5200,"sentinel",-145]],
	"props":[[650,180],[1400,300],[2120,-15],[2850,300],[3650,-210],[4700,300],[5320,-145]],
	"objectives":[{"id":"record","label":"Recover squad identity record","kind":"recover","at":Vector2(2320,230)},{"id":"antenna","label":"Transmit municipal clearance","kind":"install","at":Vector2(4300,-275),"requires":["record"]},{"id":"counterweight","label":"Load service counterweight","kind":"plate","at":Vector2(1460,300),"optional":true,"reward":"force"}],
	"cache":Vector2(3710,-210),"archive":"SQUAD PHOTOGRAPH / Five young faces surround the old one. The ink beneath each face has been crossed out and rewritten more than once.","signs":[[Vector2(1550,260),"RECORDS COURT >"],[Vector2(2190,180),"SQUAD RECORD [E]"],[Vector2(4070,-320),"ROOF TRANSMITTER >"]],
	"route":[Vector2(2320,230),Vector2(4270,-275),Vector2(5555,300)]}
static func _evacuation()->Dictionary:
	return {"id":"city_evac_spine","level":1,"level_name":"CITY WITHOUT A MASTER","title":"THE EVACUATION SPINE","subtitle":"Switchback terraces · refuge control · checkpoint approach","width":6800,"top":-460,"theme":"city",
	"text":"Before you enter the tower, give the city a way out.\nRecover the shelter keys, then open the eastern refuge.\nThe optional western refuge opens a sheltered service underpass.\nThe patrols can keep their posts. They cannot close these doors again.","hint":"East refuge is required. West rescue grants vitality and opens the floor underpass; the upper terraces remain open.",
	"platforms":[Rect2(320,245,180,55),Rect2(580,180,300,18),Rect2(1040,115,320,18),Rect2(1520,50,350,18),Rect2(2030,-15,350,18),Rect2(2540,-80,350,18),Rect2(3050,-145,350,18),Rect2(3560,-210,360,18),Rect2(4100,-145,360,18),Rect2(4640,-80,360,18),Rect2(5180,-15,360,18),Rect2(5720,50,360,18),Rect2(6260,115,360,18),Rect2(1920,245,200,55),Rect2(3910,80,270,30)],
	"ladders":[[720,300,120],[1710,300,250],[2710,300,380],[3230,300,445],[3750,300,510],[4270,300,445],[5370,300,315],[6400,300,185]],
	"enemies":[[970,"sentinel",300],[1350,"sentry",115],[2110,"listener",300],[2350,"sentinel",-15],[2830,"sentry",-80],[3500,"listener",300],[3800,"sentinel",-210],[4450,"sentry",300],[4900,"listener",-80],[5500,"sentinel",300],[5980,"sentry",50],[6500,"listener",115]],
	"props":[[840,300],[1690,50],[2430,300],[3120,-145],[4090,300],[4750,-80],[5840,50]],
	"objectives":[{"id":"keys","label":"Recover municipal shelter keys","kind":"recover","at":Vector2(3220,-145)},{"id":"west","label":"Open western refuge","kind":"rescue","at":Vector2(1700,50),"requires":["keys"],"optional":true,"reward":"vitality"},{"id":"east","label":"Open eastern refuge","kind":"rescue","at":Vector2(6400,115),"requires":["keys"]},{"id":"runner","label":"Recover runner's augment","kind":"recover","at":Vector2(3770,-210),"optional":true,"reward":"agility"}],
	"objective_doors":[{"at":Vector2(4000,190),"size":Vector2(24,220),"requires":["west"]}],
	"cache":Vector2(5370,-15),"archive":"REFUGE / You hear a child asking whether the old man is a soldier. Nobody answers. The doors open anyway.","signs":[[Vector2(1540,5),"OPTIONAL WEST REFUGE"],[Vector2(3070,-190),"SHELTER KEYS"],[Vector2(3750,255),"WEST REFUGE OPENS UNDERPASS / ROOFS ^"],[Vector2(6230,70),"EAST REFUGE"]],
	"route":[Vector2(3230,-145),Vector2(1700,50),Vector2(6400,115),Vector2(6755,300)]}
