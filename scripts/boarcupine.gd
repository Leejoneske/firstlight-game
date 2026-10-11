class_name Boarcupine
extends CharacterBody3D
## A spiky boar. It paws the ground, then charges in a straight line.
## Sidestep so it rams into something, then hit it while it's dizzy.
## Hitting it while it isn't dizzy hurts: spikes!

signal died(boar: Boarcupine)

enum State { WANDER, ALERT, CHARGE, DIZZY, DEAD }

const MAX_HEALTH := 4
const RADIUS := 0.55
const GRAVITY := 20.0
const WANDER_SPEED := 1.6
const WANDER_RANGE := 9.0
const CHARGE_SPEED := 11.0
const SIGHT_DAY := 8.0
const SIGHT_NIGHT := 12.0
const ALERT_TIME := 0.9
const CHARGE_TIME := 1.3
const DIZZY_AFTER_RAM := 2.4  ## Seconds dizzy after ramming a tree, rock or wall.
const DIZZY_AFTER_CHARGE := 0.9  ## Seconds dizzy after a charge that hit nothing.
const CHARGE_DAMAGE := 22.0
const SPIKE_DAMAGE := 8.0

var family: Array[FamilyMember] = []
var camp_position := Vector3.ZERO
var camp_radius := 7.0
var world_half := 60.0
var aggressive := false  ## True at night: it spots the family from farther away.
var health := MAX_HEALTH
var state := State.WANDER

var _home := Vector3.ZERO
var _timer := 0.0
var _wander_target := Vector3.ZERO
var _charge_dir := Vector3.FORWARD
var _target: FamilyMember
var _facing := Vector3.FORWARD
var _hurt_flash := 0.0
var _walk_phase := 0.0
var _hit_someone := false
var _model: Node3D
var _legs: Array[Node3D] = []
var _eyes: Array[MeshInstance3D] = []
var _alert_tag: Label3D
var _stars: Node3D
var _body_parts: Array[MeshInstance3D] = []
var _was_flashing := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = 1.3
	shape.shape = capsule
	shape.position.y = 0.6
	add_child(shape)
	_build_model()
	_home = global_position
	_pick_wander_target()


func is_alive() -> bool:
	return state != State.DEAD


func is_dizzy() -> bool:
	return state == State.DIZZY


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_timer -= delta
	var horizontal := Vector3(velocity.x, 0, velocity.z)

	match state:
		State.WANDER:
			horizontal = _wander(delta)
		State.ALERT:
			horizontal = Vector3.ZERO
			if _target and not _target.is_down:
				var to_target := _target.global_position - global_position
				to_target.y = 0.0
				if to_target.length() > 0.01:
					_facing = to_target.normalized()
			if _timer <= 0.0:
				_charge_dir = _facing
				_hit_someone = false
				state = State.CHARGE
				_timer = CHARGE_TIME
		State.CHARGE:
			horizontal = _charge_dir * CHARGE_SPEED
		State.DIZZY:
			horizontal = horizontal.move_toward(Vector3.ZERO, 14.0 * delta)
			if _timer <= 0.0:
				state = State.WANDER
				_timer = 1.0

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	if state == State.CHARGE:
		_check_charge_hits()
		if is_on_wall():
			_become_dizzy(DIZZY_AFTER_RAM)
		elif _timer <= 0.0 or _hit_someone or _flat_distance(camp_position) < camp_radius:
			_become_dizzy(DIZZY_AFTER_CHARGE)
	_animate(delta)


func take_hit(amount: int, attacker: FamilyMember) -> void:
	if state == State.DEAD:
		return
	if state != State.DIZZY:
		attacker.take_hit(SPIKE_DAMAGE, global_position)
		GameState.notify("Ouch, spikes! Dodge its charge, then hit it while it's dizzy.")
	health -= amount
	_hurt_flash = 0.25
	var push := global_position - attacker.global_position
	push.y = 0.0
	velocity = push.normalized() * 5.0
	if health <= 0:
		_die()
	elif state == State.WANDER:
		# Fight back against whoever hit it
		_target = attacker
		state = State.ALERT
		_timer = ALERT_TIME * 0.6


func _wander(delta: float) -> Vector3:
	if _timer <= 0.0:
		var prey := _find_prey()
		if prey:
			_target = prey
			state = State.ALERT
			_timer = ALERT_TIME
			return Vector3.ZERO
	var to_target := _wander_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.5 or (is_on_wall() and randf() < 0.05):
		_pick_wander_target()
	var move := to_target.normalized() * WANDER_SPEED
	if move.length() > 0.01:
		_facing = _facing.slerp(move.normalized(), clampf(5.0 * delta, 0.0, 1.0)).normalized()
	return move


func _find_prey() -> FamilyMember:
	var best: FamilyMember = null
	var best_distance := SIGHT_NIGHT if aggressive else SIGHT_DAY
	for member in family:
		if member.is_down or member.in_camp:
			continue
		var distance := _flat_distance(member.global_position)
		if distance < best_distance:
			best = member
			best_distance = distance
	return best


func _check_charge_hits() -> void:
	for member in family:
		if member.is_down:
			continue
		if _flat_distance(member.global_position) < RADIUS + FamilyMember.RADIUS * member.size_scale + 0.2:
			member.take_hit(CHARGE_DAMAGE, global_position)
			_hit_someone = true
			return


func _become_dizzy(duration: float) -> void:
	state = State.DIZZY
	_timer = duration
	velocity = -_charge_dir * 3.0


