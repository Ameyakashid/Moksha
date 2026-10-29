@tool
extends Resource
## Deliberately shared paint is allowed; duplicate to style instances separately.
@export var wall := Color("1b303a"):
 set(v): wall=v;emit_changed()
@export var outline := Color("59717a"):
 set(v): outline=v;emit_changed()
@export var inset := Color("0b1922"):
 set(v): inset=v;emit_changed()
@export var warm := Color("a08b70"):
 set(v): warm=v;emit_changed()
@export var neon := Color("70c1c3"):
 set(v): neon=v;emit_changed()
@export var cable := Color("52616b"):
 set(v): cable=v;emit_changed()
