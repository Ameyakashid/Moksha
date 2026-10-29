extends RefCounted
## Terrain-only encounter composition. No controller/stat/roster changes.
static func sector()->Dictionary:
	return {"id":"lift_warden","title":"08 / THE LIFT WARDEN", "subtitle":"Crossfire and two maintenance loops", "width":1700,"top":-200,"theme":"interior",
		"text":"WARDEN: You taught us to hold this door.\nOPERATIVE: Then you know I can open it.",
		"hint":"Clear the sentries first or face the Warden below. Upper loops break firing lines; the floor stays connected.",
		"platforms":[Rect2(300,245,170,55),Rect2(610,190,200,18),Rect2(1110,245,140,18),Rect2(1380,245,160,55),Rect2(850,120,28,130),Rect2(890,135,150,18),Rect2(1250,190,130,18),Rect2(1280,150,28,100)],
		"enemies":[[770,"sentry",190],[960,"warden",300],[1125,"sentry",245]],"props":[[430,245],[680,300],[1270,300]],"lock":true}
