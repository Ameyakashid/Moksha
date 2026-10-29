extends "res://demo/tests/warden_loops_review.gd"
## Explicit pre-clock edge-contact fixture. No setup during measured traversal.
func load_sector(index:int)->void:
 super.load_sector(index)
 if str(sectors[index].get("id",""))=="lift_warden":
  player.reset_actor(Vector2(780,190),1)
  enemies[0].reset_at(Vector2(805,190))
