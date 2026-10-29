extends "res://demo/tests/warden_loops_review.gd"
## Explicit pre-clock right-sentry edge fixture, original health/stats unchanged.
func load_sector(index:int)->void:
 super.load_sector(index)
 if str(sectors[index].get("id",""))=="lift_warden":enemies[2].reset_at(Vector2(1245,245))
