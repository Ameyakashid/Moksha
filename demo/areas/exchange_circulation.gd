extends RefCounted
## Existing physics assets; both relays required, order remains flexible.
static func sector()->Dictionary:
	return {"id":"exchange","title":"03 / THE EXCHANGE", "subtitle":"Pressure circuit and calibration return", "width":2600,"top":-250,"gate_y":175,"theme":"interior",
		"text":"THE EXCHANGE offers sight for speed. You may refuse.\nTwo circuits secure the exit. Pressure opens the lift access;\ncalibration opens the return bridge. The stairs remain available.",
		"hint":"E at station: choose sight trade. Lift or stairs reach calibration. W/S climbs the recovery ladder.",
		"platforms":[Rect2(650,245,150,55),Rect2(880,190,220,18),Rect2(1180,135,190,18),Rect2(1460,80,210,18),Rect2(1760,190,190,18),Rect2(2060,245,160,55),Rect2(2290,175,310,18),Rect2(1690,20,170,18),Rect2(1890,-40,220,18),Rect2(2075,175,230,18)],
		"enemies":[[1000,"listener",300],[1430,"listener",300],[1770,"listener",20],[1980,"sentry",-40],[2220,"sentinel",300],[2380,"listener",175]],
		"props":[[790,300],[1190,300],[1480,80],[1740,20],[2140,245]],"station":Vector2(430,300),"relays":[Vector2(1390,300),Vector2(1960,-40)],"cache":Vector2(1540,80),
		"archive":"CALIBRATION / Sight is only one account of the world.\nThese machines were built to make an absence useful.",
	"relay_labels":["PRESSURE","CALIBRATION"],
	"shutters":[[Vector2(1470,210),Vector2(24,180),0],[Vector2(2235,100),Vector2(24,200),1]],
	"lifts":[[Vector2(1540,285),Vector2(0,-210),6.0]],
	"ladders":[[1260,300,165]],
	"signs":[[Vector2(510,265),"PRESSURE >   STAIRS ^"],[Vector2(1290,265),"PRESSURE >"],[Vector2(1505,250),"LIFT ^"],[Vector2(1660,45),"CALIBRATION >"],[Vector2(1940,-75),"RETURN BRIDGE >"],[Vector2(1200,265),"RECOVERY ^"],[Vector2(2260,135),"EXIT >"]]}
