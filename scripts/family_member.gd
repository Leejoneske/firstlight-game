class_name FamilyMember
extends CharacterBody3D
## A family member. The player controls one at a time; the others follow the leader.

signal downed
signal hurt

const MAX_HUNGER := 100.0
const RADIUS := 0.35
const GRAVITY := 20.0
const STARVE_DAMAGE := 1.5  ## Health lost per second while hunger is empty.
const CAMP_HEAL := 2.0  ## Health gained per second while resting at camp.
const CAMP_WAKE_RATIO := 0.4  ## A knocked-out member at camp wakes up at this share of health.
const FOLLOW_BACK := 1.6  ## How far behind the leader followers walk.
const FOLLOW_SIDE := 1.1
const TELEPORT_DISTANCE := 25.0  ## Followers this far behind catch up instantly.

@export var member_name := "Member"
@export var talent := ""
@export var skin_color := Color(0.87, 0.67, 0.5)
@export var fur_color := Color(0.6, 0.4, 0.2)
@export var hair_color := Color(0.2, 0.12, 0.08)
@export var max_health := 100.0
@export var move_speed := 5.0  ## Metres per second.
@export var strength := 1  ## Damage per hit. 2 or more can smash boulders.
@export var can_climb := false
@export var hunger_rate := 0.4  ## Hunger lost per second.
@export var size_scale := 1.0
@export var follow_side := 1.0
@export var bulk := 1.0  ## Build: above 1 is broader and stockier.
@export var hair_style := ""  ## "beard", "mane" or "" for short hair.
@export var eye_color := Color(0.35, 0.22, 0.12)  ## Which side of the leader to walk on (-1 left, 1 right).

var health := 0.0
var hunger := MAX_HUNGER
var is_active := false
var is_down := false
var in_camp := false
var leader: FamilyMember  ## Who to follow when not controlled.
var move_input := Vector3.ZERO  ## World-space direction, length 0 to 1.
var look_direction := Vector3.ZERO  ## When set, the member faces this way (first-person view).
var facing := Vector3.FORWARD
var action_cooldown := 0.0

var _knockback := Vector3.ZERO
var _hurt_flash := 0.0
var _invulnerable := 0.0
var _walk_phase := 0.0
var _attack_anim := 0.0
var _model: Node3D
var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _head: Node3D
var _eyelids: Array[MeshInstance3D] = []
var _custom_model: Node3D
var _dust: CPUParticles3D
var _flash_meshes: Array[MeshInstance3D] = []
static var _flash_material: StandardMaterial3D
var _anim: AnimationPlayer
var _blink_meshes: Array[MeshInstance3D] = []
var _blink_timer := 2.0
var _idle_time := 0.0
var _name_tag: Label3D
var _sleep_tag: Label3D
var _was_flashing := false


func _ready() -> void:
	health = max_health
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS * size_scale
	capsule.height = 1.7 * size_scale
	shape.shape = capsule
	shape.position.y = capsule.height / 2.0
	add_child(shape)
	_build_model()
	_dust = Effects.dust_emitter()
	add_child(_dust)


