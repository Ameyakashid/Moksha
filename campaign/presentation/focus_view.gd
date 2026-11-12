extends CanvasLayer
## Original white corner brackets: committed late opportunity, not auto-parry.
class Ink extends Node2D:
	var observer:WeakRef
	func _process(_dt:float)->void:queue_redraw()
	func _draw()->void:
		var source=observer.get_ref()
		if not is_instance_valid(source):return
		var transform=get_viewport().get_canvas_transform()
		for mark in source.visible_marks():
			var p:Vector2=transform*mark.center
			for side in [-1,1]:
				draw_polyline(PackedVector2Array([p+Vector2(side*10,-13),p+Vector2(side*16,-13),p+Vector2(side*16,-6)]),Color(1,.96,.78,.95),2,true)
				draw_polyline(PackedVector2Array([p+Vector2(side*10,13),p+Vector2(side*16,13),p+Vector2(side*16,6)]),Color(1,.96,.78,.95),2,true)
func bind(observer:Node)->void:
	layer=24
	var ink=Ink.new();ink.observer=weakref(observer);add_child(ink)
