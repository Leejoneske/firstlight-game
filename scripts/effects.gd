class_name Effects
## Small one-off visual effects.

static var _particle_material: StandardMaterial3D


## A quick burst of little bits flying out, e.g. berries or stone chips when gathering.
static func burst(parent: Node, position: Vector3, color: Color, amount := 10, speed := 3.0) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.8
	particles.mesh = MeshUtil.box(Vector3.ONE * 0.09)
	particles.material_override = particle_material()
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = speed * 0.6
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -12, 0)
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	particles.color = color
	particles.position = position
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Material for particles: lit, coloured by each particle's colour.
static func particle_material() -> StandardMaterial3D:
	if _particle_material == null:
		_particle_material = StandardMaterial3D.new()
		_particle_material.vertex_color_use_as_albedo = true
		_particle_material.vertex_color_is_srgb = true
		_particle_material.roughness = 0.9
	return _particle_material


## Soft see-through dust puffs (for footsteps and the like).
static func dust_emitter() -> CPUParticles3D:
	var dust := CPUParticles3D.new()
	dust.amount = 10
	dust.lifetime = 0.7
	dust.emitting = false
	dust.mesh = MeshUtil.sphere(0.12, 6, 4)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	dust.material_override = material
	dust.direction = Vector3.UP
	dust.spread = 50.0
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 0.8
	dust.gravity = Vector3(0, 0.4, 0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.85, 0.72, 0.52, 0.45), Color(0.85, 0.72, 0.52, 0.0)])
	dust.color_ramp = fade
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return dust
