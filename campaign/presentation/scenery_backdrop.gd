extends Node2D
## Background-only modular dressing. Nothing drawn here represents a support.
## Draws immutable district identity. It never reads actors, objective state or RNG.
const Identity = preload("res://campaign/presentation/district_identity.gd")
const Landmark = preload("res://campaign/presentation/district_landmark.gd")
var drawing_enabled := true
var bounds := Rect2(0, -100, 1600, 480)
var theme: Resource
var seed_value := 0
var identity: Dictionary = {}
var landmark_origin := Vector2(197, 94)
var skyline := preload("res://assets/environment/city-background-v1.png")
var wall := preload("res://assets/environment/wall_panel.tres")
var pipe := preload("res://assets/decor/exposed_pipe.tres")
var cable := preload("res://assets/decor/cable_bundle.tres")

func _draw() -> void:
	if not drawing_enabled or theme == null: return
	if identity.is_empty(): identity = Identity.profile_for("district", theme.motif)
	draw_rect(bounds, theme.background)
	if theme.motif in ["city", "crown"]:
		_draw_city()
	else:
		_draw_industrial_bays()
	_draw_landmarks()

func skyline_tiles() -> Array[Dictionary]:
	# Preserve the original pixels and their aspect ratio. A seeded horizontal
	# phase and bounded vertical source crop replace the same left edge every room.
	var result: Array[Dictionary] = []
	var image_size: Vector2 = skyline.get_size()
	var source_height := clampf(float(identity.get("skyline_height", 700.0)), 1.0, image_size.y)
	var source_y := clampf(float(identity.get("skyline_y", 96.0)), 0.0, image_size.y - source_height)
	var height := 300.0 - bounds.position.y
	var scale := height / source_height
	var tile_width := image_size.x * scale
	var offset := float(identity.get("skyline_phase", 0.0)) * tile_width
	var x := bounds.position.x - offset
	while x < bounds.end.x:
		# Crop both edge tiles to the room; no paint escapes its footprint.
		var left := maxf(x, bounds.position.x)
		var right := minf(x + tile_width, bounds.end.x)
		result.append({"destination": Rect2(left, bounds.position.y, right - left, height),
			"source": Rect2((left - x) / scale, source_y, (right - left) / scale, source_height)})
		x += tile_width
	return result

func _draw_city() -> void:
	var tint: float = float(identity.get("tint", 0.0))
	var color := Color(.47 + tint, .56 + tint, .61 + tint, 1)
	if theme.motif == "crown": color = Color(.46 + tint, .57 + tint, .62 + tint, 1)
	for tile in skyline_tiles():
		draw_texture_rect_region(skyline, tile.destination, tile.source, color)
		# A dark architectural joint masks the source plate's non-tileable seam.
		if tile.destination.position.x > bounds.position.x:
			draw_rect(Rect2(tile.destination.position.x - 3, bounds.position.y, 8, 300 - bounds.position.y), theme.background.darkened(.45))
	var span := float(identity.get("bay_width", 420.0))
	var offset := float(identity.get("rib_offset", 0.0))
	for index in range(ceili((bounds.size.x + offset) / span)):
		var x := index * span - offset
		# Glass mullions remain thin, vertical and well below gameplay contrast.
		draw_rect(Rect2(x, bounds.position.y, 7, 300 - bounds.position.y), theme.panel.darkened(.42))
		draw_line(Vector2(x + 7, bounds.position.y), Vector2(x + 7, 300), theme.edge.darkened(.65), 1)
		if theme.motif == "crown":
			draw_rect(Rect2(x + 8, bounds.position.y, span - 8, 300 - bounds.position.y), Color(theme.background, .13))
		for row in range(ceili((300 - bounds.position.y) / 320.0)):
			var y := 72.0 - row * 320.0
			if posmod(index + row + seed_value, 3) == 0:
				draw_texture_rect(cable, Rect2(x + 15, y, span - 40, 30), false, Color(.35, .42, .45, 1))
				_draw_practical(Vector2(x + span * .66, y + 39), 33, .018)
			elif posmod(index + row, 3) == 1:
				draw_texture_rect(wall, Rect2(x + 24, y + 38, 36, 56), false, Color(.35, .43, .47, 1))
			if theme.motif == "crown" and posmod(index + row + seed_value, 4) == 1:
				# Small recessed service hardware identifies the Crown's inner rooms
				# without turning the entire skyline into a repeated industrial wall.
				_equipment(Vector2(x + span - 121, y + 55), "duct", 1, .46)

