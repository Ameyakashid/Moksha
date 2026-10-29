extends RefCounted
## Three connected traversal beats; existing supports, seven guards and one circuit.
static func sector()->Dictionary:
	return {"id":"cistern","title":"05 / THE CISTERN","subtitle":"Drainage approach • maintenance interchange • upper spillway","width":3600,"top":-940,"gate_y":-760,"theme":"interior",
	"text":"The upper spillway is sealed at flood control.\nTake the maintenance lifts or the fixed wall-side route.\nBeyond control, cross the exposed roof or recover through the sheltered channel.",
	"hint":"W/S climbs ladders. Jump from a lift onto a fixed landing. E restores flood control. Q reveals nearby supports.",
	"platforms":[
		Rect2(320,245,160,55),Rect2(550,190,180,18),Rect2(800,135,180,18),Rect2(1040,80,100,18),
		Rect2(780,280,200,18),Rect2(1260,145,160,18),
		Rect2(1480,60,200,18),Rect2(1710,0,210,18),Rect2(1940,-60,200,18),Rect2(2170,-120,220,18),
		Rect2(1940,-180,200,18),Rect2(1810,-240,200,18),Rect2(1770,-320,240,18),
		Rect2(1350,30,200,18),Rect2(1640,-245,160,18),Rect2(2010,-320,370,18),
		Rect2(2390,-430,210,18),Rect2(2650,-490,210,18),Rect2(2910,-550,210,18),Rect2(3170,-610,210,18),Rect2(3430,-670,150,18),Rect2(3460,-760,140,18),
		Rect2(2400,-200,210,18),Rect2(2660,-260,210,18),Rect2(2920,-320,210,18),Rect2(3180,-380,210,18),Rect2(3400,-440,180,18)],
	"lifts":[[Vector2(1000,300),Vector2(200,-160),6.0],[Vector2(1570,50),Vector2(0,-300),7.0]],
	"ladders":[[900,300,165],[1800,300,300],[2300,300,420],[2800,300,560],[3210,300,680],[3280,-380,230],[3500,-440,230]],
	"relay":Vector2(1880,-320),"relay_labels":["FLOOD CONTROL"],
	"shutters":[[Vector2(2140,-440),Vector2(24,240),0]],
	"enemies":[[600,"sentinel",190],[1300,"sentry",145],[1800,"listener",0],[1900,"sentinel",-320],[2700,"sentry",-490],[3020,"sentinel",-320],[3450,"listener",-670]],
	"props":[[400,245],[1350,145],[1770,0],[1980,-180],[3050,-320]],"cache":Vector2(3000,-320),
	"archive":"DRAINAGE MAP / The maintenance crews kept fixed landings between moving decks.\nWhen the upper spillway closed, the sheltered channel became the way home.",
	"signs":[[Vector2(170,265),"WALL ROUTE ^   MAINTENANCE >"],[Vector2(790,245),"LIFT >   MISSED? RECOVERY ^"],[Vector2(1250,110),"INTERCHANGE >"],[Vector2(1380,-5),"LIFT ^   FIXED STEPS >"],[Vector2(2180,-155),"FLOOD CONTROL < ^"],[Vector2(2180,-355),"SPILLWAY >"],[Vector2(2410,-465),"EXPOSED ROOF >   SHELTER BELOW"],[Vector2(2690,-295),"CACHE >   RECOVERY ^"],[Vector2(3190,-415),"ROOF ^   CHANNEL >"],[Vector2(3430,-795),"RELAY WORKS >"]]}
