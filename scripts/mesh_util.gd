class_name MeshUtil
## Helpers for building low-poly placeholder models out of simple shapes.

static var _materials := {}
static var _vertex_color_material: StandardMaterial3D


## A matte material of one colour. Materials are shared between models of the same colour.
static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		_materials[color] = mat
	return _materials[color]


## The material used by merged meshes, which carry their colours per vertex.
static func vertex_color_material() -> StandardMaterial3D:
	if _vertex_color_material == null:
		_vertex_color_material = StandardMaterial3D.new()
		_vertex_color_material.vertex_color_use_as_albedo = true
		_vertex_color_material.vertex_color_is_srgb = true
		_vertex_color_material.roughness = 0.95
	return _vertex_color_material


static func sphere(radius: float, segments := 8, rings := 5) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


static func cylinder(top_radius: float, bottom_radius: float, height: float, segments := 8) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func capsule(radius: float, height: float, segments := 8) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 2
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## A transform from a position, a local scale and a rotation in radians.
static func xf(position: Vector3, scale := Vector3.ONE, rotation := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rotation) * Basis.from_scale(scale), position)


## Adds a coloured shape as a child of `parent` and returns it. Use this for parts that move.
static func add_part(parent: Node3D, mesh: Mesh, color: Color, position := Vector3.ZERO,
		scale := Vector3.ONE, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.transform = xf(position, scale, rotation)
	parent.add_child(instance)
	return instance


## Merges shapes into one mesh with vertex colours, so a whole model is drawn in one go.
## Each part is [mesh: Mesh, color: Color, transform: Transform3D]. Meshes that already
## carry vertex colours keep them.
static func combine(parts: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		var mesh: Mesh = part[0]
		var arrays := (mesh as PrimitiveMesh).get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(0)
		var color: Color = part[1]
		var transform: Transform3D = part[2]
		var normal_basis := transform.basis.inverse().transposed()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in count:
			var index := indices[i] if not indices.is_empty() else i
			tool.set_color(colors[index] if not colors.is_empty() else color)
			tool.set_normal((normal_basis * normals[index]).normalized())
			tool.add_vertex(transform * vertices[index])
	var result := tool.commit()
	result.surface_set_material(0, vertex_color_material())
	return result


## Replaces the still shapes under `group` with one merged mesh, which is much faster to
## draw on phones. Nodes in `keep` (moving parts such as limbs or eyelids) stay separate.
static func merge_children(group: Node3D, keep: Array) -> MeshInstance3D:
	var parts := []
	_collect_parts(group, group, Transform3D.IDENTITY, keep, parts)
	if parts.is_empty():
		return null
	var merged := MeshInstance3D.new()
	merged.mesh = combine(parts)
	group.add_child(merged)
	return merged


static func _collect_parts(group: Node3D, node: Node3D, to_group: Transform3D, keep: Array, parts: Array) -> void:
	for child in node.get_children():
		if not child is Node3D or keep.has(child) or child is Label3D:
			continue
		var child_to_group: Transform3D = to_group * (child as Node3D).transform
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			var material := mesh_instance.material_override as StandardMaterial3D
			parts.append([mesh_instance.mesh, material.albedo_color if material else Color.WHITE, child_to_group])
		# Moving parts inside a still sub-group are moved up so they survive the merge
		for kept: Node in keep:
			if kept.get_parent() == child:
				kept.reparent(group)
		_collect_parts(group, child, child_to_group, keep, parts)
		child.free()


## A text label floating in the world that always faces the camera.
static func label(text: String, font_size := 40, color := Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.outline_size = 12
	label.pixel_size = 0.01
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.85)
	return label
