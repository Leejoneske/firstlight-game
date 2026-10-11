class_name Scenery
extends Node3D
## Decorations that bring the badlands to life: towering rock spires and an arch,
## dry grass, pebbles, old bones, fallen logs, drifting clouds and, far away on the
## horizon, the glowing peak the family will one day travel to.

const SPIRE_COUNT := 12
const GRASS_COUNT := 2000
const PEBBLE_COUNT := 900
const BONE_COUNT := 7
const LOG_COUNT := 10
const CLOUD_COUNT := 22
const FIRSTLIGHT_POSITION := Vector3(-35, 0, -150)
const POND_CENTER := Vector2(44, -44)  ## An oasis pond in the hidden grove.
const POND_RADIUS := 5.0
const STAR_COUNT := 260

const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.3, 0.66, 0.66, 0.85);
uniform vec4 deep : source_color = vec4(0.08, 0.32, 0.46, 0.95);
void vertex() {
	VERTEX.y += sin(TIME * 1.4 + VERTEX.x * 1.6) * 0.025 + cos(TIME * 1.1 + VERTEX.z * 2.0) * 0.025;
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	vec3 color = mix(deep.rgb, shallow.rgb, smoothstep(0.3, 1.0, d));
	float ripple = sin(TIME * 2.0 + UV.x * 42.0) * sin(TIME * 1.6 + UV.y * 37.0);
	ALBEDO = color + ripple * 0.035;
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	ALPHA = d > 1.0 ? 0.0 : mix(deep.a, shallow.a * 0.6, smoothstep(0.8, 1.0, d));
}
"""

var terrain: Terrain
var half_size := 60.0
var is_free: Callable  ## func(point: Vector2, radius: float) -> bool, for spots without gameplay objects.

var _rng := RandomNumberGenerator.new()
var _taken: Array[Vector3] = []  ## x, z and radius of scenery already placed.
var _clouds: Node3D
var _ground_cover: Array[Node3D] = []
var _beacon: MeshInstance3D
var _stars: MultiMeshInstance3D
var _star_material: StandardMaterial3D
var _fireflies: CPUParticles3D


## Places the big landmarks. Call before placing gameplay objects, which should avoid them.
func build_landmarks(seed_value: int) -> void:
	_rng.seed = seed_value
	_add_arch(Vector2(-14, 16))
	for i in SPIRE_COUNT:
		var point := _find_spot(4.0, 14.0)
		if point != Vector2.INF:
			_add_spire(point)
	for i in BONE_COUNT:
		var point := _find_spot(2.0, 12.0)
		if point != Vector2.INF:
			_add_bones(point)
	for i in LOG_COUNT:
		var point := _find_spot(1.5, 10.0)
		if point != Vector2.INF:
			_add_log(point)
	_add_clouds()
	_add_firstlight()
	_add_pond()
	_add_stars()
	_add_fireflies()


## Scatters grass and pebbles. Call after gameplay objects are placed.
func build_ground_cover() -> void:
	_add_grass()
	_add_pebbles()


func set_ground_cover_visible(enabled: bool) -> void:
	for node in _ground_cover:
		node.visible = enabled


## True if a spot (x, z) with the given radius overlaps a landmark.
func blocks(point: Vector2, radius: float) -> bool:
	for other in _taken:
		if point.distance_to(Vector2(other.x, other.y)) < radius + other.z:
			return true
	return false


## 0 in daylight, 1 at full night: shows the stars and the grove's fireflies.
func set_darkness(darkness: float) -> void:
	_stars.visible = darkness > 0.05
	_star_material.albedo_color.a = clampf(darkness * 1.3 - 0.2, 0.0, 1.0)
	_fireflies.emitting = darkness > 0.4


func _process(delta: float) -> void:
	# Clouds drift slowly; the far peak's light gently pulses
	_clouds.position.x = fmod(_clouds.position.x + delta * 1.2 + 150.0, 300.0) - 150.0
	if _beacon:
		_beacon.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.0015) * 0.08)


# --- Landmarks ----------------------------------------------------------------

## A tall pillar of layered red rock, wider at the bottom, with a cap stone on top.
func _add_spire(point: Vector2) -> void:
	var height := _rng.randf_range(7.0, 15.0)
	var radius := _rng.randf_range(1.6, 2.6)
	var parts := []
	var y := 0.0
	var layers := int(height / 1.6)
	for i in layers:
		var t := float(i) / layers
		var layer_radius := radius * lerpf(1.0, 0.55, t) * _rng.randf_range(0.9, 1.1)
		var shade := Color(0.66, 0.4, 0.27) if i % 2 == 0 else Color(0.76, 0.5, 0.33)
		var offset := Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15))
		parts.append([MeshUtil.cylinder(layer_radius * 0.92, layer_radius, 1.7, 9), shade, MeshUtil.xf(Vector3(0, y + 0.85, 0) + offset)])
		y += 1.6
	# Cap stone
	parts.append([MeshUtil.sphere(radius * 0.85, 9, 5), Color(0.58, 0.36, 0.25), MeshUtil.xf(Vector3(0, y + 0.3, 0), Vector3(1.0, 0.45, 1.0))])
	# Fallen rubble around the base
	for i in 4:
		var angle := _rng.randf() * TAU
		var size := _rng.randf_range(0.35, 0.7)
		parts.append([MeshUtil.sphere(size, 6, 4), Color(0.66, 0.42, 0.29), MeshUtil.xf(Vector3(cos(angle), 0.15, sin(angle)) * (radius + 0.6), Vector3(1, 0.7, 1))])
	_add_solid(point, parts, radius, height)


## A natural stone arch to walk under, near the cave.
func _add_arch(center: Vector2) -> void:
	var parts := []
	var span := 7.0
	for side in [-1.0, 1.0]:
		for i in 5:
			var shade := Color(0.68, 0.42, 0.28) if i % 2 == 0 else Color(0.77, 0.51, 0.34)
			parts.append([MeshUtil.cylinder(1.0 - i * 0.06, 1.15 - i * 0.06, 1.5, 9), shade, MeshUtil.xf(Vector3(side * span / 2.0, 0.75 + i * 1.4, 0))])
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(-span / 2.0, span / 2.0, t)
		var y := 7.2 + sin(t * PI) * 1.4
		parts.append([MeshUtil.sphere(1.25, 8, 5), Color(0.72, 0.46, 0.3) if i % 2 == 0 else Color(0.64, 0.4, 0.27), MeshUtil.xf(Vector3(x, y, 0), Vector3(1.0, 0.75, 0.9))])
	var body := _add_model(center, parts, _rng.randf() * TAU)
	for side in [-1.0, 1.0]:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 1.15
		cylinder.height = 8.0
		shape.shape = cylinder
		shape.position = Vector3(side * span / 2.0, 4.0, 0)
		body.add_child(shape)
	_taken.append(Vector3(center.x, center.y, span / 2.0 + 2.0))


func _add_bones(point: Vector2) -> void:
	var bone := Color(0.93, 0.9, 0.8)
	var parts := []
	# Spine and ribs of some huge old creature
	parts.append([MeshUtil.cylinder(0.09, 0.09, 4.0, 6), bone, MeshUtil.xf(Vector3(0, 0.25, 0), Vector3.ONE, Vector3(PI / 2.0, 0, 0))])
	for i in 6:
		var z := -1.5 + i * 0.6
		for side in [-1.0, 1.0]:
			parts.append([MeshUtil.cylinder(0.05, 0.07, 1.6 - absf(i - 2.5) * 0.15, 5), bone,
				MeshUtil.xf(Vector3(side * 0.55, 0.75, z), Vector3.ONE, Vector3(0, 0, side * 0.55))])
	# Skull
	parts.append([MeshUtil.sphere(0.5, 8, 5), bone, MeshUtil.xf(Vector3(0, 0.4, -2.4), Vector3(0.9, 0.7, 1.2))])
	parts.append([MeshUtil.sphere(0.12, 6, 3), Color(0.25, 0.2, 0.17), MeshUtil.xf(Vector3(-0.22, 0.55, -2.75))])
	parts.append([MeshUtil.sphere(0.12, 6, 3), Color(0.25, 0.2, 0.17), MeshUtil.xf(Vector3(0.22, 0.55, -2.75))])
	_add_model(point, parts, _rng.randf() * TAU)
	_taken.append(Vector3(point.x, point.y, 2.0))


func _add_log(point: Vector2) -> void:
	var wood := Color(0.45, 0.32, 0.22)
	var length := _rng.randf_range(2.0, 3.5)
	var parts := [
		[MeshUtil.cylinder(0.25, 0.3, length, 8), wood, MeshUtil.xf(Vector3(0, 0.25, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))],
		[MeshUtil.cylinder(0.08, 0.1, 0.8, 5), wood.darkened(0.1), MeshUtil.xf(Vector3(length * 0.2, 0.55, 0.15), Vector3.ONE, Vector3(0.4, 0, -0.5))],
		[MeshUtil.cylinder(0.24, 0.24, 0.02, 8), Color(0.72, 0.58, 0.4), MeshUtil.xf(Vector3(length / 2.0 + 0.01, 0.25, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))],
	]
	_add_model(point, parts, _rng.randf() * TAU)
	_taken.append(Vector3(point.x, point.y, length / 2.0))


# --- Ground cover -------------------------------------------------------------

func _add_grass() -> void:
	var tuft := []
	for i in 4:
		var angle := i * TAU / 4.0 + 0.3
		tuft.append([MeshUtil.cylinder(0.0, 0.035, 0.5, 3), Color(0.72, 0.66, 0.36),
			MeshUtil.xf(Vector3(cos(angle) * 0.06, 0.22, sin(angle) * 0.06), Vector3.ONE, Vector3(sin(angle) * 0.35, 0, cos(angle) * 0.35))])
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var attempts := 0
	while transforms.size() < GRASS_COUNT and attempts < GRASS_COUNT * 6:
		attempts += 1
		var point := Vector2(_rng.randf_range(-half_size, half_size), _rng.randf_range(-half_size, half_size))
		var grassy := terrain.grassiness(point.x, point.y)
		if _rng.randf() > grassy * 0.9 + 0.05 or not is_free.call(point, 0.6):
			continue
		var size := _rng.randf_range(0.7, 1.4)
		transforms.append(MeshUtil.xf(_ground(point), Vector3(size, size * _rng.randf_range(0.8, 1.5), size), Vector3(0, _rng.randf() * TAU, 0)))
		var lush := terrain.grove_rect.has_point(point)
		colors.append(Color(0.55, 0.85, 0.45) if lush else Color(1.0, 0.95, 0.85).darkened(_rng.randf() * 0.2))
	_add_scatter(MeshUtil.combine(tuft), transforms, colors, 55.0)


func _add_pebbles() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in PEBBLE_COUNT:
		var point := Vector2(_rng.randf_range(-half_size, half_size), _rng.randf_range(-half_size, half_size))
		if not is_free.call(point, 0.4):
			continue
		var size := _rng.randf_range(0.06, 0.2)
		transforms.append(MeshUtil.xf(_ground(point), Vector3(size * 1.3, size * 0.7, size), Vector3(0, _rng.randf() * TAU, 0)))
		var shade := _rng.randf_range(0.45, 0.7)
		colors.append(Color(shade + 0.08, shade, shade - 0.05))
	_add_scatter(MeshUtil.sphere(1.0, 5, 3), transforms, colors, 40.0)


# --- Sky and horizon ----------------------------------------------------------

func _add_clouds() -> void:
	var puff := MeshUtil.sphere(1.0, 8, 5)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in CLOUD_COUNT:
		var center := Vector3(_rng.randf_range(-150, 150), _rng.randf_range(40, 60), _rng.randf_range(-150, 150))
		for j in _rng.randi_range(4, 7):
			var offset := Vector3(_rng.randf_range(-7, 7), _rng.randf_range(-1, 2), _rng.randf_range(-3, 3))
			var size := _rng.randf_range(3.0, 6.0)
			transforms.append(MeshUtil.xf(center + offset, Vector3(size * 1.4, size * 0.6, size)))
			colors.append(Color(1, 1, 1))
	_clouds = Node3D.new()
	add_child(_clouds)
	var instance := _add_multimesh(puff, transforms, colors, _clouds)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A small oasis in the hidden grove: rippling water, stones around the shore and reeds.
func _add_pond() -> void:
	var center := _ground(POND_CENTER)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * POND_RADIUS * 2.0
	plane.subdivide_width = 10
	plane.subdivide_depth = 10
	water.mesh = plane
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATER_SHADER
	material.shader = shader
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = center + Vector3(0, 0.12, 0)
	add_child(water)

	var parts := []
	for i in 22:
		var angle := i * TAU / 22.0 + _rng.randf_range(-0.08, 0.08)
		var size := _rng.randf_range(0.25, 0.5)
		parts.append([MeshUtil.sphere(size, 6, 4), Color(0.55, 0.52, 0.48).darkened(_rng.randf() * 0.2),
			MeshUtil.xf(Vector3(cos(angle), 0.05, sin(angle)) * (POND_RADIUS - 0.2), Vector3(1.2, 0.6, 1.0))])
	for i in 26:
		var angle := _rng.randf() * TAU
		var spot := Vector3(cos(angle), 0, sin(angle)) * (POND_RADIUS + _rng.randf_range(0.1, 0.9))
		var height := _rng.randf_range(0.6, 1.3)
		parts.append([MeshUtil.cylinder(0.0, 0.03, height, 3), Color(0.35, 0.58, 0.3),
			MeshUtil.xf(spot + Vector3(0, height / 2.0, 0), Vector3.ONE, Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2)))])
		if i % 4 == 0:
			parts.append([MeshUtil.capsule(0.05, 0.22), Color(0.45, 0.3, 0.18), MeshUtil.xf(spot + Vector3(0, height, 0))])
	var shore := MeshInstance3D.new()
	shore.mesh = MeshUtil.combine(parts)
	shore.position = center
	add_child(shore)
	_taken.append(Vector3(POND_CENTER.x, POND_CENTER.y, POND_RADIUS + 1.5))


func _add_stars() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in STAR_COUNT:
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.12, 1.0), _rng.randf_range(-1, 1)).normalized()
		var size := _rng.randf_range(0.25, 0.7)
		transforms.append(MeshUtil.xf(direction * 210.0, Vector3.ONE * size))
		colors.append(Color(1, 1, 1).lerp(Color(1.0, 0.9, 0.75), _rng.randf()))
	_stars = _add_multimesh(MeshUtil.sphere(1.0, 4, 2), transforms, colors)
	_star_material = StandardMaterial3D.new()
	_star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_material.vertex_color_use_as_albedo = true
	_star_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_material.set("disable_fog", true)
	_stars.material_override = _star_material
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stars.visible = false


## Glowing fireflies drifting over the grove at night.
func _add_fireflies() -> void:
	_fireflies = CPUParticles3D.new()
	_fireflies.amount = 36
	_fireflies.lifetime = 5.0
	_fireflies.preprocess = 5.0
	_fireflies.emitting = false
	_fireflies.mesh = MeshUtil.sphere(0.06, 5, 3)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.95, 0.45)
	_fireflies.material_override = glow
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var grove := terrain.grove_rect
	_fireflies.emission_box_extents = Vector3(grove.size.x / 2.0, 1.2, grove.size.y / 2.0)
	_fireflies.position = Vector3(grove.get_center().x, terrain.height_at(grove.get_center().x, grove.get_center().y) + 1.6, grove.get_center().y)
	_fireflies.gravity = Vector3.ZERO
	_fireflies.direction = Vector3.UP
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 0.1
	_fireflies.initial_velocity_max = 0.4
	_fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var blink := Curve.new()
	blink.add_point(Vector2(0.0, 0.0))
	blink.add_point(Vector2(0.2, 1.0))
	blink.add_point(Vector2(0.8, 1.0))
	blink.add_point(Vector2(1.0, 0.0))
	_fireflies.scale_amount_curve = blink
	add_child(_fireflies)


## A lone mountain far beyond the badlands with a warm light at its top: Firstlight,
## where the family is headed.
func _add_firstlight() -> void:
	var parts := []
	var base := FIRSTLIGHT_POSITION
	for i in 6:
		var t := i / 6.0
		var shade := Color(0.5, 0.4, 0.42).lerp(Color(0.62, 0.55, 0.6), t)
		parts.append([MeshUtil.cylinder(lerpf(26.0, 4.0, t + 0.16), lerpf(26.0, 4.0, t), 14.0, 10), shade, MeshUtil.xf(Vector3(0, 7.0 + i * 13.0, 0))])
	var mountain := MeshInstance3D.new()
	mountain.mesh = MeshUtil.combine(parts)
	mountain.position = base
	add_child(mountain)

	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.86, 0.45)
	glow.set("disable_fog", true)
	_beacon = MeshInstance3D.new()
	_beacon.mesh = MeshUtil.sphere(4.0, 12, 8)
	_beacon.material_override = glow
	_beacon.position = base + Vector3(0, 86, 0)
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beacon)
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.albedo_color = Color(1.0, 0.8, 0.4, 0.25)
	halo.set("disable_fog", true)
	var halo_mesh := MeshInstance3D.new()
	halo_mesh.mesh = MeshUtil.sphere(9.0, 12, 8)
	halo_mesh.material_override = halo
	halo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(halo_mesh)


# --- Helpers ------------------------------------------------------------------

func _ground(point: Vector2) -> Vector3:
	return Vector3(point.x, terrain.height_at(point.x, point.y), point.y)


## Finds an open spot at least `clearance` from gameplay objects and other scenery,
## and at least `min_from_camp` from the cave. Returns Vector2.INF if none was found.
func _find_spot(clearance: float, min_from_camp: float) -> Vector2:
	var limit := half_size - 8.0
	for attempt in 40:
		var point := Vector2(_rng.randf_range(-limit, limit), _rng.randf_range(-limit, limit))
		if terrain.grove_rect.grow(3.0).has_point(point) or point.length() < min_from_camp or not is_free.call(point, clearance):
			continue
		var clear := true
		for other in _taken:
			if point.distance_to(Vector2(other.x, other.y)) < clearance + other.z + 3.0:
				clear = false
				break
		if clear:
			return point
	return Vector2.INF


func _add_model(point: Vector2, parts: Array, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = _ground(point) - Vector3(0, 0.1, 0)
	body.rotation.y = yaw
	var mesh := MeshInstance3D.new()
	mesh.mesh = MeshUtil.combine(parts)
	body.add_child(mesh)
	add_child(body)
	return body


func _add_solid(point: Vector2, parts: Array, radius: float, height: float) -> void:
	var body := _add_model(point, parts, _rng.randf() * TAU)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position.y = height / 2.0
	body.add_child(shape)
	_taken.append(Vector3(point.x, point.y, radius + 1.0))


## Splits many small objects into map tiles so tiles off-screen or far away are skipped.
func _add_scatter(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], visible_range: float) -> void:
	const TILE := 20.0
	var tiles := {}
	for i in transforms.size():
		var origin := transforms[i].origin
		var key := Vector2i(floori(origin.x / TILE), floori(origin.z / TILE))
		if not tiles.has(key):
			tiles[key] = [[] as Array[Transform3D], [] as Array[Color]]
		tiles[key][0].append(transforms[i])
		tiles[key][1].append(colors[i])
	for key: Vector2i in tiles:
		var instance := _add_multimesh(mesh, tiles[key][0], tiles[key][1])
		_ground_cover.append(instance)
		instance.visibility_range_end = visible_range
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color],
		parent: Node3D = self) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = MeshUtil.vertex_color_material()
	parent.add_child(instance)
	return instance
