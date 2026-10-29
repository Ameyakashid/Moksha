extends RefCounted
## Two tactical approaches lead to a physical delivery, not an interaction marker.
static func sector()->Dictionary:
	return {"title":"04 / THE FREIGHT LOCK","subtitle":"Cargo interlock and maintenance flank","width":2200,"top":-260,"theme":"interior",
	"text":"The freight lock still weighs every delivery.\nSeat an intact crate in the receiver to release the sealed passage.\nFight through the loading lane or climb above its guards.",
	"hint":"J launches cargo. E at the cradle replaces lost cargo. W/S climbs ladders.",
	"platforms":[Rect2(330,100,310,18),Rect2(710,100,250,18),Rect2(1030,160,190,18),Rect2(850,245,150,55),Rect2(1150,240,126,60),Rect2(1120,-260,650,25)],
	"ladders":[[400,300,200]],
	"enemies":[[650,"listener",300],[925,"sentry",245],[1040,"sentinel",300]],
	"props":[[510,300],[790,100]],
	"freight":{"cradle":Vector2(1250,240),"receiver":Vector2(1496,270),"shutter":[Vector2(1680,20),Vector2(26,560)]},
	"signs":[[Vector2(250,270),"LOADING LANE >   MAINTENANCE ^"],[Vector2(1140,200),"J > CARGO    E REPLACE"],[Vector2(1730,270),"ONWARD >"]]}
