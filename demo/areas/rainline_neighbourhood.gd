extends RefCounted
## Three connected opening beats; one service badge, no combat-clear or time gates.
## All geometry and interactions use existing shared world assets.
static func sector() -> Dictionary:
	return {"id":"rainline","title":"01 / RAINLINE DISTRICT","subtitle":"Market • hillside homes • intake spine","width":6200,"top":-520,"theme":"city","backdrop_scene":preload("res://demo/views/favela_backdrop.tscn"),
	"text":"You wake beneath the rainline. The arcology has sealed its gates.\nThe badge relay is above the hillside homes: E activates it.\nCross the market by street or roof; recover it, then reach Intake.",
	"hint":"A/D move · Space jump / air jump · W/S ladders · J fresh-tap combo · K guard · E interact",
	"platforms":[
		Rect2(340,245,150,55),Rect2(560,190,230,18),Rect2(880,135,230,18),Rect2(1190,80,230,18),Rect2(1500,20,230,18),
		Rect2(1810,-40,230,18),Rect2(2120,-100,230,18),Rect2(2430,-160,230,18),Rect2(2740,-220,230,18),Rect2(3050,-280,230,18),Rect2(3360,-280,260,18),
		Rect2(1480,245,160,55),Rect2(1760,190,240,18),Rect2(2070,130,240,18),Rect2(2480,80,280,18),Rect2(2810,20,250,18),
		Rect2(3120,-100,240,18),Rect2(3400,-180,220,18),Rect2(3740,-100,260,18),Rect2(4090,-40,250,18),
		Rect2(4450,20,240,18),Rect2(4780,80,240,18),Rect2(5110,140,260,18),Rect2(5480,200,240,18),Rect2(5800,245,160,55),
		Rect2(3880,245,140,55),Rect2(4560,245,160,55),Rect2(5190,245,130,55)],
	"ladders":[[710,300,110],[1870,300,340],[2590,300,220],[3250,300,400],[3500,-180,100],[4200,300,340],[4900,300,220]],
	"lifts":[[Vector2(3970,220),Vector2(0,-230),6.0]],
	"relay":Vector2(3480,-280),"cache":Vector2(2530,-160),
	"shutters":[[Vector2(3680,200),Vector2(24,200),0]],
	"enemies":[[780,"sentinel",300],[865,"sentinel",300],[1090,"sentinel",135],[1630,"listener",300],
		[1990,"sentinel",-40],[2210,"sentry",-100],[2400,"listener",300],[2870,"sentinel",-220],[3100,"listener",300],
		[3530,"sentry",-180],[3900,"sentinel",300],[4350,"listener",300],[4560,"sentry",20],
		[4790,"sentinel",300],[4880,"sentinel",300],[5300,"sentry",140],[5650,"listener",300]],
	"props":[[620,300],[940,300],[1300,80],[1680,300],[2140,130],[2540,300],[2920,20],[3160,300],[3820,-100],[4050,300],[4490,20],[4750,300],[5030,300],[5520,200],[5870,300]],
	"archive":"HILLSIDE FIELD NOTE / The market medic moved the spare kit above the homes.\nYour squad once carried supplies up these ladders.\nThe badge still releases the maintenance passage; the people kept another way over.",
	"signs":[[Vector2(130,230),"MARKET  >   ROOF  ^"],[Vector2(590,155),"ROOFTOP WALK >"],[Vector2(1510,260),"HILLSIDE COURT >"],
		[Vector2(1880,250),"ROOF / RECOVERY ^"],[Vector2(2180,-135),"MEDIC CACHE >"],[Vector2(2540,260),"MAINTENANCE >   HOMES ^"],
		[Vector2(3160,250),"BADGE ^"],[Vector2(3380,-315),"BADGE RELAY [E]"],[Vector2(3520,260),"BADGE OPENS SHORTCUT >"],
		[Vector2(3860,200),"INTAKE >   HOMES <"],[Vector2(4210,250),"ROOF SPINE ^ / STREET >"],[Vector2(4810,255),"RECOVERY ^"],[Vector2(5720,190),"QUARANTINE INTAKE >"]]}