func _draw_landmarks() -> void:
	if not bool(identity.get("authored", false)): return
	Landmark.paint(self, landmark_origin, identity, theme)
	# Sparse upper-wall repeat marks make a climb identifiable too. They are not
	# tied to objectives or passage positions and never advertise a usable door.
	var count := maxi(0, int(bounds.size.x / 1600.0))
	for i in range(count):
		var x := 920.0 + i * 1600.0 + float(posmod(seed_value + i * 79, 190))
		var tier := 1 + posmod(seed_value / 43 + i, maxi(1, int((220 - bounds.position.y) / 260.0)))
		var y := maxf(bounds.position.y + 28, 94.0 - tier * 260.0)
		if x + 98 < bounds.end.x: Landmark.paint(self, Vector2(x, y), identity, theme, true)

func _pipe(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, theme.background.darkened(.35), width + 3, true)
	draw_line(a, b, color, width, true)
	draw_line(a + Vector2(-width * .18, 0), b + Vector2(-width * .18, 0), color.lightened(.08), maxf(1, width * .14), true)

func _draw_practical(at: Vector2, width: float, spill: float) -> void:
	draw_rect(Rect2(at - Vector2(3, 3), Vector2(width + 6, 7)), theme.background.darkened(.35))
	draw_rect(Rect2(at, Vector2(width, 2)), theme.practical.darkened(.30))
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, 5), at + Vector2(width, 5), at + Vector2(width + 17, 61), at + Vector2(-17, 61)]), Color(theme.practical, spill))

func _draw_industrial_bays() -> void:
	var span := float(identity.get("bay_width", 384.0))
	var row := 0
	for bottom in range(300, int(bounds.position.y) - 1, -260):
		var roof := float(bottom - 252)
		# Staggered columns break the wallpaper grid while retaining architecture.
		var phase := float(posmod(seed_value / 19 + row * 113, 94))
		for index in range(ceili((bounds.size.x + phase) / span)):
			var x := index * span - phase
			var variant := posmod(seed_value / 7 + index * 17 + row * 31, 5)
			var kind := Identity.bay_kind(identity, index, row)
			draw_rect(Rect2(x + 14, roof + 14, span - 30, 232), theme.panel.darkened(.43))
			draw_rect(Rect2(x + 27, roof + 25, span - 55, 209), theme.background.lightened(.022))
			draw_rect(Rect2(x, roof, 12, 260), theme.background.darkened(.37))
			draw_rect(Rect2(x + 12, roof, 2, 260), theme.edge.darkened(.65))
			# Only thin wall seams, not bright horizontal ledges or false catwalks.
			draw_line(Vector2(x + 18, roof + 11), Vector2(x + span - 8, roof + 11), theme.panel.darkened(.13), 3)
			for bolt_y in [roof + 33, roof + 224]: draw_circle(Vector2(x + 6, bolt_y), 1.3, theme.edge.darkened(.38), true, -1, true)
			_pipe(Vector2(x + 21, roof + 36), Vector2(x + span - 17, roof + 36), 5, theme.panel.darkened(.03))
			var appliance_x := x + span - 68 if variant % 2 == 0 else x + 24
			draw_texture_rect(wall, Rect2(appliance_x, roof + 146, 34, 53), false, Color(.40, .46, .49, 1))
			# Large, dark, recessed equipment silhouettes are specific to this room's
			# purpose. The original wall appliance adds consistent textured material.
			var equipment_x := x + 33 if variant % 2 == 0 else x + span - 262
			_equipment(Vector2(equipment_x, roof + 67), kind, variant)
			_draw_practical(Vector2(x + 55 + float(variant) * 29, roof + 47), 40 + variant * 5, .022)
		row += 1

