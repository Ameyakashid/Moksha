extends Node2D
func _ready():
 var scene=preload("res://demo/views/favela_backdrop.tscn").instantiate()
 scene.profile.room_bounds=Rect2(0,0,1280,680)
 scene.scale=Vector2(.5,.5)
 add_child(scene)
 var text:=Label.new();text.text="FAVELA / decorative hillside kit   •   no collision or gameplay authority"
 text.position=Vector2(18,18);text.modulate=Color("bdcdd0");add_child(text)