func _physics_process(delta: float) -> void:
	action_cooldown = maxf(action_cooldown - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_attack_anim = maxf(_attack_anim - delta, 0.0)
	_update_needs(delta)

	var desired := Vector3.ZERO
	if not is_down:
		if is_active:
			desired = move_input.limit_length(1.0) * move_speed
		elif leader and not leader.is_down:
			desired = _follow_velocity()

	velocity.x = desired.x + _knockback.x
	velocity.z = desired.z + _knockback.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	_knockback = _knockback.move_toward(Vector3.ZERO, 22.0 * delta)
	move_and_slide()

	_dust.emitting = desired.length() > 3.0 and is_on_floor()
	if look_direction != Vector3.ZERO and is_active:
		facing = look_direction
	elif desired.length() > 0.2:
		facing = facing.slerp(desired.normalized(), clampf(12.0 * delta, 0.0, 1.0)).normalized()
	_animate(delta, desired.length())


func _follow_velocity() -> Vector3:
	var side := leader.facing.cross(Vector3.UP).normalized() * FOLLOW_SIDE * follow_side
	var target := leader.global_position - leader.facing * FOLLOW_BACK + side
	var to_target := target - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > TELEPORT_DISTANCE:
		global_position = target + Vector3.UP * 0.5
		return Vector3.ZERO
	if distance < 0.6:
		return Vector3.ZERO
	return to_target / distance * move_speed * clampf(distance / 3.0, 0.3, 1.0)


func _update_needs(delta: float) -> void:
	var rate := hunger_rate * (0.5 if in_camp else 1.0)
	hunger = maxf(hunger - rate * delta, 0.0)
	if hunger <= 0.0:
		_lose_health(STARVE_DAMAGE * delta)
	elif in_camp:
		health = minf(health + CAMP_HEAL * delta, max_health)
		if is_down and health >= max_health * CAMP_WAKE_RATIO:
			revive(health)


func take_hit(amount: float, from_position: Vector3) -> void:
	if is_down or _invulnerable > 0.0:
		return
	_hurt_flash = 0.3
	_invulnerable = 0.7
	hurt.emit()
	var push := global_position - from_position
	push.y = 0.0
	_knockback = push.normalized() * 9.0
	_lose_health(amount)


func revive(to_health: float) -> void:
	is_down = false
	health = clampf(to_health, 1.0, max_health)
	_invulnerable = 1.5


func eat(amount: float) -> void:
	hunger = minf(hunger + amount, MAX_HUNGER)


func play_attack(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length() > 0.01 and look_direction == Vector3.ZERO:
		facing = direction.normalized()
	_attack_anim = 0.25


## Hides the body while the camera looks through this member's eyes.
func set_first_person(enabled: bool) -> void:
	_model.visible = not enabled
	_name_tag.visible = not enabled


func eye_height() -> float:
	return 1.55 * size_scale


func _lose_health(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= 0.0 and not is_down:
		is_down = true
		_knockback = Vector3.ZERO
		downed.emit()


# --- Model and animation ----------------------------------------------------

func _build_model() -> void:
	_model = Node3D.new()
	_model.scale = Vector3.ONE * size_scale
	add_child(_model)
	_add_tags()
	# An artist-made model (models/krag.glb etc.) replaces the placeholder shapes
	_custom_model = ModelLibrary.instantiate(member_name.to_lower())
	if _custom_model:
		_model.add_child(_custom_model)
		_anim = ModelLibrary.find_animation_player(_custom_model)
		_blink_meshes = ModelLibrary.find_blink_meshes(_custom_model)
		return
	_body = Node3D.new()
	_model.add_child(_body)
	var w := bulk  # Broader shoulders and chest for heavier builds
	var dark_fur := fur_color.darkened(0.35)
	var leather := Color(0.32, 0.22, 0.15)

	# Legs with bare feet, hanging from hip pivots so they can swing
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.13 * w, 0.8, 0)
		_body.add_child(hip)
		MeshUtil.add_part(hip, MeshUtil.capsule(0.085 * w, 0.78), skin_color, Vector3(0, -0.37, 0))
		MeshUtil.add_part(hip, MeshUtil.sphere(0.1, 7, 4), skin_color, Vector3(0, -0.76, -0.06), Vector3(0.9 * w, 0.5, 1.5))
		_legs.append(hip)

	# Fur tunic: a flared skirt with a jagged hem, a belt and a strap over one shoulder
	MeshUtil.add_part(_body, MeshUtil.cylinder(0.24 * w, 0.33 * w, 0.42, 10), fur_color, Vector3(0, 0.88, 0), Vector3(1, 1, 0.8))
	for i in 10:
		var angle := i * TAU / 10.0
		MeshUtil.add_part(_body, MeshUtil.cylinder(0.0, 0.07, 0.16, 4), fur_color,
			Vector3(cos(angle) * 0.3 * w, 0.62, sin(angle) * 0.24 * w), Vector3.ONE, Vector3(PI, 0, 0))
	MeshUtil.add_part(_body, MeshUtil.capsule(0.25 * w, 0.62), skin_color, Vector3(0, 1.22, 0), Vector3(1.0, 1.0, 0.78))
	MeshUtil.add_part(_body, MeshUtil.capsule(0.26 * w, 0.42), fur_color, Vector3(0, 1.12, 0), Vector3(1.02, 1.0, 0.82))
	MeshUtil.add_part(_body, MeshUtil.capsule(0.07, 0.62), fur_color, Vector3(-0.08 * w, 1.3, 0), Vector3(1.0, 1.0, 2.6), Vector3(0, 0, -0.62))
	MeshUtil.add_part(_body, MeshUtil.cylinder(0.25 * w, 0.26 * w, 0.07, 10), leather, Vector3(0, 0.99, 0), Vector3(1, 1, 0.82))
	for spot in [Vector3(-0.12, 0.85, -0.25), Vector3(0.16, 0.95, -0.24), Vector3(0.08, 1.15, 0.2), Vector3(-0.2, 1.2, -0.18)]:
		MeshUtil.add_part(_body, MeshUtil.sphere(0.055, 6, 3), dark_fur, spot * Vector3(w, 1, 1), Vector3(1, 1, 0.4))

	# Arms with big hands, hanging from shoulder pivots
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.3 * w, 1.38, 0)
		_body.add_child(shoulder)
		MeshUtil.add_part(shoulder, MeshUtil.sphere(0.11 * w, 7, 4), skin_color)
		MeshUtil.add_part(shoulder, MeshUtil.capsule(0.075 * w, 0.62), skin_color, Vector3(0, -0.28, 0))
		MeshUtil.add_part(shoulder, MeshUtil.sphere(0.085 * w, 7, 4), skin_color, Vector3(0, -0.62, 0), Vector3(1, 1.15, 0.8))
		_arms.append(shoulder)

	# Head (the model faces -Z)
	var head := Node3D.new()
	head.position = Vector3(0, 1.68, 0)
	head.scale = Vector3.ONE * 1.12  # Big cartoon heads read better on small screens
	_body.add_child(head)
	_head = head
	MeshUtil.add_part(head, MeshUtil.sphere(0.2, 10, 6), skin_color, Vector3.ZERO, Vector3(1.0, 1.05, 1.0))
	MeshUtil.add_part(head, MeshUtil.sphere(0.16, 8, 5), skin_color, Vector3(0, -0.09, -0.04), Vector3(1.05 * w, 0.75, 1.0))
	_build_face(head)
	_build_hair(head)

	# Merge the still shapes of each moving part, so phones draw ~8 pieces instead of ~80
	var moving: Array = [_head] + _legs + _arms + _eyelids
	for group: Node3D in [_body, _head] + _legs + _arms:
		var merged := MeshUtil.merge_children(group, moving)
		if merged:
			_flash_meshes.append(merged)
	for lid in _eyelids:
		lid.set_meta("rest", lid.position)


func _add_tags() -> void:
	_name_tag = MeshUtil.label(member_name, 26)
	_name_tag.position.y = 2.25 * size_scale
	add_child(_name_tag)
	_sleep_tag = MeshUtil.label("Zz", 48, Color(0.8, 0.9, 1.0))
	_sleep_tag.position.y = 1.0
	_sleep_tag.visible = false
	add_child(_sleep_tag)


## A clear cartoon face: big eyes with coloured irises and highlights, eyelids that
## blink, heavy brows, a broad nose, a smiling mouth and rosy cheeks.
func _build_face(head: Node3D) -> void:
	var lip := skin_color.darkened(0.35)
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.078, 0.035, -0.168)
		head.add_child(eye)
		MeshUtil.add_part(eye, MeshUtil.sphere(0.055, 10, 6), Color(0.98, 0.97, 0.94), Vector3.ZERO, Vector3(1.0, 1.15, 0.6))
		MeshUtil.add_part(eye, MeshUtil.sphere(0.032, 8, 5), eye_color, Vector3(0, 0, -0.026), Vector3(1, 1, 0.5))
		MeshUtil.add_part(eye, MeshUtil.sphere(0.018, 6, 4), Color(0.05, 0.03, 0.02), Vector3(0, 0, -0.04), Vector3(1, 1, 0.5))
		MeshUtil.add_part(eye, MeshUtil.sphere(0.009, 5, 3), Color.WHITE, Vector3(0.012, 0.014, -0.046))
		# Eyelid: rests above the eye and slides down to blink
		var lid := MeshUtil.add_part(eye, MeshUtil.sphere(0.062, 10, 6), skin_color.darkened(0.04), Vector3.ZERO, Vector3(1.08, 0.3, 0.72))
		_eyelids.append(lid)
		# Brow
		MeshUtil.add_part(head, MeshUtil.capsule(0.03, 0.15), hair_color.darkened(0.25),
			Vector3(side * 0.08, 0.13, -0.175), Vector3(1.0, 1.0, 0.8), Vector3(0.2, 0, PI / 2.0 - side * 0.18))
		# Cheek
		MeshUtil.add_part(head, MeshUtil.sphere(0.045, 7, 4), skin_color.lerp(Color(0.95, 0.45, 0.4), 0.35),
			Vector3(side * 0.12, -0.05, -0.15), Vector3(1.0, 0.7, 0.5))
	# Broad nose
	MeshUtil.add_part(head, MeshUtil.sphere(0.05, 8, 5), skin_color.darkened(0.08), Vector3(0, -0.025, -0.205), Vector3(1.3, 0.9, 1.0))
	for side in [-1.0, 1.0]:
		MeshUtil.add_part(head, MeshUtil.sphere(0.025, 6, 3), skin_color.darkened(0.12), Vector3(side * 0.04, -0.04, -0.2))
	# Smiling mouth: a dark curve with a lighter lower lip
	for i in 5:
		var t := (i - 2) / 2.0
		MeshUtil.add_part(head, MeshUtil.sphere(0.016, 6, 3), Color(0.3, 0.1, 0.08),
			Vector3(t * 0.05, -0.105 + t * t * 0.018, -0.208 + absf(t) * 0.012), Vector3(1.6, 1.0, 0.8))
	MeshUtil.add_part(head, MeshUtil.sphere(0.03, 7, 4), lip, Vector3(0, -0.127, -0.2), Vector3(1.4, 0.45, 0.6))
	# Ears
	for side in [-1.0, 1.0]:
		MeshUtil.add_part(head, MeshUtil.sphere(0.05, 6, 3), skin_color, Vector3(side * 0.2, 0.0, 0), Vector3(0.5, 1.0, 0.8))


