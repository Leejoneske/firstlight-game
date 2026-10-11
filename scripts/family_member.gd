class_name FamilyMember
extends CharacterBody3D
## A family member. The player controls one at a time; the others follow the leader.

signal downed

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
@export var follow_side := 1.0  ## Which side of the leader to walk on (-1 left, 1 right).

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
var _skin_parts: Array[MeshInstance3D] = []
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
	_body = Node3D.new()
	_model.add_child(_body)

	# Legs and arms hang from pivots so they can swing
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.13, 0.78, 0)
		_body.add_child(hip)
		_skin_parts.append(MeshUtil.add_part(hip, MeshUtil.capsule(0.09, 0.8), skin_color, Vector3(0, -0.38, 0)))
		_legs.append(hip)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.3, 1.25, 0)
		_body.add_child(shoulder)
		_skin_parts.append(MeshUtil.add_part(shoulder, MeshUtil.capsule(0.075, 0.62), skin_color, Vector3(0, -0.27, 0)))
		_arms.append(shoulder)

	# Fur tunic with spots
	MeshUtil.add_part(_body, MeshUtil.capsule(0.27, 0.8), fur_color, Vector3(0, 1.05, 0), Vector3(1.0, 1.0, 0.85))
	for spot in [Vector3(-0.12, 1.12, -0.22), Vector3(0.14, 0.92, -0.21), Vector3(0.05, 1.25, 0.22)]:
		MeshUtil.add_part(_body, MeshUtil.sphere(0.06, 6, 3), fur_color.darkened(0.35), spot, Vector3(1, 1, 0.4))

	# Head: hair behind, face in front (the model faces -Z)
	_skin_parts.append(MeshUtil.add_part(_body, MeshUtil.sphere(0.2), skin_color, Vector3(0, 1.58, 0)))
	MeshUtil.add_part(_body, MeshUtil.sphere(0.215), hair_color, Vector3(0, 1.64, 0.05), Vector3(1.05, 0.9, 1.0))
	MeshUtil.add_part(_body, MeshUtil.sphere(0.12, 6, 4), hair_color, Vector3(0, 1.5, 0.17), Vector3(1.4, 1.6, 1.0))
	for side in [-1.0, 1.0]:
		MeshUtil.add_part(_body, MeshUtil.sphere(0.03, 6, 3), Color(0.08, 0.05, 0.03), Vector3(side * 0.075, 1.6, -0.18))
	MeshUtil.add_part(_body, MeshUtil.sphere(0.04, 6, 3), skin_color.darkened(0.08), Vector3(0, 1.55, -0.2))

	_name_tag = MeshUtil.label(member_name, 36)
	_name_tag.position.y = 2.15 * size_scale
	add_child(_name_tag)
	_sleep_tag = MeshUtil.label("Zz", 48, Color(0.8, 0.9, 1.0))
	_sleep_tag.position.y = 1.0
	_sleep_tag.visible = false
	add_child(_sleep_tag)


func _animate(delta: float, speed: float) -> void:
	_model.rotation.y = atan2(-facing.x, -facing.z)
	_sleep_tag.visible = is_down
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

	var flashing := _hurt_flash > 0.0 and int(_hurt_flash * 20.0) % 2 == 0
	if flashing != _was_flashing:
		_was_flashing = flashing
		var mat := MeshUtil.material(Color(1, 0.35, 0.3) if flashing else skin_color)
		for part in _skin_parts:
			part.material_override = mat
