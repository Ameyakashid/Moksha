extends Node2D
## Optional presentation adapter. Remove this node without changing the simulation.
## Parent at z=-5. Backdrop=-8 and terrain=-5 in world order; actors stay above.
const Themes = [
	preload("res://campaign/assets/themes/01_rainline.tres"),
	preload("res://campaign/assets/themes/02_foundry.tres"),
	preload("res://campaign/assets/themes/03_residences.tres"),
	preload("res://campaign/assets/themes/04_memory.tres"),
	preload("res://campaign/assets/themes/05_crown.tres")]
const ArcologyAtmosphere = preload("res://campaign/presentation/arcology_atmosphere.gd")
const Backdrop = preload("res://campaign/presentation/scenery_backdrop.gd")
const DistrictIdentity = preload("res://campaign/presentation/district_identity.gd")
const SurfaceSkin = preload("res://campaign/presentation/terrain_skin.gd")
var backdrop: Node2D
var terrain_paint: Node2D
var atmosphere: Node2D
var configured := false
var sight_enabled := true
var view_center := Vector2(320,180)
var view_size := Vector2(640,360)
func configure(data: Dictionary) -> void:
	configure_sector(data)
func configure_sector(data: Dictionary) -> void:
	# Reconfiguration is safe and does not retain the caller's mutable dictionary.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	atmosphere = null
	var width: float = maxf(1.0,float(data.get("width",640)))
	var top: float = minf(240.0,float(data.get("top",-100)))
	var level: int = clampi(int(data.get("level",1)),1,5)
	var palette: Resource = Themes[level-1]
	backdrop = Node2D.new()
	backdrop.set_script(Backdrop)
	backdrop.name = "Architecture"
	backdrop.bounds = Rect2(0,top-180,width,560-top)
	backdrop.theme = palette
	backdrop.identity = DistrictIdentity.profile_for(str(data.get("id","district")),palette.motif)
	backdrop.seed_value = int(backdrop.identity.seed)
	backdrop.landmark_origin = Vector2(clampf(float(data.get("spawn",Vector2(75,300)).x)+65.0+float(posmod(backdrop.seed_value,130)),24.0,maxf(24.0,width-170.0)),96.0+float(posmod(backdrop.seed_value/137,32)))
	backdrop.z_index = -3
	add_child(backdrop)
	# Opening inhabited city views are district-owned, entirely behind gameplay.
	if level == 1:
		atmosphere=ArcologyAtmosphere.new()
		atmosphere.name="InhabitedArcology"
		backdrop.add_child(atmosphere)
		atmosphere.configure({"id":str(data.get("id","district")),"width":width})
		atmosphere.set_view(view_center,view_size)
	terrain_paint = Node2D.new()
	terrain_paint.set_script(SurfaceSkin)
	terrain_paint.name = "ExactSurfaceSkins"
	terrain_paint.theme = palette
	var surfaces: Array[Rect2] = []
	var cursor := 0.0
	for gap in data.get("gaps",[]):
		var start: float = clampf(float(gap.x),cursor,width)
		if start > cursor: surfaces.append(Rect2(cursor,300,start-cursor,80))
		cursor = clampf(float(gap.y),start,width)
	if cursor < width: surfaces.append(Rect2(cursor,300,width-cursor,80))
	for platform in data.get("platforms",[]):
		if platform is Rect2 and platform.size.x > 0 and platform.size.y > 0:
			surfaces.append(platform)
	terrain_paint.surfaces = surfaces
	add_child(terrain_paint)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	configured = true
	set_sight_enabled(sight_enabled)
func set_sight_enabled(enabled: bool) -> void:
	# No peripheral city, light or reflected clue remains after the sight trade.
	sight_enabled = enabled
	visible = enabled
func update_view(camera_center: Vector2, viewport_size: Vector2) -> void:
	# Stable optional adapter API; static composition needs no camera tick.
	view_center = camera_center
	view_size = viewport_size
	if is_instance_valid(atmosphere):atmosphere.set_view(camera_center,viewport_size)