func _build_hair(head: Node3D) -> void:
	match hair_style:
		"beard":
			# Short bushy hair and a thick beard
			MeshUtil.add_part(head, MeshUtil.sphere(0.22, 9, 5), hair_color, Vector3(0, 0.08, 0.04), Vector3(1.05, 0.85, 1.05))
			MeshUtil.add_part(head, MeshUtil.sphere(0.2, 8, 5), hair_color, Vector3(0, -0.23, -0.05), Vector3(1.1, 0.85, 0.85))
			MeshUtil.add_part(head, MeshUtil.sphere(0.12, 7, 4), hair_color, Vector3(0, -0.34, -0.09), Vector3(1.0, 1.0, 0.8))
			for side in [-1.0, 1.0]:
				MeshUtil.add_part(head, MeshUtil.sphere(0.08, 7, 4), hair_color, Vector3(side * 0.13, -0.12, -0.08))
			# Tooth necklace
			for i in 7:
				var angle := PI + 0.35 + i * 0.4
				var point := Vector3(cos(angle) * 0.22, -0.42 - sin(i * 0.45) * 0.04, sin(angle) * 0.17)
				MeshUtil.add_part(head, MeshUtil.cylinder(0.0, 0.025, 0.08, 4), Color(0.95, 0.92, 0.82), point, Vector3.ONE, Vector3(PI, 0, 0))
		"mane":
			# A big wild mane with a bone clip
			for blob in [Vector4(0, 0.1, 0.06, 0.24), Vector4(-0.17, 0.0, 0.1, 0.17), Vector4(0.17, 0.0, 0.1, 0.17),
					Vector4(0, -0.05, 0.2, 0.2), Vector4(-0.12, -0.2, 0.18, 0.15), Vector4(0.12, -0.2, 0.18, 0.15), Vector4(0, -0.3, 0.2, 0.14)]:
				MeshUtil.add_part(head, MeshUtil.sphere(blob.w, 8, 5), hair_color, Vector3(blob.x, blob.y, blob.z))
			MeshUtil.add_part(head, MeshUtil.sphere(0.12, 7, 4), hair_color, Vector3(0, 0.2, -0.07), Vector3(1.4, 0.55, 1.0))
			MeshUtil.add_part(head, MeshUtil.cylinder(0.025, 0.025, 0.32, 5), Color(0.95, 0.92, 0.82), Vector3(0.12, 0.2, 0.08), Vector3.ONE, Vector3(0.3, 0, 1.2))
		_:
			MeshUtil.add_part(head, MeshUtil.sphere(0.215, 9, 5), hair_color, Vector3(0, 0.06, 0.05), Vector3(1.05, 0.9, 1.0))


