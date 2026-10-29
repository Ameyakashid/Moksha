@tool
extends Resource
const Paint=preload("res://demo/views/favela_appearance.gd")
@export_range(70,200,1) var block_spacing:=115.0:
 set(v):block_spacing=v;emit_changed()
@export_range(0,1,.01) var neon_amount:=0.3:
 set(v):neon_amount=v;emit_changed()
@export var sky:=Color("08131e"):
 set(v):sky=v;emit_changed()
@export var appearance:Paint:
 set(v):
  if appearance!=null and appearance.changed.is_connected(_paint_changed):appearance.changed.disconnect(_paint_changed)
  appearance=v
  if appearance!=null and not appearance.changed.is_connected(_paint_changed):appearance.changed.connect(_paint_changed)
  emit_changed()
func _paint_changed():emit_changed()
func is_valid()->bool:
 return is_finite(block_spacing) and block_spacing>=70 and is_finite(neon_amount)
