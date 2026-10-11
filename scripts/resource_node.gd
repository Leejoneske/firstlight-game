class_name ResourceNode
extends StaticBody3D
## Something the family can gather from: bushes, trees, rocks and boulders.
## Some need a particular talent: boulders need strength, tall trees need a climber.

enum Kind { BERRY_BUSH, TREE, ROCK, BOULDER, TALL_TREE }

## regrow < 0 means the resource is gone for good once used up. Radius is in metres.
const DATA := {
	Kind.BERRY_BUSH: {"item": "berries", "amount": 2, "uses": 3, "regrow": 60.0, "radius": 0.7, "solid": false, "verb": "Pick berries"},
	Kind.TREE: {"item": "sticks", "amount": 1, "uses": 4, "regrow": 90.0, "radius": 0.35, "solid": true, "verb": "Gather sticks"},
	Kind.ROCK: {"item": "stones", "amount": 1, "uses": 3, "regrow": 120.0, "radius": 0.5, "solid": true, "verb": "Collect stones"},
	Kind.BOULDER: {"item": "stones", "amount": 5, "uses": 1, "regrow": -1.0, "radius": 1.15, "solid": true, "verb": "Smash boulder"},
	Kind.TALL_TREE: {"item": "fruit", "amount": 2, "uses": 2, "regrow": 90.0, "radius": 0.4, "solid": true, "verb": "Climb for fruit"},
}

const MODEL_NAMES := {
	Kind.BERRY_BUSH: "berry_bush", Kind.TREE: "tree", Kind.ROCK: "rock",
	Kind.BOULDER: "boulder", Kind.TALL_TREE: "tall_tree",
}

## Meshes are built once per kind and shared by every resource of that kind.
static var _mesh_cache := {}

var kind := Kind.BERRY_BUSH
var is_gate := false  ## The boulder blocking the hidden grove.
var radius := 0.5
var uses_left := 0

var _regrow_timer := 0.0
var _shake := 0.0
var _shape: CollisionShape3D
var _visual: Node3D
var _main_mesh: MeshInstance3D
var _extra_mesh: MeshInstance3D  ## Berries, fruit or leaves that change as it's used.


func _ready() -> void:
	var data: Dictionary = DATA[kind]
	radius = data.radius
	uses_left = data.uses
	collision_layer = 1
	collision_mask = 0
	if data.solid:
		_shape = CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = 3.0
		_shape.shape = cylinder
		_shape.position.y = 1.5
		add_child(_shape)

	_visual = Node3D.new()
	_visual.rotation.y = randf() * TAU
	_visual.scale = Vector3.ONE * randf_range(0.9, 1.12)
	add_child(_visual)
	# An artist-made model (models/berry_bush.glb etc.) replaces the placeholder shapes
	var custom := ModelLibrary.instantiate(MODEL_NAMES[kind])
	if custom:
		_visual.add_child(custom)
		return
	_main_mesh = MeshInstance3D.new()
	_main_mesh.mesh = _cached_mesh("main")
	_main_mesh.visibility_range_end = 75.0
	_visual.add_child(_main_mesh)
	_extra_mesh = MeshInstance3D.new()
	_extra_mesh.visibility_range_end = 75.0
	_visual.add_child(_extra_mesh)
	_update_look()


func is_available() -> bool:
	return uses_left > 0


func can_use(member: FamilyMember) -> bool:
	match kind:
		Kind.BOULDER:
			return member.strength >= 2
		Kind.TALL_TREE:
			return member.can_climb
	return true


func action_name(member: FamilyMember) -> String:
	var verb: String = DATA[kind].verb
	if can_use(member):
		return verb
	if kind == Kind.BOULDER:
		return verb + " (needs someone strong)"
	return verb + " (needs a climber)"


## Gathers from this resource. Returns {"item", "amount"} on success, and/or {"message"}.
func interact(member: FamilyMember) -> Dictionary:
	if not is_available():
		return {}
	_shake = 0.35
	set_process(true)
	if not can_use(member):
		if kind == Kind.BOULDER:
			return {"message": "Too heavy for %s. Switch to someone stronger!" % member.member_name}
		return {"message": "Too high for %s to climb. Switch to a climber!" % member.member_name}
	var data: Dictionary = DATA[kind]
	var result := {"item": data.item, "amount": data.amount}
	uses_left -= 1
	if uses_left <= 0:
		if is_gate:
			result["message"] = "The boulder shatters... there's a hidden grove behind it!"
		_deplete()
	_update_look()
	return result


func _deplete() -> void:
	var regrow: float = DATA[kind].regrow
	if regrow < 0.0:
		queue_free()
		return
	_regrow_timer = regrow
	if kind == Kind.ROCK:
		visible = false
		_shape.set_deferred("disabled", true)


func _process(delta: float) -> void:
	if _shake <= 0.0 and uses_left > 0:
		set_process(false)  # Nothing to animate or regrow
		return
	if _shake > 0.0:
		_shake -= delta
		_visual.rotation.z = sin(_shake * 50.0) * 0.06 * _shake / 0.35
	if uses_left <= 0:
		_regrow_timer -= delta
		if _regrow_timer <= 0.0:
			uses_left = DATA[kind].uses
			visible = true
			if _shape:
				_shape.set_deferred("disabled", false)
			_update_look()


## Shows how much is left: berries and fruit disappear as they're picked.
func _update_look() -> void:
	if _extra_mesh == null:
		return
	match kind:
		Kind.BERRY_BUSH, Kind.TALL_TREE:
			_extra_mesh.mesh = _cached_mesh("fruit_%d" % uses_left) if uses_left > 0 else null
		Kind.TREE:
			_extra_mesh.mesh = _cached_mesh("leaves" if uses_left > 0 else "bare")