## Plays the artist's animations: idle, walk, run, attack (or gather) and down.
func _animate_custom_model(delta: float, speed: float) -> void:
	var lying := false
	if is_down:
		lying = not ModelLibrary.play(_anim, ["down"])
	elif _attack_anim > 0.0:
		ModelLibrary.play(_anim, ["attack", "gather"])
	elif speed > 0.3:
		ModelLibrary.play(_anim, ["run", "walk"] if speed > 5.5 else ["walk", "run"], speed / 3.5)
	else:
		ModelLibrary.play(_anim, ["idle"])
	_model.rotation.z = PI / 2.0 if lying else 0.0
	_model.position.y = 0.3 * size_scale if lying else 0.0
	_blink(delta)


## Every few seconds the eyelids close for a moment.
func _blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer < -0.14:
		_blink_timer = randf_range(2.0, 5.0)
	var closed := 1.0 - absf(_blink_timer + 0.07) / 0.07 if _blink_timer < 0.0 else 0.0
	for mesh in _blink_meshes:
		mesh.set_blend_shape_value(mesh.find_blend_shape_by_name("blink"), closed)
	for lid in _eyelids:
		lid.visible = closed > 0.0
		var height := lerpf(0.2, 1.08, closed)
		lid.scale.y = height
		lid.position = (lid.get_meta("rest", Vector3.ZERO) as Vector3) + Vector3(0, 0.062 * (1.0 - height) * 1.12, 0)


