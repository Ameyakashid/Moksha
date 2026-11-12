extends Node2D
## Original cosmetic cognitive mote; no bodies, input, light/reveal or authority.
func _draw()->void:
	draw_circle(Vector2.ZERO,3,Color("91d9d4"))
	draw_arc(Vector2.ZERO,6,.3,4.6,12,Color(.57,.85,.83,.45),1,true)