func _pick_wander_target() -> void:
	for attempt in 10:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(2.0, WANDER_RANGE)
		var point := _home + offset
		var limit := world_half - 6.0
		if absf(point.x) > limit or absf(point.z) > limit:
			continue
		if Vector2(point.x - camp_position.x, point.z - camp_position.z).length() < camp_radius + 3.0:
			continue
		_wander_target = point
		return
	_wander_target = _home


func _flat_distance(point: Vector3) -> float:
	return Vector2(global_position.x - point.x, global_position.z - point.z).length()


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	_alert_tag.visible = false
	_stars.visible = false
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(_model, "rotation:z", PI / 2.0, 0.4)
	tween.tween_interval(0.5)
	tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.4)
	tween.tween_callback(queue_free)


# --- Model and animation ----------------------------------------------------

func _build_model() -> void:
	var brown := Color(0.48, 0.33, 0.22)
	_model = Node3D.new()
	add_child(_model)
	for corner in [Vector3(-0.22, 0.45, -0.38), Vector3(0.22, 0.45, -0.38), Vector3(-0.22, 0.45, 0.38), Vector3(0.22, 0.45, 0.38)]:
		var hip := Node3D.new()
		hip.position = corner
		_model.add_child(hip)
		_body_parts.append(MeshUtil.add_part(hip, MeshUtil.cylinder(0.07, 0.06, 0.45, 6), brown.darkened(0.3), Vector3(0, -0.22, 0)))
		_legs.append(hip)
	_body_parts.append(MeshUtil.add_part(_model, MeshUtil.sphere(0.5), brown, Vector3(0, 0.72, 0), Vector3(0.85, 0.65, 1.15)))
	_body_parts.append(MeshUtil.add_part(_model, MeshUtil.sphere(0.27), brown.lightened(0.05), Vector3(0, 0.75, -0.62)))
	MeshUtil.add_part(_model, MeshUtil.cylinder(0.11, 0.13, 0.2, 8), Color(0.85, 0.6, 0.55), Vector3(0, 0.7, -0.88), Vector3.ONE, Vector3(PI / 2.0, 0, 0))
	for side in [-1.0, 1.0]:
		MeshUtil.add_part(_model, MeshUtil.cylinder(0.0, 0.035, 0.22, 5), Color(1, 0.97, 0.88), Vector3(side * 0.12, 0.66, -0.85), Vector3.ONE, Vector3(-0.6, 0, side * 0.3))
		_eyes.append(MeshUtil.add_part(_model, MeshUtil.sphere(0.04, 6, 3), Color(0.08, 0.05, 0.03), Vector3(side * 0.13, 0.85, -0.8)))
		MeshUtil.add_part(_model, MeshUtil.cylinder(0.0, 0.07, 0.16, 4), brown.darkened(0.2), Vector3(side * 0.15, 1.0, -0.6))
	# Spikes along the back, pointing up and backward
	for part in _body_parts:
		part.set_meta("material", part.material_override)
	var spikes := []
	for row in 4:
		for column in 3:
			var x := (column - 1) * 0.2
			var z := -0.25 + row * 0.22
			var spike_xf := MeshUtil.xf(Vector3(x, 1.02 - absf(x) * 0.4, z), Vector3.ONE, Vector3(0.6, 0, -x * 1.2))
			spikes.append([MeshUtil.cylinder(0.0, 0.04, 0.45, 4), Color(0.93, 0.89, 0.76), spike_xf])
	var spike_mesh := MeshInstance3D.new()
	spike_mesh.mesh = MeshUtil.combine(spikes)
	_model.add_child(spike_mesh)

	_alert_tag = MeshUtil.label("!", 96, Color(1, 0.3, 0.2))
	_alert_tag.position.y = 1.8
	_alert_tag.visible = false
	add_child(_alert_tag)
	_stars = Node3D.new()
	_stars.position.y = 1.45
	_stars.visible = false
	add_child(_stars)
	for i in 3:
		MeshUtil.add_part(_stars, MeshUtil.sphere(0.08, 6, 3), Color(1, 0.92, 0.3), Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 3.0) * 0.45)


func _animate(delta: float) -> void:
	_model.rotation.y = atan2(-_facing.x, -_facing.z)
	var speed := Vector2(velocity.x, velocity.z).length()
	_walk_phase += delta * speed * 3.0
	var swing := sin(_walk_phase) * clampf(speed / 3.0, 0.0, 1.0) * 0.7
	_legs[0].rotation.x = swing
	_legs[3].rotation.x = swing
	_legs[1].rotation.x = -swing
	_legs[2].rotation.x = -swing

	_alert_tag.visible = state == State.ALERT
	_model.position.x = sin(Time.get_ticks_msec() * 0.06) * 0.04 if state == State.ALERT else 0.0
	_stars.visible = state == State.DIZZY
	_stars.rotation.y += delta * 5.0
	var angry := state == State.ALERT or state == State.CHARGE
	for eye in _eyes:
		eye.material_override = MeshUtil.material(Color(0.95, 0.2, 0.15) if angry else Color(0.08, 0.05, 0.03))

	var flashing := _hurt_flash > 0.0
	if flashing != _was_flashing:
		_was_flashing = flashing
		for part in _body_parts:
			var normal: Material = part.get_meta("material")
			part.material_override = MeshUtil.material(Color(1, 0.45, 0.4)) if flashing else normal
