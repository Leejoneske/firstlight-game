class_name RockWall
extends StaticBody3D
## A wall of piled-up rocks between two points that nobody can walk through.

const THICKNESS := 1.6
const HEIGHT := 4.0

var from := Vector2.ZERO  ## Start point (x, z).
var to := Vector2.ZERO  ## End point (x, z).
var terrain: Terrain


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var segment := to - from
	var middle := (from + to) / 2.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(segment.length(), HEIGHT * 2.0, THICKNESS)
	shape.shape = box
	shape.position = Vector3(middle.x, terrain.height_at(middle.x, middle.y), middle.y)
	shape.rotation.y = -segment.angle()
	add_child(shape)

	# Many rocks drawn in one go with a MultiMesh
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from) ^ hash(to)
	var transforms: Array[Transform3D] = []
	var direction := segment.normalized()
	var side := Vector2(-direction.y, direction.x)
	var distance := 0.0
	while distance <= segment.length():
		for layer in 2:
			var point := from + direction * distance + side * rng.randf_range(-0.5, 0.5)
			var ground := terrain.height_at(point.x, point.y)
			var size := rng.randf_range(0.9, 1.4) * (1.0 - layer * 0.35)
			var scale := Vector3(size * rng.randf_range(0.9, 1.3), size * rng.randf_range(1.2, 2.2), size)
			var position := Vector3(point.x, ground + layer * 1.6 + scale.y * 0.3, point.y)
			transforms.append(MeshUtil.xf(position, scale, Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0)))
		distance += rng.randf_range(0.8, 1.3)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = MeshUtil.sphere(1.0, 6, 4)
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		var shade := rng.randf_range(-0.07, 0.07)
		multimesh.set_instance_color(i, Color(0.55 + shade, 0.46 + shade, 0.38 + shade))
	var rocks := MultiMeshInstance3D.new()
	rocks.multimesh = multimesh
	rocks.material_override = MeshUtil.vertex_color_material()
	add_child(rocks)