func _cached_mesh(variant: String) -> Mesh:
	var key := "%d_%s" % [kind, variant]
	if not _mesh_cache.has(key):
		_mesh_cache[key] = _build_mesh(variant)
	return _mesh_cache[key]


func _build_mesh(variant: String) -> Mesh:
	var parts := []
	match kind:
		Kind.BERRY_BUSH:
			if variant == "main":
				var green := Color(0.33, 0.52, 0.24)
				for blob in [Vector4(-0.35, 0.35, 0.1, 0.45), Vector4(0.35, 0.35, -0.1, 0.45), Vector4(0, 0.6, 0, 0.5), Vector4(0, 0.35, 0.35, 0.4)]:
					parts.append([MeshUtil.sphere(blob.w, 8, 5), green if blob.y < 0.5 else green.darkened(0.1), MeshUtil.xf(Vector3(blob.x, blob.y, blob.z))])
			else:
				var count := int(variant.get_slice("_", 1)) * 4
				for i in count:
					var angle := i * 2.4
					var height := 0.3 + fmod(i * 0.37, 0.5)
					var point := Vector3(cos(angle) * 0.62, height, sin(angle) * 0.62) * Vector3(1, 1, 1)
					if i % 3 == 0:
						point = Vector3(cos(angle) * 0.3, 0.95, sin(angle) * 0.3)
					parts.append([MeshUtil.sphere(0.07, 6, 3), Color(0.85, 0.1, 0.18), MeshUtil.xf(point)])
		Kind.TREE:
			var trunk := Color(0.42, 0.28, 0.17)
			if variant == "main":
				parts.append([MeshUtil.cylinder(0.12, 0.2, 2.2, 7), trunk, MeshUtil.xf(Vector3(0, 1.1, 0))])
				parts.append([MeshUtil.cylinder(0.05, 0.09, 1.0, 5), trunk, MeshUtil.xf(Vector3(-0.35, 2.0, 0), Vector3.ONE, Vector3(0, 0, 0.7))])
				parts.append([MeshUtil.cylinder(0.05, 0.09, 1.0, 5), trunk, MeshUtil.xf(Vector3(0.3, 2.2, 0.1), Vector3.ONE, Vector3(0.2, 0, -0.6))])
			else:
				var leaves := Color(0.5, 0.56, 0.28) if variant == "leaves" else Color(0.62, 0.52, 0.34)
				var size := 1.0 if variant == "leaves" else 0.65
				for blob in [Vector3(-0.7, 2.5, 0), Vector3(0.65, 2.7, 0.15), Vector3(0, 3.0, -0.1), Vector3(0, 2.6, 0.55)]:
					parts.append([MeshUtil.sphere(0.6 * size, 7, 4), leaves, MeshUtil.xf(blob)])
		Kind.ROCK:
			var grey := Color(0.56, 0.53, 0.5)
			parts.append([MeshUtil.sphere(0.5, 6, 4), grey, MeshUtil.xf(Vector3(0, 0.2, 0), Vector3(1.0, 0.65, 0.85))])
			parts.append([MeshUtil.sphere(0.22, 5, 3), grey.lightened(0.1), MeshUtil.xf(Vector3(0.45, 0.1, 0.2))])
		Kind.BOULDER:
			var stone := Color(0.5, 0.45, 0.4)
			parts.append([MeshUtil.sphere(1.2, 7, 5), stone, MeshUtil.xf(Vector3(0, 0.85, 0), Vector3(1.0, 0.85, 0.95), Vector3(0.1, 0, 0.15))])
			parts.append([MeshUtil.sphere(0.5, 6, 4), stone.darkened(0.15), MeshUtil.xf(Vector3(0.8, 0.3, 0.5))])
			parts.append([MeshUtil.sphere(0.35, 5, 3), stone.lightened(0.1), MeshUtil.xf(Vector3(-0.3, 1.75, -0.2))])
		Kind.TALL_TREE:
			var top := Vector3(0.3, 5.4, 0)
			if variant == "main":
				var trunk := Color(0.5, 0.36, 0.22)
				for i in 6:
					var t := i / 6.0
					var center := Vector3(0.3 * t * t, 0.45 + i * 0.9, 0)
					parts.append([MeshUtil.cylinder(0.15, 0.2, 0.92, 7), trunk if i % 2 == 0 else trunk.darkened(0.12), MeshUtil.xf(center, Vector3.ONE, Vector3(0, 0, -0.06 * i))])
				var frond := Color(0.3, 0.6, 0.3)
				for i in 7:
					var yaw := i * TAU / 7.0
					var leaf_xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)) * Basis.from_euler(Vector3(0, 0, -0.45)), top)
					leaf_xf = leaf_xf * MeshUtil.xf(Vector3(1.1, 0, 0), Vector3(2.2, 0.06, 0.45))
					parts.append([MeshUtil.box(Vector3.ONE), frond if i % 2 == 0 else frond.darkened(0.12), leaf_xf])
			else:
				var count := int(variant.get_slice("_", 1)) * 2
				for i in count:
					var point := top + Vector3(cos(i * 1.7) * 0.28, -0.3 - (i % 2) * 0.12, sin(i * 1.7) * 0.28)
					parts.append([MeshUtil.sphere(0.16, 7, 4), Color(0.98, 0.58, 0.15), MeshUtil.xf(point)])
	return MeshUtil.combine(parts)
