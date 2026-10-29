extends RefCounted
## One cargo, one receiver: acquisition choices, real transport, final seating.
static func sector()->Dictionary:
	return {"id":"freight_lock","title":"04 / THE FREIGHT LOCK","subtitle":"Acquisition court • transfer deck • interlock","width":3000,"top":-260,"theme":"interior",
	"text":"The freight lock needs one intact delivery.\nClear the loading court or use its maintenance roof.\nMove the marked cargo along the transfer deck; seat it in the receiver.",
	"hint":"J strikes cargo. E replaces it only at the original cradle. Ordinary props make real noise; protect the marked delivery.",
	"platforms":[Rect2(330,100,310,18),Rect2(710,100,250,18),Rect2(1030,160,190,18),Rect2(600,210,30,90),Rect2(850,245,150,55),Rect2(1150,240,880,18),Rect2(1390,100,240,18),Rect2(1710,100,240,18),Rect2(1120,-260,1260,25),Rect2(2500,245,140,55)],
	"ladders":[[400,300,200],[1180,300,60],[1470,240,140],[1850,240,140]],
	"enemies":[[800,"listener",300],[925,"sentry",245],[1040,"sentinel",300],[1780,"listener",240]],
	"props":[[510,300],[790,100],[1450,100]],
	"freight":{"cradle":Vector2(1250,240),"receiver":Vector2(2110,270),"shutter":[Vector2(2294,20),Vector2(26,560)]},
	"signs":[[Vector2(160,265),"LOADING COURT >   MAINTENANCE ^"],[Vector2(460,245),"SPARE CRATE / NOISE"],[Vector2(730,65),"MAINTENANCE FLANK >"],[Vector2(1100,205),"MARKED DELIVERY >"],[Vector2(1370,205),"TRANSFER DECK >   PROTECT CARGO"],[Vector2(1800,205),"RECEIVER >"],[Vector2(1940,285),"LOST CARGO? RETURN TO CRADLE <"],[Vector2(2340,265),"INTERLOCK RELEASED >"]]}
