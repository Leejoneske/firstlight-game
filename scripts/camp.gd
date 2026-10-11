class_name Camp
extends Node3D
## The family cave. Resting inside the ring of stones heals the family and slows
## hunger, and creatures won't follow them in.

const MOUND_CENTER := Vector3(0, 0, -6.0)

var radius := 7.0


func _ready() -> void:
	var rock := Color(0.55, 0.43, 0.33)
	var parts := [
		[MeshUtil.sphere(1.0, 12, 7), rock, MeshUtil.xf(MOUND_CENTER, Vector3(6.5, 4.2, 5.0))],
		[MeshUtil.sphere(1.0, 8, 5), rock.lightened(0.1), MeshUtil.xf(MOUND_CENTER + Vector3(-2.0, 3.0, -0.5), Vector3(2.4, 1.6, 2.0))],
		[MeshUtil.sphere(1.0, 8, 5), rock.darkened(0.12), MeshUtil.xf(MOUND_CENTER + Vector3(3.5, 1.2, 1.5), Vector3(2.2, 1.8, 2.0))],
		# Cave mouth
		[MeshUtil.sphere(1.0, 12, 6), Color(0.1, 0.07, 0.05), MeshUtil.xf(Vector3(0, 0.2, -1.4), Vector3(1.7, 2.2, 0.9))],
		# Sleeping furs
		[MeshUtil.sphere(1.0, 10, 4), Color(0.62, 0.45, 0.28), MeshUtil.xf(Vector3(-3.0, 0.02, 1.0), Vector3(1.1, 0.06, 0.6), Vector3(0, 0.3, 0))],
		[MeshUtil.sphere(1.0, 10, 4), Color(0.55, 0.4, 0.3), MeshUtil.xf(Vector3(3.0, 0.02, 1.2), Vector3(1.1, 0.06, 0.6), Vector3(0, -0.4, 0))],
		# Unlit fire pit: sticks in a ring of stones
		[MeshUtil.cylinder(0.04, 0.05, 1.1, 5), Color(0.45, 0.3, 0.18), MeshUtil.xf(Vector3(0, 0.12, 2.5), Vector3.ONE, Vector3(0, 0.5, PI / 2.0 - 0.15))],
		[MeshUtil.cylinder(0.04, 0.05, 1.1, 5), Color(0.4, 0.27, 0.16), MeshUtil.xf(Vector3(0, 0.12, 2.5), Vector3.ONE, Vector3(0, -0.6, PI / 2.0 - 0.15))],
	]
	for i in 9:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 9.0) * 0.7
		parts.append([MeshUtil.sphere(0.16, 6, 3), Color(0.5, 0.48, 0.45), MeshUtil.xf(Vector3(0, 0.08, 2.5) + offset)])
	# Pale stones marking the edge of the safe area
	for i in 28:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 28.0) * radius
		parts.append([MeshUtil.sphere(0.18, 5, 3), Color(0.9, 0.86, 0.78), MeshUtil.xf(offset + Vector3(0, 0.03, 0), Vector3(1.2, 0.5, 1.0))])
	# An artist-made model (models/cave.glb) replaces the placeholder shapes
	var custom := ModelLibrary.instantiate("cave")
	if custom:
		add_child(custom)
	else:
		var model := MeshInstance3D.new()
		model.mesh = MeshUtil.combine(parts)
		add_child(model)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 4.8
	cylinder.height = 8.0
	shape.shape = cylinder
	shape.position = MOUND_CENTER
	body.add_child(shape)
	add_child(body)

	var cave_label := MeshUtil.label("Family Cave", 48, Color(1, 0.95, 0.8))
	cave_label.position = MOUND_CENTER + Vector3(0, 5.2, 0)
	add_child(cave_label)