func _equipment(at: Vector2, kind: String, variant: int, scale := 1.0) -> void:
	draw_set_transform(at, 0, Vector2.ONE * scale)
	var plate: Color = theme.panel.darkened(.12)
	var edge: Color = theme.edge.darkened(.40)
	var recess: Color = theme.background.darkened(.28)
	var detail: Color = theme.edge.darkened(.18)
	match kind:
		"heat":
			_frame(Rect2(7, 4, 126, 143), recess, edge)
			draw_rect(Rect2(18, 16, 104, 106), Color("281e1b"))
			for slot in range(7):
				draw_rect(Rect2(27 + slot * 12, 28, 4, 76), Color("8e5b35"))
				draw_rect(Rect2(28 + slot * 12, 31, 1, 68), Color("b47a43"))
			_pipe(Vector2(170, -26), Vector2(170, 143), 12, Color("463b36"))
			for y in [18, 74, 126]: draw_rect(Rect2(161, y, 18, 5), theme.background)
		"power":
			_frame(Rect2(14, 8, 184, 137), recess, edge)
			for coil in range(3):
				var x := 35 + coil * 50
				draw_rect(Rect2(x, 25, 24, 93), plate)
				for rib in range(7): draw_rect(Rect2(x - 3, 30 + rib * 12, 30, 5), edge)
				draw_line(Vector2(x + 11, 14), Vector2(x + 11, 25), detail, 4)
				draw_line(Vector2(x + 11, 118), Vector2(x + 11, 137), detail, 4)
		"water":
			for tank in range(2 if variant % 2 == 0 else 3):
				var x := 20 + tank * 58
				draw_style_box(_rounded_panel(plate, 12), Rect2(x, 5, 43, 143))
				draw_rect(Rect2(x + 7, 12, 5, 128), Color(edge, .4))
				for y in [28, 88, 127]: draw_rect(Rect2(x - 3, y, 49, 5), edge)
				_pipe(Vector2(x + 22, -28), Vector2(x + 22, 5), 8, plate)
				for tick in 4: draw_rect(Rect2(x + 26, 53 + tick * 9, 3, 2), theme.accent.darkened(.57))
		"window", "refuge", "clinic":
			_frame(Rect2(5, 0, 160, 143), recess, edge)
			var source_x := float(200 + posmod(seed_value + variant * 197, 850))
			draw_texture_rect_region(skyline, Rect2(11, 6, 148, 131), Rect2(source_x, 210, 420, 430), Color(.20, .32, .35, 1))
			for x in [59, 110]: draw_rect(Rect2(x, 5, 3, 133), plate)
			draw_rect(Rect2(10, 73, 150, 3), plate)
			if kind in ["refuge", "clinic"]:
				# Warm recesses imply occupied architecture, never fake rescue pods.
				for x in [15, 65, 116]:
					draw_rect(Rect2(x, 12, 35, 54), Color(theme.practical.darkened(.6), .30))
					for line in 5: draw_line(Vector2(x, 17 + line * 9), Vector2(x + 34, 17 + line * 9), Color(plate, .6), 1)
				Landmark.mark(self, Vector2(199, 53), kind, theme.edge.darkened(.44))
			else:
				draw_texture_rect(pipe, Rect2(177, 90, 65, 25), false, Color(.4, .5, .52, 1))
		"records":
			_frame(Rect2(8, 0, 196, 148), recess, edge)
			for column in 4:
				for row in 5:
					var p := Vector2(15 + column * 46, 8 + row * 27)
					draw_rect(Rect2(p, Vector2(40, 22)), plate)
					draw_rect(Rect2(p + Vector2(11, 6), Vector2(18, 4)), detail.darkened(.12))
					draw_line(p + Vector2(14, 15), p + Vector2(26, 15), recess, 2)
		"rack":
			for rack in 2:
				var p := Vector2(13 + rack * 88, 0)
				_frame(Rect2(p, Vector2(80, 153)), recess, edge)
				for row in 8:
					var y := 9 + row * 17
					draw_rect(Rect2(p + Vector2(7, y), Vector2(66, 12)), plate)
					draw_line(p + Vector2(14, y + 7), p + Vector2(50, y + 7), edge, 1)
					draw_rect(Rect2(p + Vector2(61, y + 4), Vector2(3, 2)), theme.accent.darkened(.46 if (row + variant) % 4 == 0 else .72))
			draw_texture_rect(cable, Rect2(16, 153, 164, 22), false, Color(.35, .38, .45, 1))
		"shutter":
			_frame(Rect2(5, 1, 198, 146), recess, edge)
			for slat in 12:
				draw_rect(Rect2(13, 8 + slat * 11, 182, 8), plate.darkened(.08 if slat % 3 else .0))
				draw_line(Vector2(16, 8 + slat * 11), Vector2(191, 8 + slat * 11), Color(edge, .38), 1)
			# Fasteners across the face emphasize a wall shutter, not an exit door.
			for x in [37, 167]:
				draw_rect(Rect2(x, 8, 4, 128), edge.darkened(.12))
				for y in [23, 73, 126]: draw_circle(Vector2(x + 2, y), 2, recess)
		"press":
			_frame(Rect2(8, 0, 196, 151), recess, edge)
			for x in [28, 151]:
				draw_rect(Rect2(x, 11, 20, 128), plate)
				draw_rect(Rect2(x + 7, 18, 5, 111), detail.darkened(.15))
			draw_rect(Rect2(56, 9, 82, 35), edge.darkened(.08))
			draw_rect(Rect2(86, 45, 24, 49), plate.lightened(.05))
			draw_rect(Rect2(60, 94, 76, 17), edge)
			draw_rect(Rect2(56, 123, 84, 13), plate)
		"baffle":
			_frame(Rect2(6, 0, 196, 150), recess, edge)
			for fin in 11:
				var x := 17 + fin * 16
				draw_rect(Rect2(x, 11, 10, 128), plate.darkened(.08))
				draw_line(Vector2(x + 1, 12), Vector2(x + 1, 138), edge, 1)
		"loom":
			_frame(Rect2(5, 0, 201, 149), recess, edge)
			for reel in 2:
				var center := Vector2(57 + reel * 95, 49)
				draw_circle(center, 31, plate, true, -1, true)
				draw_circle(center, 22, recess, true, -1, true)
				draw_circle(center, 7, edge, true, -1, true)
				for spoke in 3:
					var dir := Vector2.from_angle(float(spoke) * TAU / 3 + variant * .2)
					draw_line(center + dir * 8, center + dir * 28, edge, 3, true)
				draw_line(center + Vector2(-8, 31), center + Vector2(-8, 69), edge, 2)
				draw_line(center + Vector2(8, 31), center + Vector2(8, 69), edge, 2)
			draw_rect(Rect2(26, 118, 159, 14), plate)
		"blank":
			for i in 3: draw_rect(Rect2(15 + i * 41, 22, 26, 3), Color(edge, .35))
			draw_texture_rect(cable, Rect2(8, 89, 192, 29), false, Color(.30, .35, .37, 1))
		_:
			_frame(Rect2(9, 18, 195, 104), recess, edge)
			for vent in 2:
				var center := Vector2(60 + vent * 90, 70)
				draw_circle(center, 36, plate, true, -1, true)
				for slat in 8:
					var y := -26.0 + slat * 7.5
					var half := sqrt(maxf(0, 30 * 30 - y * y))
					draw_line(center + Vector2(-half, y), center + Vector2(half, y), recess, 3)
				cable_to_wall(center + Vector2(0, 39), edge)
	draw_set_transform(Vector2.ZERO)

func cable_to_wall(at: Vector2, color: Color) -> void:
	draw_polyline(PackedVector2Array([at, at + Vector2(0, 22), at + Vector2(23, 22), at + Vector2(23, 39)]), color.darkened(.16), 3, true)

func _frame(rect: Rect2, fill: Color, edge: Color) -> void:
	draw_rect(rect.grow(4), theme.background.darkened(.42))
	draw_rect(rect, fill)
	draw_rect(rect.grow(-2), edge, false, 2)

func _rounded_panel(color: Color, radius: int) -> StyleBoxFlat:
	# This helper is called only when the canvas draw list is rebuilt, not per tick.
	var panel := StyleBoxFlat.new()
	panel.bg_color = color
	panel.set_corner_radius_all(radius)
	return panel
