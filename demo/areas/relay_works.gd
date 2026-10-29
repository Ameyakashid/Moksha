extends RefCounted
## Three distinct circuits, fixed alternatives and a real machine-to-dispatch link.
## Geometry/data only: existing shared physics, motors, actors and stats unchanged.
static func sector()->Dictionary:
	return {"id":"relay_works","title":"07 / RELAY WORKS","subtitle":"Service galleries • machine floors • dispatch district","width":6400,"top":-620,"theme":"interior","spawn":Vector2(2200,300),"station":Vector2(2200,300),
	"text":"Three crews left three independent circuits.\nService is west; machine floors rise above; Dispatch is east.\nLift power opens an elevated connection into Dispatch.",
	"hint":"Choose circuit order. Fixed ladders remain when shortcuts are closed. E restores relays; Q sounds landings. No guard-clear requirement.",
	"platforms":[
		# Service: overhead maintenance catwalk versus ground gallery and retaining wall.
		Rect2(550,80,230,18),Rect2(850,80,180,18),Rect2(1100,80,220,18),Rect2(1400,80,180,18),
		Rect2(1620,135,90,18),Rect2(1740,190,90,18),Rect2(1860,245,90,18),
		Rect2(800,245,80,55),Rect2(900,190,180,110),Rect2(1120,245,80,55),
		# Machine floors: two fixed working galleries, optional lift beside them.
		Rect2(2520,80,300,18),Rect2(2520,-140,300,18),Rect2(2850,-195,80,18),Rect2(2860,-250,200,18),
		Rect2(2660,245,90,18),Rect2(2780,240,200,18),Rect2(3070,-155,200,18),Rect2(3070,-430,420,18),
		# Lift-powered shortcut: a genuine elevated connection, not the return to hub.
		Rect2(3500,-240,800,18),
		# Dispatch high crossing and sheltered working galleries.
		Rect2(4400,-295,260,18),Rect2(4760,-240,260,18),Rect2(5120,-240,240,18),Rect2(5460,-240,260,18),
		Rect2(4200,135,600,18),Rect2(4900,80,420,18),
		Rect2(4520,180,24,70),Rect2(5180,180,24,70),
		# Both sides of the Dispatch shortcut retain an independent fixed return.
		Rect2(5560,80,220,18),Rect2(5840,80,320,18)],
	"relays":[Vector2(450,300),Vector2(3440,-430),Vector2(5520,-240)],
	"relay_labels":["SERVICE","LIFT","DISPATCH"],
	"shutters":[[Vector2(1500,205),Vector2(24,190),0],[Vector2(3800,-340),Vector2(24,280),1],[Vector2(5800,205),Vector2(24,190),2]],
	"ladders":[[1250,300,220],[2600,300,220],[2700,80,220],[3200,-155,275],[3520,300,540],[4220,300,540],[4320,300,165],[5000,300,220],[5520,300,540],[5630,300,220],[6000,300,220]],
	"lifts":[[Vector2(3000,260),Vector2(0,-420),7.0]],
	"enemies":[[440,"listener",300],[520,"sentinel",300],[750,"listener",80],[2600,"listener",80],[2800,"sentry",-140],[3150,"sentinel",-155],[3400,"sentry",-430],[4400,"sentry",135],[4700,"sentinel",135],[4950,"listener",80],[5220,"listener",80],[5580,"sentry",-240],[6100,"sentinel",300]],
	"props":[[300,300],[630,300],[710,80],[2650,80],[2580,-140],[3250,-155],[4050,300],[4460,135],[5090,80],[5940,300]],
	"cache":Vector2(2580,-140),"archive":"MAINTENANCE ORDER / Three circuits, three crews.\nThe machine gallery joins Dispatch above the flood shutters.\nThe crews kept the lower ladders; none of the crews owned the only way home.",
	"signs":[[Vector2(2070,235),"SERVICE <   MACHINES ^   DISPATCH >"],[Vector2(1720,155),"SERVICE CATWALK <"],[Vector2(1190,260),"CATWALK ^   HUB >"],[Vector2(1550,260),"SERVICE SHORTCUT"],[Vector2(2510,265),"FIXED MACHINE FLOORS ^"],[Vector2(2770,205),"LIFT BOARDING >"],[Vector2(3080,-185),"CONTROL ^"],[Vector2(3490,-275),"DISPATCH LINK >"],[Vector2(3660,260),"MACHINES <   DISPATCH >"],[Vector2(4170,265),"UPPER CROSSING ^"],[Vector2(4340,105),"SHELTERED GALLERY >"],[Vector2(4970,265),"GALLERY ^"],[Vector2(5440,265),"DISPATCH CONTROL ^"],[Vector2(5750,265),"EGRESS SHORTCUT >"],[Vector2(5990,265),"FIXED RETURN ^"],[Vector2(6230,250),"ONWARD >"]]}
