extends RefCounted
## Four connected neighbourhood beats; traversal, not another circuit/kill gate.
static func sector()->Dictionary:
	return {"id":"upper_residential_crossing","title":"06 / UPPER RESIDENTIAL CROSSING","subtitle":"Spillway court • stacked homes • transit roofs • Works approach","width":5200,"top":-360,"gate_y":-85,"theme":"city","backdrop_scene":preload("res://demo/views/favela_backdrop.tscn"),
	"text":"The spillway emerges above the hillside homes.\nService terraces cross three retaining walls; roofs offer another route.\nReach Relay Works. The lower-court supply cache is optional.",
	"hint":"A/D move · Space jump / air jump · W/S ladders · Q maps landings. Neither guards nor supplies seal this crossing.",
	"platforms":[
		Rect2(160,245,80,18),Rect2(250,190,90,18),Rect2(320,135,480,18),Rect2(760,80,160,18),
		Rect2(900,25,500,18),Rect2(1500,-30,500,18),Rect2(2100,-30,500,18),Rect2(2700,25,450,18),Rect2(3250,-30,400,18),Rect2(3750,-85,450,18),Rect2(4300,-30,450,18),Rect2(4850,-85,350,18),
		Rect2(960,245,80,55),Rect2(1100,190,160,110),Rect2(1320,245,80,55),
		Rect2(2090,245,80,55),Rect2(2190,190,70,110),Rect2(2280,135,170,165),Rect2(2480,190,70,110),Rect2(2580,245,80,55),
		Rect2(3400,245,80,55),Rect2(3500,190,80,110),Rect2(3640,120,150,180),Rect2(3830,190,80,110),Rect2(3950,245,80,55)],
	"ladders":[[550,300,165],[1300,300,275],[2730,300,275],[3370,300,330],[4100,300,385],[5050,300,385]],
	"enemies":[[680,"sentinel",300],[1110,"sentry",25],[1650,"listener",300],[2340,"sentinel",135],[2750,"listener",300],[3510,"sentry",190],[4200,"listener",300],[4480,"sentry",-30],[4950,"sentinel",-85]],
	"props":[[460,300],[1550,300],[1850,-30],[2810,300],[3220,300],[4000,245],[4590,-30]],
	"cache":Vector2(2940,300),
	"archive":"RESIDENTS' NOTE / Supplies stay below the transit roofs.\nThe retaining walls were built for the hillside, not the guards.\nThe old ladders still connect both sides of the neighbourhood.",
	"signs":[[Vector2(120,220),"SPILLWAY COURT >"],[Vector2(510,265),"ROOFS ^   SERVICE TERRACES >"],[Vector2(940,210),"FIRST RETAINING WALL >"],[Vector2(1420,265),"STACKED HOMES >"],[Vector2(1570,-65),"TRANSIT ROOFS >"],[Vector2(2030,265),"SERVICE STEPS >"],[Vector2(2680,265),"ROOFS ^   SUPPLIES >"],[Vector2(2910,250),"OPTIONAL SUPPLIES"],[Vector2(3290,265),"TRANSIT CROSSING >   ROOFS ^"],[Vector2(4020,210),"WORKS APPROACH >   RECOVERY ^"],[Vector2(4910,265),"RELAY WORKS ^"],[Vector2(4890,-120),"RELAY WORKS >"]]}
