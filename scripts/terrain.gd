class_name Terrain
extends StaticBody3D
## Low-poly rolling badlands. Hills are gentle in the play area and rise into
## mountains around the edge. The ground around the camp is flattened.

const CELL := 2.0  ## Metres between height samples.
const BORDER := 30.0  ## Width of the mountain belt outside the play area.

var half_size := 60.0  ## Half the width of the play area.
var flat_spots: Array[Vector3] = []  ## x, z and radius of areas kept flat.
var grove_rect := Rect2()  ## Area (x, z) coloured as green grove.

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _extent := 0.0
var _samples := 0
var _heights := PackedFloat32Array()


func build(seed_value: int) -> void:
	_noise.seed = seed_value
	_noise.frequency = 0.018
	_detail.seed = seed_value + 1
	_detail.frequency = 0.09
	_extent = half_size + BORDER
	_samples = int(_extent * 2.0 / CELL) + 1
	_heights.resize(_samples * _samples)
	for iz in _samples:
		for ix in _samples:
			_heights[iz * _samples + ix] = _shape_height(-_extent + ix * CELL, -_extent + iz * CELL)
	collision_layer = 1
	collision_mask = 0
	_build_mesh()
	_build_collision()


## Ground height at a point, matching the terrain mesh.
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + _extent) / CELL, 0.0, _samples - 1.001)
	var fz := clampf((z + _extent) / CELL, 0.0, _samples - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := _heights[iz * _samples + ix]
	var h10 := _heights[iz * _samples + ix + 1]
	var h01 := _heights[(iz + 1) * _samples + ix]
	var h11 := _heights[(iz + 1) * _samples + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _shape_height(x: float, z: float) -> float:
	var height := _noise.get_noise_2d(x, z) * 2.4 + _detail.get_noise_2d(x, z) * 0.35
	for spot in flat_spots:
		var distance := Vector2(x, z).distance_to(Vector2(spot.x, spot.y))
		height *= smoothstep(spot.z, spot.z + 8.0, distance)
	var past_edge := maxf(absf(x), absf(z)) - half_size + 4.0
	if past_edge > 0.0:
		height += pow(past_edge, 1.45) * 0.9 + _detail.get_noise_2d(x * 0.5, z * 0.5) * past_edge * 0.25
	return height


func _build_mesh() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in _samples - 1:
		for ix in _samples - 1:
			var x0 := -_extent + ix * CELL
			var z0 := -_extent + iz * CELL
			var v00 := Vector3(x0, _heights[iz * _samples + ix], z0)
			var v10 := Vector3(x0 + CELL, _heights[iz * _samples + ix + 1], z0)
			var v01 := Vector3(x0, _heights[(iz + 1) * _samples + ix], z0 + CELL)
			var v11 := Vector3(x0 + CELL, _heights[(iz + 1) * _samples + ix + 1], z0 + CELL)
			_add_face(tool, v00, v10, v01)
			_add_face(tool, v10, v11, v01)
	var mesh := tool.commit()
	mesh.surface_set_material(0, MeshUtil.vertex_color_material())
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)


## Adds one flat-shaded triangle, coloured by where it is and how steep it is.
func _add_face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.y < 0.0:
		normal = -normal
	var center := (a + b + c) / 3.0
	var jitter := (hash(Vector2i(int(center.x * 7.0), int(center.z * 7.0))) % 100) / 100.0 - 0.5
	var color := Color(0.78, 0.6, 0.4)
	if grove_rect.has_point(Vector2(center.x, center.z)):
		color = Color(0.45, 0.62, 0.3)
	if normal.y < 0.8 or center.y > 6.0:
		color = Color(0.6, 0.47, 0.36).lerp(Color(0.52, 0.48, 0.45), clampf(center.y / 30.0, 0.0, 1.0))
	color = color.lightened(jitter * 0.12) if jitter > 0.0 else color.darkened(-jitter * 0.12)
	tool.set_color(color)
	tool.set_normal(normal)
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


func _build_collision() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = _samples
	shape.map_depth = _samples
	var data := PackedFloat32Array()
	data.resize(_heights.size())
	for i in _heights.size():
		data[i] = _heights[i] / CELL
	shape.map_data = data
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3.ONE * CELL
	add_child(collision)

	# Invisible walls at the edge of the play area, in case anyone climbs the slopes
	for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 80.0, half_size * 2.0 + 4.0) if side.x != 0.0 else Vector3(half_size * 2.0 + 4.0, 80.0, 2.0)
		wall.shape = box
		wall.position = side * (half_size + 1.0)
		add_child(wall)