func _animate(delta: float, speed: float) -> void:
	_model.rotation.y = atan2(-facing.x, -facing.z)
	_sleep_tag.visible = is_down
	if _custom_model:
		_animate_custom_model(delta, speed)
		return
	if is_down:
		_model.rotation.z = PI / 2.0
		_model.position.y = 0.3 * size_scale
		return
	_model.rotation.z = 0.0
	_model.position.y = 0.0

	if speed > 0.3:
		_walk_phase += delta * speed * 2.4
	else:
		_walk_phase = move_toward(_walk_phase, roundf(_walk_phase / PI) * PI, delta * 6.0)
	var swing := sin(_walk_phase) * clampf(speed / 4.0, 0.0, 1.0) * 0.8
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.8
	if _attack_anim > 0.0:
		_arms[1].rotation.x = -1.9 * (_attack_anim / 0.25)
	_body.position.y = absf(sin(_walk_phase)) * 0.05
	_idle_time += delta
	var breath := sin(_idle_time * 2.2) * (1.0 - clampf(speed / 2.0, 0.0, 1.0))
	_body.scale = Vector3(1.0 + breath * 0.012, 1.0 + breath * 0.008, 1.0 + breath * 0.012)
	_head.rotation.x = breath * 0.04
	_head.rotation.y = sin(_idle_time * 0.5) * 0.15 * (1.0 - clampf(speed, 0.0, 1.0))
	_blink(delta)

	var flashing := _hurt_flash > 0.0 and int(_hurt_flash * 20.0) % 2 == 0
	if flashing != _was_flashing:
		_was_flashing = flashing
		if _flash_material == null:
			_flash_material = MeshUtil.vertex_color_material().duplicate()
			_flash_material.albedo_color = Color(1.0, 0.45, 0.4)
		for mesh in _flash_meshes:
			mesh.material_override = _flash_material if flashing else null
